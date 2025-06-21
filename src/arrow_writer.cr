# Arrow sparse tensor bindings
@[Link(ldflags: "#{__DIR__}/../libarrow_sparse.a -lstdc++")]
lib ArrowSparse
  fun write_arrow_sparse_coo(filename : LibC::Char*, coords : LibC::Int64T*, values : LibC::Double*, nnz : LibC::Int64T, num_rows : LibC::Int64T, num_cols : LibC::Int64T) : LibC::Int
end

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
    coords = LibC.malloc(data.size * 2 * sizeof(Int64)).as(Int64*)
    values = LibC.malloc(data.size * sizeof(Float64)).as(Float64*)

    data.each_with_index do |(read_id, kmer, count), i|
      row = read_to_row[read_id]
      col = kmer_to_col[kmer]

      coords[i * 2] = row
      coords[i * 2 + 1] = col
      values[i] = count.to_f64
    end

    num_rows = read_ids.size.to_i64
    num_cols = all_kmers.size.to_i64
    nnz = data.size.to_i64

    result = ArrowSparse.write_arrow_sparse_coo(filename, coords, values, nnz, num_rows, num_cols)

    LibC.free(coords.as(Void*))
    LibC.free(values.as(Void*))

    result == 0
  end
end
