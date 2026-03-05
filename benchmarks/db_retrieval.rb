# frozen_string_literal: true

require "active_record"
require "sqlite3"
require "benchmark/ips"
require "sqids"
require_relative "../lib/sqinky"

NUM_RECORDS = 100

class Order < ActiveRecord::Base
  include Sqinky::IdentifierEncoding

  encodes_identifier :id, as: :sqids_encoding
end

puts "Preparing #{NUM_RECORDS} records ----------------"
sqids = Sqids.new
@orders = Array.new(NUM_RECORDS) do |index|
  encoding = sqids.encode([index + 1])
  {sqid: encoding, sqid_unindexed: encoding}
end

# Prepare random IDs and SQIDs for retrieval
sample_size = NUM_RECORDS
@random_ids = Array.new(sample_size) { rand(1..NUM_RECORDS) }
@random_sqids = @random_ids.map { |id| sqids.encode([id]) }

def run_benchmark(adapter:, connection_config:)
  puts "Preparing #{adapter} database -----------------------"

  begin
    ActiveRecord::Base.establish_connection(connection_config)
    ActiveRecord::Base.connection.active?
  rescue => e
    puts "Could not connect to #{adapter}: #{e.message}"
    return
  end

  ActiveRecord::Schema.define do
    create_table :orders, force: true do |t|
      t.string :sqid_unindexed
      t.string :sqid
    end
    add_index :orders, :sqid
  end

  puts "Inserting into the database..."
  # Bulk insert for speed
  Order.insert_all(@orders)
  puts "Orders inserted."

  puts "Benchmarking #{adapter} ------------------------------------"

  Benchmark.ips do |benchmark|
    benchmark.report("#1: Find by ID (Direct)") do
      Order.find(@random_ids.sample)
    end

    benchmark.report("#2: Find by encoding (Indexed column)") do
      Order.find_by(sqid: @random_sqids.sample)
    end

    benchmark.report("#3: Find by encoding (Column without index)") do
      Order.find_by(sqid_unindexed: @random_sqids.sample)
    end

    benchmark.report("#4: Find by encoding (On-the-fly)") do
      Order.find_by_sqids_encoding(@random_sqids.sample)
    end

    benchmark.report("#5: Find by encoding (Strict, On-the-fly)") do
      Order.find_by_sqids_encoding!(@random_sqids.sample)
    end

    benchmark.compare!
  end
ensure
  if adapter == "sqlite3" && File.exist?(connection_config[:database])
    File.delete(connection_config[:database])
  end
end

# Run PostgreSQL if available
begin
  require "pg"
  run_benchmark(
    adapter: "postgresql",
    connection_config: {
      adapter: "postgresql",
      host: "127.0.0.1",
      user: "postgres",
      password: "postgres",
      database: "postgres",
      pool: 5,
      connect_timeout: 2
    }
  )
rescue LoadError
  puts "\nPostgreSQL skip: 'pg' gem not installed."
rescue => e
  puts "\nPostgreSQL skip: #{e.message}"
end

# Run SQLite3
DB_FILE = "benchmarks/db_retrieval.sqlite3"
run_benchmark(
  adapter: "sqlite3",
  connection_config: {adapter: "sqlite3", database: DB_FILE}
)
