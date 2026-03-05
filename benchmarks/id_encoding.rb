# frozen_string_literal: true

require "active_support/all"
require "benchmark/ips"
require "sqids"
require_relative "../lib/sqinky"

# Mock an ActiveRecord-like object or just a plain Ruby object to test instance methods
class SingleAttribute
  include Sqinky::IdentifierEncoding

  attr_accessor :id
  def initialize(id)
    @id = id
  end
  encodes_identifier :id
end

class MultipleAttributes
  include Sqinky::IdentifierEncoding

  attr_accessor :id, :account_id
  def initialize(id, account_id)
    @id = id
    @account_id = account_id
  end
  encodes_identifiers :id, :account_id
end

# For comparison, how much overhead does Sqinky add over raw Sqids?
SQIDS = Sqids.new

# Generate a pool of random IDs to sample from during benchmark
SAMPLE_SIZE = 10_000
random_single_ids = Array.new(SAMPLE_SIZE) { rand(1..1_000_000) }
random_multiple_ids = Array.new(SAMPLE_SIZE) { [rand(1..1_000_000), rand(1..1_000_000)] }

single = SingleAttribute.new(nil)
multiple = MultipleAttributes.new(nil, nil)

Benchmark.ips do |x|
  x.report("Sqids.encode([id])") do
    SQIDS.encode([random_single_ids.sample])
  end

  x.report("Single#id_encoding") do
    single.id = random_single_ids.sample
    single.id_encoding
  end

  x.report("Single#id_encoding!") do
    single.id = random_single_ids.sample
    single.id_encoding!
  end

  x.report("Sqids.encode([id, account_id])") do
    SQIDS.encode(random_multiple_ids.sample)
  end

  x.report("Multiple#id_and_account_id_encoding") do
    id, account_id = random_multiple_ids.sample
    multiple.id = id
    multiple.account_id = account_id
    multiple.id_and_account_id_encoding
  end

  x.report("Multiple#id_and_account_id_encoding!") do
    id, account_id = random_multiple_ids.sample
    multiple.id = id
    multiple.account_id = account_id
    multiple.id_and_account_id_encoding!
  end

  x.compare!
end
