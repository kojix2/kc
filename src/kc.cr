require "option_parser"
require "wait_group"
require "fastx"
require "fiber/execution_context"
require "log"
require "./kmer"

# CLI options

input_file = ""
output_file = ""
k_size = 3
num_workers = 4
chunk_size = 1_000
verbose = false

OptionParser.parse do |p|
  p.banner = "Usage: kc [options] -i FILE"
  p.on("-i", "--input FILE", "Input FASTQ file (.gz supported)") { |v| input_file = v }
  p.on("-o", "--output FILE", "Output TSV file (default: stdout)") { |v| output_file = v }
  p.on("-k", "--kmer-size N", "k-mer size (default: #{k_size})") { |v| k_size = v.to_i.clamp(1, 32) }
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

out = output_file.empty? ? STDOUT : File.open(output_file, "w")
out.sync = true

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

# Emitter

ctx.spawn(name: "emitter") do
  pending = Hash(Int64, Kmer::Entry).new
  next_index = 0_i64

  all_kmers = Kmer.all_kmers(k_size)
  out.print "ID"
  all_kmers.each { |k| out.print '\t', k }
  out.puts

  while row = result_q.receive?
    pending[row.index] = row

    while row = pending.delete(next_index)
      out.print row.id
      all_kmers.each { |k| out.print '\t', (row.counts[k]? || 0) }
      out.puts
      next_index += 1
    end
  end

  until pending.empty?
    if row = pending.delete(next_index)
      out.print row.id
      all_kmers.each { |k| out.print '\t', (row.counts[k]? || 0) }
      out.puts
      next_index += 1
    else
      break
    end
  end
ensure
  mainio_wg.done
end

mainio_wg.wait

total_reads = total_reads_q.receive
Log.info { "[kc] Completed: #{total_reads} reads processed" }

# Only close file if it's not STDOUT
unless out == STDOUT
  out.close
end
