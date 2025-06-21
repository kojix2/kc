require "./spec_helper"
require "../src/kmer"

describe Kmer do
  describe ".count" do
    it "counts k-mers correctly for simple sequence" do
      result = Kmer.count("AAATTT", 3)

      result["AAA"].should eq(1)
      result["AAT"].should eq(1)
      result["ATT"].should eq(1)
      result["TTT"].should eq(1)

      # All other k-mers should be 0 (not present in hash)
      result.size.should eq(4)
    end

    it "handles overlapping k-mers" do
      result = Kmer.count("AAAA", 3)

      result["AAA"].should eq(2)
      result.size.should eq(1)
    end

    it "returns empty hash for sequences shorter than k" do
      result = Kmer.count("AT", 3)

      result.should be_empty
    end

    it "handles k=2 correctly" do
      result = Kmer.count("ATCG", 2)

      result["AT"].should eq(1)
      result["TC"].should eq(1)
      result["CG"].should eq(1)
      result.size.should eq(3)
    end

    it "handles k=1 correctly" do
      result = Kmer.count("ATCG", 1)

      result["A"].should eq(1)
      result["T"].should eq(1)
      result["C"].should eq(1)
      result["G"].should eq(1)
      result.size.should eq(4)
    end

    it "handles repeated k-mers" do
      result = Kmer.count("ATATATATA", 2)

      result["AT"].should eq(4)
      result["TA"].should eq(4)
      result.size.should eq(2)
    end
  end

  describe ".all_kmers" do
    it "generates all possible 2-mers" do
      result = Kmer.all_kmers(2)

      result.should eq(["AA", "AC", "AG", "AT", "CA", "CC", "CG", "CT",
                        "GA", "GC", "GG", "GT", "TA", "TC", "TG", "TT"])
      result.size.should eq(16)
    end

    it "generates all possible 1-mers" do
      result = Kmer.all_kmers(1)

      result.should eq(["A", "C", "G", "T"])
      result.size.should eq(4)
    end

    it "generates correct number of 3-mers" do
      result = Kmer.all_kmers(3)

      result.size.should eq(64) # 4^3
      result.should contain("AAA")
      result.should contain("TTT")
      result.should contain("ACG")
    end

    it "returns sorted k-mers" do
      result = Kmer.all_kmers(2)

      result.should eq(result.sort)
    end
  end

  describe "Entry" do
    it "creates entry with correct fields" do
      counts = Kmer.count("ATCG", 2)
      entry = Kmer::Entry.new(42_i64, "test_read", counts)

      entry.index.should eq(42)
      entry.id.should eq("test_read")
      entry.counts.should eq(counts)
    end
  end
end
