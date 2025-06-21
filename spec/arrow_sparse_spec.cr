require "./spec_helper"
require "../src/arrow_sparse"

describe ArrowSparse do
  describe ".write_arrow_sparse" do
    it "writes and reads sparse tensor data correctly" do
      filename = "test_sparse.arrow"

      # Test data
      coords = [0_i64, 0_i64, 0_i64, 2_i64, 1_i64, 1_i64, 2_i64, 0_i64]
      values = [10_u32, 20_u32, 30_u32, 40_u32]
      read_names = ["read1", "read2", "read3"]
      nnz = 4_i64
      num_rows = 3_i64
      num_cols = 3_i64

      # Write data
      result = ArrowSparse.write_arrow_sparse(
        filename, coords, values, read_names, nnz, num_rows, num_cols
      )
      result.should be_true

      # Read and verify data
      data = ArrowSparse.read_arrow_sparse(filename)
      data[:nnz].should eq(nnz)
      data[:num_rows].should eq(num_rows)
      data[:num_cols].should eq(num_cols)
      data[:read_names].should eq(read_names)
      data[:coords].should eq(coords)
      data[:values].should eq(values)

      # Clean up
      File.delete(filename) if File.exists?(filename)
    end
  end

  describe ".write_arrow_sparse_slice" do
    it "writes and reads sparse tensor data with slices correctly" do
      filename = "test_sparse_slice.arrow"

      # Test data
      coords_array = [0_i64, 0_i64, 0_i64, 2_i64, 1_i64, 1_i64, 2_i64, 0_i64]
      values_array = [10_u32, 20_u32, 30_u32, 40_u32]
      coords = Slice.new(coords_array.to_unsafe, coords_array.size)
      values = Slice.new(values_array.to_unsafe, values_array.size)
      read_names = ["read1", "read2", "read3"]
      nnz = 4_i64
      num_rows = 3_i64
      num_cols = 3_i64

      # Write data
      result = ArrowSparse.write_arrow_sparse_slice(
        filename, coords, values, read_names, nnz, num_rows, num_cols
      )
      result.should be_true

      # Read and verify data
      data = ArrowSparse.read_arrow_sparse(filename)
      data[:nnz].should eq(nnz)
      data[:num_rows].should eq(num_rows)
      data[:num_cols].should eq(num_cols)
      data[:read_names].should eq(read_names)
      data[:coords].should eq(coords_array)
      data[:values].should eq(values_array)

      # Clean up
      File.delete(filename) if File.exists?(filename)
    end
  end

  describe "error handling" do
    it "returns false for invalid file path" do
      coords = [0_i64, 0_i64]
      values = [10_u32]
      read_names = ["read1"]

      result = ArrowSparse.write_arrow_sparse(
        "/invalid/path/file.arrow", coords, values, read_names, 1_i64, 1_i64, 1_i64
      )
      result.should be_false
    end

    it "raises error for invalid magic header" do
      # Create a file with wrong magic header
      filename = "invalid_magic.arrow"
      File.open(filename, "wb") do |file|
        file.write("XXXX".to_slice)
      end

      expect_raises(Exception, "Invalid magic header") do
        ArrowSparse.read_arrow_sparse(filename)
      end

      # Clean up
      File.delete(filename) if File.exists?(filename)
    end
  end
end
