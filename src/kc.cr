require "option_parser"
require "wait_group"
require "fastx"
require "fiber/execution_context"
require "log"
require "./kmer"

# Writer implementation selection
{% if flag?(:cpp_arrow) %}
  require "./arrow_writer"
  require "./arsn_writer"
{% else %}
  require "./arsn_writer"
{% end %}

# CLI options

input_file = ""
output_file = ""
k_size = 3
num_workers = 4
chunk_size = 1_000
verbose = false
format = "tsv" # default format

# Build format options string based on available features
format_options = "tsv (default), sparse, arsn"
{% if flag?(:cpp_arrow) %}
  format_options = "tsv (default), sparse, arrow, arsn"
{% end %}

OptionParser.parse do |p|
  p.banner = "Usage: kc [options] -i FILE"
  p.on("-k", "--kmer-size N", "k-mer size (default: #{k_size})") { |v| k_size = v.to_i.clamp(1, 32) }
  p.on("-i", "--input FILE", "Input FASTQ file (.gz supported)") { |v| input_file = v }
  p.on("-o", "--output FILE", "Output file (default: stdout)") { |v| output_file = v }
  p.on("-f", "--format FORMAT", "Output format: #{format_options}") { |v| format = v }
  p.on("-t", "--threads N", "Number of worker threads (default: #{num_workers})") { |v| num_workers = v.to_i.clamp(1, 256) }
  p.on("-c", "--chunk-size N", "Reads per processing chunk (default: #{chunk_size})") { |v| chunk_size = v.to_i.clamp(1, 10_000) }
  p.on("-v", "--verbose", "Enable verbose output") { |v| verbose = v }

  p.on("-h", "--help", "Show this help message") { puts p; exit }
  p.invalid_option { STDERR.puts(p); exit 1 }
  p.missing_option { STDERR.puts(p); exit 1 }
end
abort "[kc] Input file is required. Use -i to specify a FASTQ file." if input_file.empty?

# Setup logging to STDERR
log_backend = Log::IOBackend.new(STDERR)
if verbose
  Log.setup(:info, log_backend)
else
  Log.setup(:warn, log_backend)
end

output_io = output_file.empty? ? STDOUT : File.open(output_file, "w")
output_io.sync = true

# channels

chunk_q = Channel({Int64, Array(String), Array(String)}).new(16)
result_q = Channel(Kmer::Entry).new(16)
total_reads_q = Channel(Int64).new(1)

Log.info { "[kc] k-mer counting: k=#{k_size}, threads=#{num_workers}, input=#{File.basename(input_file)}" }

ctx = Fiber::ExecutionContext::MultiThreaded.new("kmer-pool", num_workers + 2)
worker_wg = WaitGroup.new(num_workers)
mainio_wg = WaitGroup.new(3)

# Reader

ctx.spawn(name: "reader") do
  read_count = 0_i64
  ids, seqs = [] of String, [] of String
  Fastx::Fastq::Reader.open(input_file) do |r|
    r.each do |id, seq, _|
      ids << id
      seqs << seq.to_s
      if ids.size >= chunk_size
        chunk_q.send({read_count, ids, seqs})
        read_count += ids.size
        ids.clear; seqs.clear
      end
    end
    chunk_q.send({read_count, ids, seqs}) unless ids.empty?
    total_reads_q.send(read_count + ids.size)
  end
  chunk_q.close
ensure
  mainio_wg.done
end

# Workers

num_workers.times do |wid|
  ctx.spawn(name: "worker-#{wid}") do
    while chunk = chunk_q.receive?
      start_idx, id_batch, seq_batch = chunk
      id_batch.each_with_index do |rid, j|
        res = Kmer::Entry.new(start_idx + j, rid, Kmer.count(seq_batch[j], k_size))
        result_q.send res
      end
    end
  ensure
    worker_wg.done
  end
end

ctx.spawn(name: "worker_monitor") do
  worker_wg.wait
  result_q.close
ensure
  mainio_wg.done
end

# Output formatters

# Write header row for the specified output format
def write_header(format : String, io : IO, all_kmers : Array(String)) : Nil
  case format
  when "sparse"
    io.puts "ID\tkmer\tcount"
  else # "tsv"
    io.print "ID"
    all_kmers.each { |k| io.print '\t', k }
    io.puts
  end
end

# Write a single data row for the specified output format
def write_row(format : String, io : IO, row : Kmer::Entry, all_kmers : Array(String)) : Nil
  case format
  when "sparse"
    row.counts.each do |kmer, count|
      next if count == 0
      io.puts "#{row.id}\t#{kmer}\t#{count}"
    end
  else # "tsv"
    io.print row.id
    all_kmers.each { |k| io.print '\t', (row.counts[k]? || 0) }
    io.puts
  end
end

# Emitter helper functions

# Flush ready rows from pending hash in order
def flush_ready_rows(pending : Hash(Int64, Kmer::Entry), next_index : Int64) : {Array(Kmer::Entry), Int64}
  ready = [] of Kmer::Entry
  index = next_index

  while row = pending.delete(index)
    ready << row
    index += 1
  end

  {ready, index}
end

# Convert k-mer entries to sparse data format
def to_sparse_data(rows : Array(Kmer::Entry)) : Array({String, String, UInt32})
  data = [] of {String, String, UInt32}
  rows.each do |row|
    row.counts.each do |kmer, count|
      next if count == 0
      data << {row.id, kmer, count}
    end
  end
  data
end

# Save data in binary format (arrow or arsn)
def save_binary_format(file : String, data : Array({String, String, UInt32}), kmers : Array(String), format_name : String) : Nil
  if file.empty?
    STDERR.puts "[kc] Error: #{format_name.capitalize} format requires output file (-o option)"
    exit 1
  end

  success = case format_name
            when "arrow"
              {% if flag?(:cpp_arrow) %}
                ArrowWriter.write_sparse_coo(file, data, kmers)
              {% else %}
                false # Arrow format not available in Crystal-only build
              {% end %}
            when "arsn"
              ArsnWriter.write_sparse_coo(file, data, kmers)
            else
              false
            end

  unless success
    STDERR.puts "[kc] Error: Failed to write #{format_name} file"
    exit 1
  end
end

ctx.spawn(name: "emitter") do
  pending = Hash(Int64, Kmer::Entry).new
  next_index = 0_i64
  all_kmers = Kmer.all_kmers(k_size)

  case format
  when "arrow", "arsn"
    all_data = [] of {String, String, UInt32}

    # Collect all results
    while row = result_q.receive?
      pending[row.index] = row
      ready_rows, next_index = flush_ready_rows(pending, next_index)
      all_data.concat(to_sparse_data(ready_rows))
    end

    # Process remaining pending rows
    until pending.empty?
      ready_rows, next_index = flush_ready_rows(pending, next_index)
      break if ready_rows.empty?
      all_data.concat(to_sparse_data(ready_rows))
    end

    save_binary_format(output_file, all_data, all_kmers, format)
  else
    # TSV/sparse formats
    write_header(format, output_io, all_kmers)

    while row = result_q.receive?
      pending[row.index] = row
      ready_rows, next_index = flush_ready_rows(pending, next_index)
      ready_rows.each { |r| write_row(format, output_io, r, all_kmers) }
    end

    # Process remaining pending rows
    until pending.empty?
      ready_rows, next_index = flush_ready_rows(pending, next_index)
      break if ready_rows.empty?
      ready_rows.each { |r| write_row(format, output_io, r, all_kmers) }
    end
  end
ensure
  mainio_wg.done
end

mainio_wg.wait

total_reads = total_reads_q.receive
Log.info { "[kc] Completed: #{total_reads} reads processed" }

# Only close file if it's not STDOUT
unless output_io == STDOUT
  output_io.close
end
