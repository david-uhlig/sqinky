# frozen_string_literal: true

# Compares finding records by a Sqinky encoding, which is decoded on the fly, against finding them by primary key
# and by an encoding stored in a column. Runs against SQLite and, if it is reachable, PostgreSQL.
#
#   bundle exec ruby benchmarks/db_retrieval.rb
#   NUM_RECORDS=10000 WARMUP=1 TIME=2 bundle exec ruby benchmarks/db_retrieval.rb  # quicker, noisier run
#   DATABASE_URL=postgres://user:password@host/database bundle exec ruby benchmarks/db_retrieval.rb
#
# The benchmark creates and drops the table sqinky_benchmark_orders. It doesn't touch any other table.

require "active_record"
require "benchmark/ips"
require "sqids"
require_relative "../lib/sqinky"

NUM_RECORDS = Integer(ENV.fetch("NUM_RECORDS", 100_000))
NUM_ACCOUNTS = 100
SAMPLE_SIZE = 10_000
IPS_CONFIG = {warmup: Float(ENV.fetch("WARMUP", 2)), time: Float(ENV.fetch("TIME", 5))}.freeze
POSTGRES_URL = ENV.fetch("DATABASE_URL", "postgres://postgres:postgres@127.0.0.1/postgres")
SQLITE_FILE = File.expand_path("db_retrieval.sqlite3", __dir__)

class Order < ActiveRecord::Base
  include Sqinky::IdentifierEncoding

  self.table_name = "sqinky_benchmark_orders"

  encodes_identifier :id, as: :public_id
  encodes_identifiers :id, :account_id, as: :token
end

sqids = Sqids.new
ROWS = Array.new(NUM_RECORDS) do |index|
  id = index + 1
  encoding = sqids.encode([id])
  {id: id, account_id: id % NUM_ACCOUNTS, sqid: encoding, sqid_unindexed: encoding}
end

# Lookups sample from these, so that every report pays the same sampling overhead.
SAMPLE = ROWS.sample(SAMPLE_SIZE).map { |row| row.merge(token: sqids.encode([row[:id], row[:account_id]])) }
MISSING_ID = NUM_RECORDS + 1
MISSING_ENCODING = sqids.encode([MISSING_ID])
INVALID_ENCODING = "not-an-encoding"

def run_benchmark(adapter, connection_config)
  puts "\n#### #{adapter}"
  ActiveRecord::Base.establish_connection(connection_config)
  connection = ActiveRecord::Base.lease_connection
  version_query = (connection.adapter_name == "SQLite") ? "SELECT sqlite_version()" : "SHOW server_version"
  puts "Database: #{connection.adapter_name} #{connection.select_value(version_query)}"

  connection.create_table(Order.table_name, force: true) do |t|
    t.integer :account_id, null: false
    t.string :sqid, null: false, index: {unique: true}
    t.string :sqid_unindexed, null: false
  end
  Order.reset_column_information

  print "Inserting #{NUM_RECORDS} records... "
  ROWS.each_slice(10_000) { Order.insert_all(_1) }
  # Fresh statistics, so that the query planner uses the indexes.
  connection.execute("ANALYZE #{Order.table_name}")
  puts "done."

  puts "\n== Finding by a single-column encoding"
  Benchmark.ips do |x|
    x.config(**IPS_CONFIG)
    x.report("find(id)") { Order.find(SAMPLE.sample[:id]) }
    x.report("find_by(id:)") { Order.find_by(id: SAMPLE.sample[:id]) }
    x.report("find_by_public_id") { Order.find_by_public_id(SAMPLE.sample[:sqid]) }
    x.report("find_by_public_id!") { Order.find_by_public_id!(SAMPLE.sample[:sqid]) }
    x.report("find_by(sqid:) (stored, indexed)") { Order.find_by(sqid: SAMPLE.sample[:sqid]) }
    x.compare!
  end

  # Kept apart, because a full table scan is orders of magnitude slower than the other lookups and would take over
  # the comparison.
  puts "\n== Finding by a stored encoding without an index (full table scan)"
  Benchmark.ips do |x|
    x.config(**IPS_CONFIG)
    x.report("find_by(sqid_unindexed:)") { Order.find_by(sqid_unindexed: SAMPLE.sample[:sqid]) }
  end

  puts "\n== Finding by a two-column encoding"
  Benchmark.ips do |x|
    x.config(**IPS_CONFIG)
    x.report("find_by(id:, account_id:)") do
      row = SAMPLE.sample
      Order.find_by(id: row[:id], account_id: row[:account_id])
    end
    x.report("find_by_token") { Order.find_by_token(SAMPLE.sample[:token]) }
    x.compare!
  end

  # An invalid encoding never reaches the database. A valid encoding of a missing record does.
  puts "\n== Not finding a record"
  Benchmark.ips do |x|
    x.config(**IPS_CONFIG)
    x.report("find_by(id:) (missing)") { Order.find_by(id: MISSING_ID) }
    x.report("find_by_public_id (missing)") { Order.find_by_public_id(MISSING_ENCODING) }
    x.report("find_by_public_id (invalid)") { Order.find_by_public_id(INVALID_ENCODING) }
    x.compare!
  end
rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, LoadError => e
  puts "Skipping #{adapter}: #{e.message.lines.first&.strip}"
ensure
  if ActiveRecord::Base.connected?
    ActiveRecord::Base.lease_connection.drop_table(Order.table_name, if_exists: true)
    ActiveRecord::Base.remove_connection
  end
  Dir.glob("#{SQLITE_FILE}*").each { File.delete(_1) }
end

puts "Ruby #{RUBY_VERSION} (YJIT #{(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) ? "on" : "off"}), " \
  "Active Record #{ActiveRecord.version}, Sqids #{Gem.loaded_specs["sqids"]&.version}, #{NUM_RECORDS} records"

run_benchmark("SQLite", adapter: "sqlite3", database: SQLITE_FILE)
run_benchmark("PostgreSQL", url: POSTGRES_URL, connect_timeout: 2)
