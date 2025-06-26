# ARSN (custom sparse binary) implementation
require "./sparse_binary"

module ArsnWriter
  # Write sparse COO format data to ARSN binary file
  def self.write_sparse_coo(filename : String, data : Array({String, String, UInt32}), all_kmers : Array(String)) : Bool
    # Create mapping from kmer to column index
    kmer_to_col = Hash(String, Int64).new
    all_kmers.each_with_index { |kmer, idx| kmer_to_col[kmer] = idx.to_i64 }

    # Create mapping from read ID to row index
    read_ids = data.map(&.[0]).uniq
    read_to_row = Hash(String, Int64).new
    read_ids.each_with_index { |read_id, idx| read_to_row[read_id] = idx.to_i64 }

    # Prepare coordinate and value arrays
    coords = Array(Int64).new(data.size * 2)
    values = Array(UInt32).new(data.size)

    data.each do |(read_id, kmer, count)|
      row = read_to_row[read_id]
      col = kmer_to_col[kmer]

      coords << row
      coords << col
      values << count
    end

    num_rows = read_ids.size.to_i64
    num_cols = all_kmers.size.to_i64
    nnz = data.size.to_i64

    # Use the custom sparse binary implementation
    success = SparseBinary.write(filename, coords, values, read_ids, nnz, num_rows, num_cols)
    unless success
      STDERR.puts "[ArsnWriter] Error: Failed to write ARSN file '#{filename}'"
    end
    success
  end
end
