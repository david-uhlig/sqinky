# frozen_string_literal: true

require "active_record"
require "active_support"

class ApplicationRecord
  class << self
    def find_by
    end

    def find_by!
    end

    def destroy_by
    end

    def delete_by
    end
  end
end

RSpec.describe Sqinky::IdentifierEncoding do
  subject do
    Class.new(ApplicationRecord) do
      include Sqinky::IdentifierEncoding
    end
  end
  let(:instance) { subject.new }

  describe "#encodes_identifier" do
    it "delegates default values to #encodes_identifiers" do
      expect(subject).to receive(:encodes_identifiers).with(:id, as: nil, decodes_as: nil, canonical: true)
      subject.encodes_identifier
    end

    it "delegates to #encodes_identifiers" do
      expect(subject).to receive(:encodes_identifiers).with(:other_id, as: :token, decodes_as: :token_decoding, canonical: false, min_length: 10, alphabet: "abc", blocklist: [])
      subject.encodes_identifier(:other_id, as: :token, decodes_as: :token_decoding, canonical: false, min_length: 10, alphabet: "abc", blocklist: [])
    end
  end

  describe "#encodes_identifiers" do
    describe "attributes parameter" do
      it "raises ArgumentError without attributes" do
        expect { subject.encodes_identifiers }.to raise_error(ArgumentError)
        expect { subject.encodes_identifiers("") }.to raise_error(ArgumentError)
        expect { subject.encodes_identifiers(:"") }.to raise_error(ArgumentError)
      end

      context "single attribute" do
        let(:attribute) { :some_id }

        it "generates instance methods named by the attribute" do
          subject.encodes_identifiers(attribute)
          expect(instance).to respond_to("#{attribute}_encoding")
          expect(instance).to respond_to("#{attribute}_encoding!")
        end

        it "generates class methods named by the attribute" do
          subject.encodes_identifiers(attribute)
          expect(subject).to respond_to("find_by_#{attribute}_encoding")
          expect(subject).to respond_to("find_by_#{attribute}_encoding!")
          expect(subject).to respond_to("destroy_by_#{attribute}_encoding")
          expect(subject).to respond_to("delete_by_#{attribute}_encoding")
        end
      end

      context "multiple attributes" do
        let(:attributes) { [:id, :other_id, :last_id] }
        let(:expected_method_name) { attributes.join("_and_").concat("_encoding") }

        it "generates instance methods named by the attribute names" do
          subject.encodes_identifiers(*attributes)
          expect(instance).to respond_to(expected_method_name)
          expect(instance).to respond_to("#{expected_method_name}!")
        end

        it "generates class methods named by the attribute names" do
          subject.encodes_identifiers(*attributes)
          expect(subject).to respond_to("find_by_#{expected_method_name}")
          expect(subject).to respond_to("find_by_#{expected_method_name}!")
          expect(subject).to respond_to("destroy_by_#{expected_method_name}")
          expect(subject).to respond_to("delete_by_#{expected_method_name}")
        end
      end
    end

    describe "as: parameter" do
      it "generates named instance methods" do
        subject.encodes_identifiers(:id, as: :token)
        expect(instance).to respond_to(:token)
        expect(instance).to respond_to(:token!)
      end

      it "generates named class methods" do
        subject.encodes_identifiers(:id, as: :token)
        expect(subject).to respond_to(:find_by_token)
        expect(subject).to respond_to(:find_by_token!)
        expect(subject).to respond_to(:destroy_by_token)
        expect(subject).to respond_to(:delete_by_token)
      end
    end

    describe "decodes_as: parameter" do
      it "generates named decoding class method" do
        subject.encodes_identifiers(:id, decodes_as: :token_decoding)
        expect(subject).to respond_to(:token_decoding)
      end
    end

    describe "sqids parameters" do
      it "passes sqids arguments to Sqids.new" do
        expect(Sqids).to receive(:new).with(min_length: 10, alphabet: "abc", blocklist: []).and_call_original
        subject.encodes_identifiers(:id, min_length: 10, alphabet: "abc", blocklist: [])
      end
    end
  end

  describe "#id_encoding" do
    context "single attribute" do
      before do
        subject.attr_accessor(:id)
        subject.encodes_identifiers(:id)
      end

      it "returns nil when the identifier value is nil" do
        instance.id = nil
        expect(instance.id_encoding).to be_nil
      end

      it "raises an ArgumentError when the identifier is a negative number" do
        instance.id = -1
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end

      it "returns the encoding when the identifier is zero" do
        sqids = Sqids.new
        instance.id = 0
        expect(instance.id_encoding).to eq(sqids.encode([instance.id]))
      end

      it "returns the encoding when the identifier is in range" do
        sqids = Sqids.new
        instance.id = 13756238
        expect(instance.id).to be <= Sqids.max_value
        expect(instance.id_encoding).to eq(sqids.encode([instance.id]))
      end

      it "raises an ArgumentError when the identifier is too large" do
        instance.id = Sqids.max_value + 1
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end

      it "returns nil when the identifier is blank" do
        instance.id = ""
        expect(instance.id_encoding).to be_nil
      end

      it "raises an ArgumentError when the identifier is noninteger" do
        instance.id = 1.5
        expect { instance.id_encoding }.to raise_error(ArgumentError, /1\.5/)
        instance.id = "abc"
        expect { instance.id_encoding }.to raise_error(ArgumentError)
        instance.id = :abc
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end
    end

    context "multiple attributes" do
      before do
        subject.attr_accessor(:id, :other_id, :last_id)
        subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      end

      it "raises an ArgumentError when one identifier is noninteger" do
        instance.id = 1
        instance.other_id = 2.5
        instance.last_id = 3
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end

      it "returns nil when one identifier value is nil" do
        instance.id = 1
        instance.other_id = nil
        instance.last_id = 54345
        expect(instance.id_encoding).to be_nil
      end

      it "raises an ArgumentError when one identifier is a negative number" do
        instance.id = -1
        instance.other_id = 32423
        instance.last_id = 25675
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end

      it "returns the encoding when one identifier is zero" do
        sqids = Sqids.new
        instance.id = 4645
        instance.other_id = 353
        instance.last_id = 0
        expect(instance.id_encoding).to eq(sqids.encode([instance.id, instance.other_id, instance.last_id]))
      end

      it "returns the encoding when the identifiers are in range" do
        sqids = Sqids.new
        instance.id = 13756238
        instance.other_id = 4234
        instance.last_id = 7575756234
        expect(instance.id).to be <= Sqids.max_value
        expect(instance.other_id).to be <= Sqids.max_value
        expect(instance.last_id).to be <= Sqids.max_value
        expect(instance.id_encoding).to eq(sqids.encode([instance.id, instance.other_id, instance.last_id]))
      end

      it "raises an ArgumentError when one identifier is too large" do
        instance.id = Sqids.max_value + 1
        instance.other_id = 0
        instance.last_id = 25675
        expect { instance.id_encoding }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#id_encoding!" do
    context "single attribute" do
      before do
        subject.attr_accessor(:id)
        subject.encodes_identifiers(:id)
      end

      it "raises ArgumentError when the identifier value is nil" do
        instance.id = nil
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end

      it "raises an ArgumentError when the identifier is a negative number" do
        instance.id = -1
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end

      it "returns the encoding when the identifier is zero" do
        sqids = Sqids.new
        instance.id = 0
        expect(instance.id_encoding!).to eq(sqids.encode([instance.id]))
      end

      it "returns the encoding when the identifier is in range" do
        sqids = Sqids.new
        instance.id = 13756238
        expect(instance.id).to be <= Sqids.max_value
        expect(instance.id_encoding!).to eq(sqids.encode([instance.id]))
      end

      it "raises an ArgumentError when the identifier is too large" do
        instance.id = Sqids.max_value + 1
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end
    end

    context "multiple attributes" do
      before do
        subject.attr_accessor(:id, :other_id, :last_id)
        subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      end

      it "raises ArgumentError when one identifier values is nil" do
        instance.id = 1
        instance.other_id = nil
        instance.last_id = 54345
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end

      it "raises an ArgumentError when one identifier is a negative number" do
        instance.id = -1
        instance.other_id = 32423
        instance.last_id = 25675
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end

      it "returns the encoding when one identifier is zero" do
        sqids = Sqids.new
        instance.id = 4645
        instance.other_id = 353
        instance.last_id = 0
        expect(instance.id_encoding!).to eq(sqids.encode([instance.id, instance.other_id, instance.last_id]))
      end

      it "returns the encoding when the identifiers are in range" do
        sqids = Sqids.new
        instance.id = 13756238
        instance.other_id = 4234
        instance.last_id = 7575756234
        expect(instance.id).to be <= Sqids.max_value
        expect(instance.other_id).to be <= Sqids.max_value
        expect(instance.last_id).to be <= Sqids.max_value
        expect(instance.id_encoding!).to eq(sqids.encode([instance.id, instance.other_id, instance.last_id]))
      end

      it "raises an ArgumentError when one identifier is too large" do
        instance.id = Sqids.max_value + 1
        instance.other_id = 0
        instance.last_id = 25675
        expect { instance.id_encoding! }.to raise_error(ArgumentError)
      end

      it "raises an ArgumentError when one identifier is noninteger" do
        instance.id = 255
        instance.other_id = 909
        instance.last_id = 12312
        expect {
          instance.id = "abc"
          instance.id_encoding!
        }.to raise_error(ArgumentError)
        expect {
          instance.other_id = true
          instance.id_encoding!
        }.to raise_error(ArgumentError)
        expect {
          instance.last_id = false
          instance.id_encoding!
        }.to raise_error(ArgumentError)
        expect {
          instance.id = 12.5
          instance.id_encoding!
        }.to raise_error(ArgumentError)
        expect {
          instance.other_id = ""
          instance.id_encoding!
        }.to raise_error(ArgumentError)
        expect {
          instance.last_id = :abc
          instance.id_encoding!
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe "id_decoding" do
    it "decodes a valid encoding" do
      subject.attr_accessor(:id)
      subject.encodes_identifiers(:id, decodes_as: :token_decoding)
      instance.id = 634
      expect(subject.token_decoding(instance.id_encoding)).to eq({id: 634})
    end

    it "decodes a multi attribute encoding" do
      subject.attr_accessor(:id, :other_id, :last_id)
      subject.encodes_identifiers(:id, :other_id, :last_id, as: :token, decodes_as: :token_decoding)
      instance.id = 2165
      instance.other_id = 87686
      instance.last_id = 3246
      expect(subject.token_decoding(instance.token)).to eq({id: 2165, other_id: 87686, last_id: 3246})
    end

    context "encoding length" do
      let(:max) { Sqids.max_value }

      it "decodes the longest valid encoding" do
        subject.attr_accessor(:id, :other_id)
        subject.encodes_identifiers(:id, :other_id, as: :token, decodes_as: :token_decoding)
        instance.id = max
        instance.other_id = max
        expect(subject.token_decoding(instance.token)).to eq({id: max, other_id: max})
      end

      it "decodes the longest valid encoding padded to min_length" do
        subject.attr_accessor(:id)
        subject.encodes_identifiers(:id, decodes_as: :token_decoding, min_length: 255)
        instance.id = max
        expect(instance.id_encoding.length).to eq(255)
        expect(subject.token_decoding(instance.id_encoding)).to eq({id: max})
      end

      it "rejects a longer encoding without decoding it" do
        subject.encodes_identifiers(:id, decodes_as: :token_decoding)
        expect_any_instance_of(Sqids).not_to receive(:decode)
        expect(subject.token_decoding("U" * 100_000)).to be_nil
      end

      it "rejects an encoding within the length limit that decodes to a value above Sqids.max_value" do
        subject.encodes_identifiers(:id, decodes_as: :token_decoding)
        oversized = "UZZZZZZZZZZZ"
        expect(oversized.length).to eq(Sqids.new.encode([max]).length)
        expect(subject.token_decoding(oversized)).to be_nil
      end

      it "accepts encodings issued with the largest min_length if not canonical" do
        subject.attr_accessor(:id)
        subject.encodes_identifiers(:id, decodes_as: :token_decoding, canonical: false)
        issued = Sqids.new(min_length: 255).encode([1])
        expect(subject.token_decoding(issued)).to eq({id: 1})
        expect(subject.token_decoding("#{issued}U")).to be_nil
      end
    end
  end

  describe ".find_by_id_encoding" do
    it "delegates a single attribute to find_by" do
      subject.attr_accessor(:id)
      subject.encodes_identifiers(:id)
      instance.id = 6345
      expect(subject).to receive(:find_by).with({id: 6345})
      subject.find_by_id_encoding(instance.id_encoding)
    end

    it "delegates multiple attributes to find_by" do
      subject.attr_accessor(:id, :other_id, :last_id)
      subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      instance.id = 2341
      instance.other_id = 298
      instance.last_id = 123545
      expect(subject).to receive(:find_by).with({id: 2341, other_id: 298, last_id: 123545})
      subject.find_by_id_encoding(instance.id_encoding)
    end
  end

  describe ".find_by_id_encoding!" do
    it "delegates a single attribute to find_by!" do
      subject.attr_accessor(:id)
      subject.encodes_identifiers(:id)
      instance.id = 6345
      expect(subject).to receive(:find_by!).with({id: 6345})
      subject.find_by_id_encoding!(instance.id_encoding)
    end

    it "delegates multiple attributes to find_by!" do
      subject.attr_accessor(:id, :other_id, :last_id)
      subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      instance.id = 2341
      instance.other_id = 298
      instance.last_id = 123545
      expect(subject).to receive(:find_by!).with({id: 2341, other_id: 298, last_id: 123545})
      subject.find_by_id_encoding!(instance.id_encoding)
    end
  end

  describe ".destroy_by_id_encoding" do
    it "delegates a single attribute to destroy_by" do
      subject.attr_accessor(:id)
      subject.encodes_identifiers(:id)
      instance.id = 6345
      expect(subject).to receive(:destroy_by).with({id: 6345})
      subject.destroy_by_id_encoding(instance.id_encoding)
    end

    it "delegates multiple attributes to destroy_by" do
      subject.attr_accessor(:id, :other_id, :last_id)
      subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      instance.id = 2341
      instance.other_id = 298
      instance.last_id = 123545
      expect(subject).to receive(:destroy_by).with({id: 2341, other_id: 298, last_id: 123545})
      subject.destroy_by_id_encoding(instance.id_encoding)
    end
  end

  describe ".delete_by_id_encoding" do
    it "delegates a single attribute to delete_by" do
      subject.attr_accessor(:id)
      subject.encodes_identifiers(:id)
      instance.id = 6345
      expect(subject).to receive(:delete_by).with({id: 6345})
      subject.delete_by_id_encoding(instance.id_encoding)
    end

    it "delegates multiple attributes to delete_by" do
      subject.attr_accessor(:id, :other_id, :last_id)
      subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
      instance.id = 2341
      instance.other_id = 298
      instance.last_id = 123545
      expect(subject).to receive(:delete_by).with({id: 2341, other_id: 298, last_id: 123545})
      subject.delete_by_id_encoding(instance.id_encoding)
    end
  end

  describe "child classes" do
    let(:base_class) do
      Class.new(ApplicationRecord) do
        include Sqinky::IdentifierEncoding

        encodes_identifier
      end
    end

    subject do
      Class.new(base_class) do
        attr_accessor :id
      end
    end

    let(:instance) { subject.new }

    it "inherit encoding and database methods" do
      expect(instance).to respond_to :id_encoding
      expect(instance).to respond_to :id_encoding!
      expect(subject).to respond_to :find_by_id_encoding
      expect(subject).to respond_to :find_by_id_encoding!
      expect(subject).to respond_to :delete_by_id_encoding
      expect(subject).to respond_to :destroy_by_id_encoding
    end

    it "return the encoding when the identifier is in range" do
      sqids = Sqids.new
      instance.id = 13756238
      expect(instance.id).to be <= Sqids.max_value
      expect(instance.id_encoding).to eq(sqids.encode([instance.id]))
    end

    it "may redeclare an inherited encoding" do
      expect { subject.encodes_identifier(alphabet: "abcdef0123456789") }.not_to raise_error

      instance.id = 1
      expect(instance.id_encoding).to eq(Sqids.new(alphabet: "abcdef0123456789").encode([1]))
    end
  end

  describe "method name collisions" do
    before { subject.attr_accessor(:id) }

    it "raises when the encoding method replaces an attribute" do
      expect { subject.encodes_identifier(as: :id) }.to raise_error(ArgumentError, /defines #id\. Choose/)
    end

    it "raises when the encoding method replaces a hand-written method" do
      subject.define_method(:token) { "hand-written" }

      expect { subject.encodes_identifier(as: :token) }.to raise_error(ArgumentError, /#token/)
      expect(instance.token).to eq("hand-written")
    end

    it "raises when a class method replaces an existing class method" do
      expect { subject.encodes_identifier(decodes_as: :find_by) }.to raise_error(ArgumentError, /\.find_by\b/)
    end

    it "raises when two encodings in the same class share a name" do
      subject.encodes_identifier(as: :token)

      expect { subject.encodes_identifier(as: :token, min_length: 10) }
        .to raise_error(ArgumentError, /#token, #token!, \.find_by_token, \.find_by_token!, \.destroy_by_token, \.delete_by_token/)
    end

    it "defines none of the methods when one of them collides" do
      expect { subject.encodes_identifier(decodes_as: :find_by) }.to raise_error(ArgumentError)

      expect(instance).not_to respond_to(:id_encoding)
      expect(subject).not_to respond_to(:find_by_id_encoding)
    end
  end
end
