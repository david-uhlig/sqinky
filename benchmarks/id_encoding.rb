# frozen_string_literal: true

# Measures the overhead that Sqinky adds on top of raw Sqids when encoding and decoding identifiers, without a
# database.
#
#   bundle exec ruby benchmarks/id_encoding.rb
#   WARMUP=1 TIME=2 bundle exec ruby benchmarks/id_encoding.rb  # quicker, noisier run

require "active_support/all"
require "benchmark/ips"
require "sqids"
require_relative "../lib/sqinky"

IPS_CONFIG = {warmup: Float(ENV.fetch("WARMUP", 2)), time: Float(ENV.fetch("TIME", 5))}.freeze

# Plain Ruby objects stand in for Active Record models, so that only the encoding overhead is measured.
class SingleAttribute
  include Sqinky::IdentifierEncoding

  attr_reader :id

  def initialize(id)
    @id = id
  end

  encodes_identifier :id, decodes_as: :decode_id
  encodes_identifier :id, as: :lenient_encoding, decodes_as: :decode_id_leniently, canonical: false
  # Sqids checks every encoding against its blocklist, which dominates the cost of encoding.
  encodes_identifier :id, as: :unfiltered_encoding, decodes_as: :decode_id_unfiltered, blocklist: []
end

class MultipleAttributes
  include Sqinky::IdentifierEncoding

  attr_reader :id, :account_id

  def initialize(id, account_id)
    @id = id
    @account_id = account_id
  end

  encodes_identifiers :id, :account_id, decodes_as: :decode_id_and_account_id
end

SQIDS = Sqids.new
SAMPLE_SIZE = 10_000

single_ids = Array.new(SAMPLE_SIZE) { rand(1..1_000_000) }
multiple_ids = Array.new(SAMPLE_SIZE) { [rand(1..1_000_000), rand(1..1_000_000)] }
singles = single_ids.map { SingleAttribute.new(_1) }
multiples = multiple_ids.map { MultipleAttributes.new(*_1) }
single_encodings = single_ids.map { SQIDS.encode([_1]) }
multiple_encodings = multiple_ids.map { SQIDS.encode(_1) }

# Invalid input that a client could send instead of an encoding.
garbage = "a" * 1_000
foreign_characters = "Uk!"
wrong_arity = SQIDS.encode([1, 2])
non_canonical = Sqids.new(min_length: 10).encode([1])

puts "Ruby #{RUBY_VERSION} (YJIT #{(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) ? "on" : "off"}), " \
  "Active Support #{ActiveSupport.version}, Sqids #{Gem.loaded_specs["sqids"]&.version}"

puts "\n== Encoding a single attribute"
Benchmark.ips do |x|
  x.config(**IPS_CONFIG)
  x.report("Sqids#encode([id])") { SQIDS.encode([single_ids.sample]) }
  x.report("#id_encoding") { singles.sample.id_encoding }
  x.report("#id_encoding!") { singles.sample.id_encoding! }
  x.report("#unfiltered_encoding (blocklist: [])") { singles.sample.unfiltered_encoding }
  x.compare!
end

puts "\n== Encoding two attributes"
Benchmark.ips do |x|
  x.config(**IPS_CONFIG)
  x.report("Sqids#encode([id, account_id])") { SQIDS.encode(multiple_ids.sample) }
  x.report("#id_and_account_id_encoding") { multiples.sample.id_and_account_id_encoding }
  x.report("#id_and_account_id_encoding!") { multiples.sample.id_and_account_id_encoding! }
  x.compare!
end

# Decoding checks the encoding by re-encoding the decoded values, unless canonical: false.
puts "\n== Decoding a single attribute"
Benchmark.ips do |x|
  x.config(**IPS_CONFIG)
  x.report("Sqids#decode") { SQIDS.decode(single_encodings.sample) }
  x.report(".decode_id (canonical)") { SingleAttribute.decode_id(single_encodings.sample) }
  x.report(".decode_id_leniently (canonical: false)") { SingleAttribute.decode_id_leniently(single_encodings.sample) }
  x.report(".decode_id_unfiltered (blocklist: [])") { SingleAttribute.decode_id_unfiltered(single_encodings.sample) }
  x.compare!
end

puts "\n== Decoding two attributes"
Benchmark.ips do |x|
  x.config(**IPS_CONFIG)
  x.report("Sqids#decode") { SQIDS.decode(multiple_encodings.sample) }
  x.report(".decode_id_and_account_id") { MultipleAttributes.decode_id_and_account_id(multiple_encodings.sample) }
  x.compare!
end

# Invalid input must be cheap to reject, since anyone can send it. Sqids decoding time grows quadratically with the
# input length, so Sqinky rejects input longer than the longest valid encoding before decoding it.
puts "\n== Rejecting invalid input"
Benchmark.ips do |x|
  x.config(**IPS_CONFIG)
  x.report("Sqids#decode(1,000 characters)") { SQIDS.decode(garbage) }
  x.report(".decode_id(1,000 characters)") { SingleAttribute.decode_id(garbage) }
  x.report(".decode_id_leniently(1,000 characters)") { SingleAttribute.decode_id_leniently(garbage) }
  x.report(".decode_id(foreign characters)") { SingleAttribute.decode_id(foreign_characters) }
  x.report(".decode_id(wrong number of values)") { SingleAttribute.decode_id(wrong_arity) }
  x.report(".decode_id(non-canonical)") { SingleAttribute.decode_id(non_canonical) }
  x.report(".decode_id(nil)") { SingleAttribute.decode_id(nil) }
  x.compare!
end
