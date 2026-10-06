# frozen_string_literal: true

require "open3"
require "rbconfig"

# Runs in a separate process, because the other specs load Active Record, which loads the core extensions this
# library relies on and would hide a missing require.
RSpec.describe "Loading Sqinky without Rails" do
  it "works with only its own requires" do
    script = <<~RUBY
      require "sqinky"

      klass = Class.new do
        include Sqinky::IdentifierEncoding

        attr_accessor :id

        encodes_identifier decodes_as: :decode_id
      end

      record = klass.new
      record.id = 1
      raise "unexpected decoding" unless klass.decode_id(record.id_encoding) == {id: 1}
      record.id = nil
      raise "unexpected encoding" unless record.id_encoding.nil?
      raise "Rails loaded" if defined?(ActiveRecord)
    RUBY

    output, status = Open3.capture2e(RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script)
    expect(status).to be_success, output
  end
end
