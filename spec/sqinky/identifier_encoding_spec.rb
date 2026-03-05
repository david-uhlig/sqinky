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
      expect(subject).to receive(:encodes_identifiers).with(:id, as: nil, decodes_as: nil)
      subject.encodes_identifier
    end

    it "delegates to #encodes_identifiers" do
      expect(subject).to receive(:encodes_identifiers).with(:other_id, as: :token, decodes_as: :token_decoding, min_length: 10, alphabet: "abc", blocklist: [])
      subject.encodes_identifier(:other_id, as: :token, decodes_as: :token_decoding, min_length: 10, alphabet: "abc", blocklist: [])
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
        expect(Sqids).to receive(:new).with(min_length: 10, alphabet: "abc", blocklist: [])
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
    end

    context "multiple attributes" do
      before do
        subject.attr_accessor(:id, :other_id, :last_id)
        subject.encodes_identifiers(:id, :other_id, :last_id, as: :id_encoding)
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
  end
end
