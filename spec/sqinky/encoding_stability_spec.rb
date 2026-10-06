# frozen_string_literal: true

require "active_support"

# Issued encodings end up in URLs and must never change. These reference values were produced by sqids 0.2.2. If this
# spec fails after a sqids update, that release changed the algorithm: do not allow it in the gemspec.
RSpec.describe "Sqinky::IdentifierEncoding encoding stability" do
  def encoder(*attributes, **options)
    Class.new do
      include Sqinky::IdentifierEncoding

      attr_accessor(*attributes)

      encodes_identifiers(*attributes, as: :token, decodes_as: :decode_token, **options)
    end
  end

  {
    "a single value" => [{id: 1}, {}, "Uk"],
    "multiple values" => [{a: 1, b: 2, c: 3}, {}, "86Rf07"],
    "the maximum value" => [{id: Sqids.max_value}, {}, "EGqHPBv9w2Vf"],
    "min_length padding" => [{id: 1}, {min_length: 10}, "UkLWZg9DAJ"],
    "a custom alphabet" => [{a: 1, b: 2, c: 3}, {alphabet: "abcdef0123456789"}, "a83a2e"],
    "the default blocklist" => [{id: 4572721}, {}, "JExTR"],
    "a custom blocklist" => [{a: 1, b: 2, c: 3}, {blocklist: Set["86Rf07"]}, "se8ojk"]
  }.each do |description, (values, options, expected)|
    it "encodes and decodes #{description}" do
      klass = encoder(*values.keys, **options)
      instance = klass.new
      values.each { |attribute, value| instance.public_send(:"#{attribute}=", value) }

      expect(instance.token).to eq(expected)
      expect(klass.decode_token(expected)).to eq(values)
    end
  end
end
