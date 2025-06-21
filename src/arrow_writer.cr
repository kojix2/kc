require "./arrow_sparse"

module ArrowWriter
  def self.write_sparse_coo(filename : String, data : Array({String, String, UInt32}), all_kmers : Array(String))
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

    # Use the Crystal implementation
    ArrowSparse.write_arrow_sparse(filename, coords, values, read_ids, nnz, num_rows, num_cols)
  end
end
