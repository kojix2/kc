require "./spec_helper"
require "file_utils"

describe "kc integration" do
  it "runs without errors" do
    File.tempfile("test", ".fastq") do |file|
      file.puts "@read1"
      file.puts "ATCG"
      file.puts "+"
      file.puts "IIII"
      file.flush

      result = `./bin/kc -i #{file.path} 2>/dev/null`

      result.should contain("ID")
      result.should contain("read1")
    end
  end

  it "shows help" do
    result = `./bin/kc --help 2>&1`
    result.should contain("Usage: kc")
  end

  it "shows error for missing input" do
    result = `./bin/kc 2>&1`
    result.should contain("Input file is required")
  end
end
