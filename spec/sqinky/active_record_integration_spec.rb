# frozen_string_literal: true

require "active_record"

# Exercises the generated methods against a real database instead of stubbed query methods.
RSpec.describe "Sqinky::IdentifierEncoding with Active Record" do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table :sqinky_memberships, force: true do |t|
        t.integer :user_id
        t.integer :group_id
      end
    end
  end

  after(:all) do
    ActiveRecord::Base.remove_connection
  end

  let(:model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "sqinky_memberships"

      def self.name = "SqinkyMembership"

      include Sqinky::IdentifierEncoding

      encodes_identifier decodes_as: :decode_id_encoding
      encodes_identifiers :user_id, :group_id, as: :token, decodes_as: :decode_token
    end
  end
  let(:sqids) { Sqids.new }

  let!(:member) { model.create!(id: 1, user_id: 5, group_id: 9) }
  let!(:orphan) { model.create!(id: 2, user_id: nil, group_id: nil) }
  let!(:partial) { model.create!(id: 3, user_id: 5, group_id: nil) }

  after { model.delete_all }

  describe "valid encodings" do
    it "finds records by single and composite encodings" do
      expect(model.find_by_id_encoding(member.id_encoding)).to eq(member)
      expect(model.find_by_token(member.token)).to eq(member)
      expect(model.find_by_token!(member.token)).to eq(member)
    end

    it "destroys and deletes the matching record only" do
      expect(model.destroy_by_token(member.token)).to eq([member])
      expect(model.delete_by_id_encoding(partial.id_encoding)).to eq(1)
      expect(model.pluck(:id)).to eq([orphan.id])
    end

    it "respects the current scope" do
      expect(model.where(group_id: 9).find_by_id_encoding(member.id_encoding)).to eq(member)
      expect(model.where(group_id: 1).find_by_id_encoding(member.id_encoding)).to be_nil
    end

    it "decodes into the attribute hash" do
      expect(model.decode_token(member.token)).to eq({user_id: 5, group_id: 9})
    end
  end

  # Each of these used to decode into conditions containing nil, which matched rows with NULL columns.
  invalid_encodings = {
    "nil" => nil,
    "an empty string" => "",
    "foreign characters" => "!!!",
    "a non-string" => 123,
    "an encoding with too few values" => Sqids.new.encode([5]),
    "an encoding with too many values" => Sqids.new.encode([5, 9, 1])
  }

  invalid_encodings.each do |description, encoding|
    context "with #{description}" do
      it "does not find a record" do
        expect(model.find_by_token(encoding)).to be_nil
      end

      it "raises RecordNotFound from the bang finder" do
        expect { model.find_by_token!(encoding) }.to raise_error(ActiveRecord::RecordNotFound, /invalid encoding/)
      end

      it "does not destroy or delete any record" do
        expect(model.destroy_by_token(encoding)).to eq([])
        expect(model.delete_by_token(encoding)).to eq(0)
        expect(model.count).to eq(3)
      end

      it "decodes to nil" do
        expect(model.decode_token(encoding)).to be_nil
      end
    end
  end

  context "with a non-canonical alias of a valid encoding" do
    let(:canonical) { member.id_encoding }
    let(:alias_encoding) { "cY" }

    it "rejects the alias although it decodes to the same id" do
      expect(sqids.decode(alias_encoding)).to eq([member.id])
      expect(alias_encoding).not_to eq(canonical)

      expect(model.find_by_id_encoding(canonical)).to eq(member)
      expect(model.find_by_id_encoding(alias_encoding)).to be_nil
      expect(model.decode_id_encoding(alias_encoding)).to be_nil
    end
  end

  context "with min_length padding" do
    let(:padded_model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "sqinky_memberships"

        def self.name = "SqinkyPaddedMembership"

        include Sqinky::IdentifierEncoding

        encodes_identifiers :user_id, :group_id, as: :token, min_length: 20
      end
    end
    let(:padded_member) { padded_model.find(member.id) }

    it "accepts the padded canonical encoding" do
      expect(padded_member.token.length).to eq(20)
      expect(padded_model.find_by_token(padded_member.token)).to eq(padded_member)
    end

    it "rejects unpadded encodings issued before min_length was set" do
      unpadded = member.token
      expect(Sqids.new(min_length: 20).decode(unpadded)).to eq([5, 9])
      expect(padded_model.find_by_token(unpadded)).to be_nil
    end
  end

  context "with canonical: false" do
    let(:lenient_model) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "sqinky_memberships"

        def self.name = "SqinkyLenientMembership"

        include Sqinky::IdentifierEncoding

        encodes_identifier min_length: 20, canonical: false, decodes_as: :decode_id_encoding
        encodes_identifiers :user_id, :group_id, as: :token, min_length: 20, canonical: false
      end
    end
    let(:lenient_member) { lenient_model.find(member.id) }

    it "still issues the padded canonical encoding" do
      expect(lenient_member.token).to eq(Sqids.new(min_length: 20).encode([5, 9]))
    end

    it "accepts unpadded encodings issued before min_length was set" do
      expect(lenient_model.find_by_token(member.token)).to eq(lenient_member)
      expect(lenient_model.find_by_id_encoding(member.id_encoding)).to eq(lenient_member)
    end

    it "accepts non-canonical aliases" do
      expect(lenient_model.find_by_id_encoding("cY")).to eq(lenient_member)
      expect(lenient_model.decode_id_encoding("cY")).to eq({id: member.id})
    end

    it "still rejects encodings with the wrong number of values" do
      expect(lenient_model.find_by_token(sqids.encode([5]))).to be_nil
      expect(lenient_model.find_by_token(sqids.encode([5, 9, 1]))).to be_nil
      expect(lenient_model.delete_by_token("")).to eq(0)
      expect(lenient_model.delete_by_token("!!!")).to eq(0)
      expect(lenient_model.count).to eq(3)
    end

    it "is not forwarded to Sqids" do
      expect(Sqids).to receive(:new).with(min_length: 20).and_call_original
      Class.new(ActiveRecord::Base) do
        include Sqinky::IdentifierEncoding

        encodes_identifier min_length: 20, canonical: false
      end
    end
  end

  context "with a name that collides with an Active Record method" do
    it "raises instead of replacing the method" do
      expect { model.encodes_identifier(as: :id) }.to raise_error(ArgumentError, /SqinkyMembership already defines #id\./)
      expect { model.encodes_identifier(as: :to_param) }.to raise_error(ArgumentError, /#to_param\./)
      expect(member.id).to eq(1)
    end
  end

  context "with a single-attribute encoding passed to an extra-values finder" do
    it "does not ignore the surplus values" do
      expect(model.find_by_id_encoding(sqids.encode([member.id, 999]))).to be_nil
    end
  end
end
