# frozen_string_literal: true

# Sqinky::Coder must return exactly what Sqids returns, so these examples use Sqids as the reference.
RSpec.describe Sqinky::Coder do
  {
    "the default options" => {},
    "min_length" => {min_length: 10},
    "a custom alphabet" => {alphabet: "abcdefghijklmnopqrstuvwxyz"},
    "a custom blocklist" => {blocklist: Set["86Rf07", "Uk", "xyz9", "abc", "LONG"]},
    "a custom alphabet and blocklist" => {alphabet: "0123456789abcdef", blocklist: %w[dead beef cafe 0ff1ce bad f00d]},
    "an empty blocklist" => {blocklist: []}
  }.each do |description, options|
    context "with #{description}" do
      let(:coder) { described_class.new(**options) }
      let(:sqids) { Sqids.new(options) }
      let(:blocklist) { described_class::Blocklist.new(options[:blocklist] || Sqids::DEFAULT_BLOCKLIST, alphabet:) }
      let(:alphabet) { options[:alphabet] || Sqids::DEFAULT_ALPHABET }

      it "encodes like Sqids" do
        random = Random.new(1)
        numbers = (0..20_000).each_slice(1).to_a +
          Array.new(2_000) { [random.rand(Sqids.max_value)] } +
          Array.new(2_000) { Array.new(random.rand(2..4)) { random.rand(10_000) } }

        mismatches = numbers.reject { coder.encode(_1) == sqids.encode(_1) }

        expect(mismatches).to be_empty
      end

      it "decodes like Sqids" do
        encoding = sqids.encode([1, 2, 3])

        expect(coder.decode(encoding)).to eq([1, 2, 3])
      end

      it "blocks the same words as Sqids, in every position" do
        words = (options[:blocklist] || Sqids::DEFAULT_BLOCKLIST).to_a
        filler = alphabet[0, 2]
        candidates = words.flat_map do |word|
          [word, word.upcase, "#{filler}#{word}", "#{word}#{filler}", "#{filler}#{word}#{filler}", word[0..-2], word[1..]]
        end

        mismatches = candidates.reject { blocklist.blocked?(_1) == sqids.send(:blocked_id?, _1) }

        expect(mismatches).to be_empty
      end

      it "blocks the same random encodings as Sqids" do
        random = Random.new(2)
        characters = alphabet.chars
        candidates = Array.new(20_000) { Array.new(random.rand(1..14)) { characters.sample(random:) }.join }

        mismatches = candidates.reject { blocklist.blocked?(_1) == sqids.send(:blocked_id?, _1) }

        expect(mismatches).to be_empty
      end
    end
  end

  it "re-generates a blocked encoding like Sqids" do
    # 4572721 encodes to "aho1e" without a blocklist, which the default blocklist blocks.
    expect(Sqids.new(blocklist: []).encode([4572721])).to eq("aho1e")
    expect(described_class.new.encode([4572721])).to eq("JExTR")
  end

  it "raises for invalid options like Sqids" do
    expect { described_class.new(alphabet: "ab") }.to raise_error(ArgumentError, /at least 3/)
    expect { described_class.new(min_length: 256) }.to raise_error(TypeError)
  end
end
