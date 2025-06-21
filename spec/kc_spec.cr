require "./spec_helper"
require "file_utils"

# Helper method to create test FASTQ data
private def create_test_fastq(file)
  file.puts "@read1"
  file.puts "ATCGATCG" # 8bp sequence for more k-mers
  file.puts "+"
  file.puts "IIIIIIII"
  file.puts "@read2"
  file.puts "GCTAGCTA" # Different sequence
  file.puts "+"
  file.puts "IIIIIIII"
  file.flush
end

describe "kc integration" do
  before_all do
    # Build using Makefile instead of shards
    unless File.exists?("./kc")
      system("make test")
    end
  end

  it "runs without errors with default TSV format" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      result = `./kc -i #{file.path} -k 3 2>/dev/null`

      result.should contain("ID")
      result.should contain("read1")
      result.should contain("read2")
      # Should contain k-mer columns
      result.should contain("ATC")
      result.should contain("TCG")
    end
  end

  it "outputs sparse format correctly" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      result = `./kc -i #{file.path} -k 3 --format sparse 2>/dev/null`

      # Check sparse header
      result.should contain("ID\tkmer\tcount")

      # Check that it contains read IDs and k-mers
      result.should contain("read1")
      result.should contain("read2")

      # Should contain actual k-mers with counts
      lines = result.split('\n')
      data_lines = lines.select { |line| line.includes?('\t') && !line.starts_with?("ID") }
      data_lines.size.should be > 0

      # Each data line should have format: ID\tkmer\tcount
      data_lines.each do |line|
        parts = line.split('\t')
        parts.size.should eq(3)
        parts[0].should match(/read[12]/) # ID should be read1 or read2
        parts[1].size.should eq(3)        # k-mer should be 3bp
        parts[2].to_i.should be > 0       # count should be positive
      end
    end
  end

  it "outputs arrow format correctly" do
    File.tempfile("test", ".fastq") do |input_file|
      create_test_fastq(input_file)

      File.tempfile("output", ".arrow") do |output_file|
        result = `./kc -i #{input_file.path} -o #{output_file.path} -k 3 --format arrow 2>/dev/null`

        # Should complete without error
        $?.success?.should be_true

        # Output file should be created and have content
        File.exists?(output_file.path).should be_true
        File.size(output_file.path).should be > 0

        # Check if it has the expected format based on implementation
        content = File.read(output_file.path)
        {% if flag?(:cpp_arrow) %}
          # C++ implementation uses official Arrow IPC format
          content[0..5].should eq("ARROW1")
        {% else %}
          # Custom binary implementation uses ARSN format
          content[0..3].should eq("ARSN")
        {% end %}
      end
    end
  end

  it "handles different k-mer sizes" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      # Test k=2
      result_k2 = `./kc -i #{file.path} -k 2 2>/dev/null`
      result_k2.should contain("ID")
      result_k2.should contain("AT")
      result_k2.should contain("TC")

      # Test k=4
      result_k4 = `./kc -i #{file.path} -k 4 2>/dev/null`
      result_k4.should contain("ID")
      result_k4.should contain("ATCG")
      result_k4.should contain("TCGA")
    end
  end

  it "handles multiple threads" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      # Test with different thread counts
      result_t1 = `./kc -i #{file.path} -k 3 -t 1 2>/dev/null`
      result_t4 = `./kc -i #{file.path} -k 3 -t 4 2>/dev/null`

      # Results should be identical regardless of thread count
      result_t1.should eq(result_t4)
    end
  end

  it "handles output to file" do
    File.tempfile("test", ".fastq") do |input_file|
      create_test_fastq(input_file)

      File.tempfile("output", ".tsv") do |output_file|
        result = `./kc -i #{input_file.path} -o #{output_file.path} -k 3 2>/dev/null`

        # Should complete without error
        $?.success?.should be_true

        # Output file should be created and have content
        File.exists?(output_file.path).should be_true
        content = File.read(output_file.path)
        content.should contain("ID")
        content.should contain("read1")
        content.should contain("read2")
      end
    end
  end

  it "shows help" do
    result = `./kc --help 2>&1`
    result.should contain("Usage: kc")
    result.should contain("--format FORMAT")
    result.should contain("tsv")
    result.should contain("sparse")
    result.should contain("arrow")
  end

  it "shows error for missing input" do
    result = IO::Memory.new
    status = Process.run("./kc", output: result, error: result)
    output = result.to_s
    output.should contain("Input file is required")
    status.exit_code.should_not eq(0)
  end

  it "handles invalid format gracefully (falls back to default)" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      result = IO::Memory.new
      status = Process.run("./kc", ["-i", file.path, "--format", "invalid"], output: result, error: result)
      output = result.to_s

      # Should complete successfully (falls back to default TSV format)
      status.exit_code.should eq(0)
      output.should contain("ID")
      output.should contain("read1")
    end
  end

  it "shows error for arrow without output file" do
    File.tempfile("test", ".fastq") do |file|
      create_test_fastq(file)

      result = IO::Memory.new
      status = Process.run("./kc", ["-i", file.path, "--format", "arrow"], output: result, error: result)
      output = result.to_s
      output.should contain("Arrow format requires output file")
      status.exit_code.should_not eq(0)
    end
  end
end
