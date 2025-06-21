require "fastx"

module Kmer
  alias Counts = Hash(String, UInt32)

  record Entry,
    index : Int64,
    id : String,
    counts : Counts

  def self.count(sequence : String, k : Int32) : Counts
    counts = Counts.new(0_u32, initial_capacity: 4**k)
    return counts if sequence.bytesize < k

    encoded_bases = Fastx.encode_bases(sequence)
    encoded_bases.each_cons(k) do |kmer_slice|
      kmer = Fastx.decode_bases(kmer_slice)
      counts[kmer] += 1
    end

    counts
  end

  def self.all_kmers(k : Int32) : Array(String)
    bases = ['A', 'C', 'G', 'T']
    bases.repeated_permutations(k).map(&.join).to_a.sort
  end
end
