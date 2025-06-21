require "./spec_helper"
require "file_utils"

describe "kc integration" do
  before_all do
    unless File.exists?("./bin/kc")
      system("shards build --release -Dpreview_mt -Dexecution_context")
    end
  end

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
    result = IO::Memory.new
    status = Process.run("./bin/kc", output: result, error: result)
    output = result.to_s
    output.should contain("Input file is required")
    status.exit_code.should_not eq(0)
  end
end
