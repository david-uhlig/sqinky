# frozen_string_literal: true

require "active_support/concern"
require "sqids"

module Sqinky
  # Add Sqids-based identifier encoding/decoding helpers to Active Record models.
  #
  # {Sqids}[https://sqids.org/] is an open-source library that lets you generate short unique identifiers from numbers.
  # These IDs are URL-safe, can encode several numbers, and do not contain common profanity words.
  #
  # *Note*: Sqids encodings are computed dynamically from record attributes and do not need to be stored.
  #
  # Sqinky adds a thin access layer on top of Sqids to work effortlessly with Sqids in Active Record models.
  # It generates an encoding method, e.g. +id_encoding+ and database methods for finding and deleting matching records,
  # e.g. +find_by_id_encoding+, +find_by_id_encoding!+, +destroy_by_id_encoding+, and +delete_by_id_encoding+.  Sqinky
  # does not persist the encoding to the database. It supports encodings composed of multiple attributes, and multiple
  # encodings per model.
  module IdentifierEncoding
    extend ActiveSupport::Concern

    class_methods do
      # Generates methods for creating and consuming a single identifier attribute encoding, typically for the primary
      # key +id+.
      #
      # #### Note
      # * If the +as+ argument is missing, it is generated as +<attribute>_encoding+.
      # * The referenced +attribute+ must be present when the generated +#{as}+ method is called.
      #
      # #### Generates
      # * +#<as>+ - Generates the Sqids encoding from the attribute value.
      # * +#<as>!+ - Generates the Sqids encoding from the attribute value. Raises +ArgumentError+ the attribute value is noninteger.
      # * +#<decodes_as>(encoding)+ - Decodes a Sqids encoding back to the attribute-value hash. (Optional)
      # * +.find_by_<as>(encoding)+ - Finds record by +encoding+ or returns nil.
      # * +.find_by_<as>!(encoding)+ - Finds record by +encoding+ or raises +ActiveRecord::RecordNotFound+ error.
      # * +.destroy_by_<as>(encoding)+ - Destroys record by +encoding+.
      # * +.delete_by_<as>(encoding)+ - Deletes record by +encoding+.
      #
      # @param attribute [Symbol] Attribute to encode. Must take positive +Integer+ values.
      # @param as [Symbol, nil] Optional name of the instance method that returns the encoding. Also part of the database methods, e.g. +find_by_<as>+. If missing, it is generated from the attribute name, e.g. +id_encoding+.
      # @param decodes_as [Symbol, nil] Optional class method name that, when given an encoding, returns a hash of decoded attribute values. If missing, no such method is generated.
      # @param sqids_options [Hash] Options forwarded to +Sqids.new+, e.g. +alphabet+, +min_length+, and +blocklist+.
      #
      # @return [Void]
      #
      # @see .encodes_identifiers
      def encodes_identifier(attribute = :id, as: nil, decodes_as: nil, **sqids_options)
        encodes_identifiers(attribute, as: as, decodes_as: decodes_as, **sqids_options)
      end

      # Generates methods for creating and consuming a single or multiple identifier attribute encoding.
      #
      # #### Note
      # * If the +as+ argument is missing, it is generated as +<attribute>_encoding+. If multiple attributes are present they are joined by +_and_+, e.g. +<attribute>_and_<attribute>_encoding+.
      # * The referenced +attribute+ must be present when the generated +#{as}+ method is called.
      #
      # #### Generates
      # * +#<as>+ - Generates the Sqids encoding from the attribute values.
      # * +#<as>!+ - Generates the Sqids encoding from the attribute values. Raises +ArgumentError+ if any attribute value is noninteger.
      # * +#<decodes_as>(encoding)+ - Decodes a Sqids encoding back to the attributes-values hash. (Optional)
      # * +.find_by_<as>(encoding)+ - Finds record by +encoding+ or returns nil.
      # * +.find_by_<as>!(encoding)+ - Finds record by +encoding+ or raises +ActiveRecord::RecordNotFound+ error.
      # * +.destroy_by_<as>(encoding)+ - Destroys record by +encoding+.
      # * +.delete_by_<as>(encoding)+ - Deletes record by +encoding+.
      #
      # ### Usage
      #
      # @example Basic usage for an `id` primary key
      #   class Post < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Encodes the `id` attribute into `id_encoding`
      #     encodes_identifier
      #   end
      #
      #   post = Post.create!(title: "Hello")
      #   post.id           # => 1
      #   post.id_encoding  # => "Uk"
      #   Post.find_by_id_encoding("Uk")   # => #<Post id: 1, ...>
      #   Post.find_by_id_encoding!("Uk")  # => Same as above, raises if not found.
      #   Post.destroy_by_id_encoding("Uk")
      #   Post.delete_by_id_encoding("Uk")
      #
      # @example Encoding multiple attributes
      #   class Invitation < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Encode `account_id` and `id`
      #     encodes_identifiers :id, :account_id
      #   end
      #
      #   invitation = Invitation.create!(account_id: 42)
      #   invitation.id                         # => 1
      #   invitation.id_and_account_id_encoding # => "ySrS"
      #   Invitation.find_by_id_and_account_id_encoding("ySrS")
      #   # => Internally calls find_by(id: 1, account_id: 42)
      #   # => #<Invitation id: 1, account_id: 42, ...>
      #   Invitation.find_by_id_and_account_id_encoding!("ySrS")
      #   Invitation.destroy_by_id_and_account_id_encoding("ySrS")
      #   Invitation.delete_by_id_and_account_id_encoding("ySrS")
      #
      # @example Renaming the helper methods
      #   class Invitation < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Encode `account_id` and `id` into `token`
      #     encodes_identifiers :id, :account_id, as: :token
      #   end
      #
      #   invitation = Invitation.create!(account_id: 42)
      #   invitation.id                        # => 1
      #   invitation.token                     # => "ySrS"
      #   Invitation.find_by_token("ySrS")
      #   # => Internally calls find_by(id: 1, account_id: 42)
      #   # => #<Invitation id: 1, account_id: 42, ...>
      #   Invitation.find_by_token!("ySrS")
      #   Invitation.destroy_by_token("ySrS")
      #   Invitation.delete_by_token("ySrS")
      #
      # @example Generating a decoding helper
      #   class Order < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Add a decoding helper that returns the decoded attributes hash
      #     encodes_identifiers :shop_id, :id,
      #                         as: :public_id,
      #                         decodes_as: :decode_public_id
      #   end
      #
      #   order = Order.create!(shop_id: 10)
      #   encoded = order.public_id           # => e.g. "86Rf07"
      #   Order.decode_public_id(encoded)
      #   # => { shop_id: 10, id: 1 }
      #
      # @example Passing Sqids options through
      #   class Comment < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Use a custom alphabet and minimum length for generated IDs
      #     encodes_identifier :id,
      #                        alphabet: "abc",
      #                        min_length: 10
      #   end
      #
      #   comment = Comment.create!
      #   comment.id_encoding        # => Always at least 10 characters, consists only of "abc" characters.
      #
      # @example Multiple encoders in a single model
      #   class Membership < ApplicationRecord
      #     include Sqinky::IdentifierEncoding
      #
      #     # Encodes +id+ into +id_encoding+.
      #     encode_identifier
      #     # Encodes +id+ (again) into +code+ with the +abc+ alphabet.
      #     encode_identifier as: :code, alphabet: "abc"
      #     # Encodes both +user_id+ and +group_id+ into a single token. Make sure to
      #     # use a different +as+ (and +decodes_as+) value for each encoder, otherwise they will overwrite
      #     # each other.
      #     encodes_identifiers :user_id, :group_id, as: :membership_token
      #   end
      #
      #   membership = Membership.create!(user_id: 44, group_id: 12)
      #   token = membership.id_encoding
      #   # => "Uk"
      #   Membership.find_by_id_encoding(token)
      #   # => Internally calls `find_by(id: 1)`
      #
      #   code = membership.code
      #   # => "aa"
      #   Membership.find_by_code(code)
      #   # => Internally calls `find_by(id: 1)`
      #
      #   membership_token = membership.membership_token
      #   # => "7edZ"
      #   Membership.find_by_membership_token(membership_token)
      #   # => Internally calls `find_by(user_id: 44, group_id: 12)
      #
      # @return [Void]
      #
      # @param attributes [Array<Symbol>] List of attributes to encode. At least one attribute must be provided.
      # @param as [Symbol, nil] Name of the instance method that returns the encoding. Also part of the database methods, e.g. +find_by_<as>+. If missing, it is generated from the attribute names, e.g. +id_encoding+ or +id_and_tenant_id_encoding+.
      # @param decodes_as [Symbol, nil] Optional class method name that, when given an encoding, returns a hash of decoded attribute values. If missing, no such method is generated.
      # @param sqids_options [Hash] Options forwarded to +Sqids.new+, e.g. +alphabet+, +min_length+, and +blocklist+.
      #
      # @raise [ArgumentError] if no attributes are given.
      #
      # @return [void]
      def encodes_identifiers(*attributes, as: nil, decodes_as: nil, **sqids_options)
        if attributes.compact_blank!.empty?
          raise ArgumentError, <<~MSG
            Must specify at least one attribute. Hint: Use `encodes_identifier` instead to encode the primary key 
            without having to specify the `:id` attribute.
          MSG
        end
        coder = Sqids.new(**sqids_options)
        encoding_method_name = as.presence || attributes.join("_and_").concat("_encoding")
        database_methods = %w[find_by find_by! destroy_by delete_by].map do |base_method|
          # ["find_by!", "find_by_id_encoding!"]
          [base_method, base_method.gsub(/(\w+?)(!?)\b/, "\\1_#{encoding_method_name}\\2")]
        end

        # @!method <encoding_method_name>
        #   Returns the Sqids-encoded identifier for the configured attributes.
        #
        #   Will return an irreversible encoding if any attribute is noninteger. Use the bang method to ensure a
        #   reversible encoding.
        #
        #   @raises [ArgumentError] If any of the attributes is a number below 0 or above +Sqids.max_value+.
        #   @return [String, nil] Encoded identifier or nil if any of the attributes is +blank?+.
        define_method(encoding_method_name) do
          values = attributes.map { send(_1) }
          values.any?(&:blank?) ? nil : coder.encode(values)
        end

        # @!method <encoding_method_name>
        #   Returns the Sqids-encoded identifier for the configured attributes.
        #
        #   Ensures a reversible encoding.
        #
        #   @raises [ArgumentError] If any of the attributes is not a positive integer between 0 and +Sqids.max_value+
        #   @return [String] Encoded identifier.
        define_method("#{encoding_method_name}!") do
          values = attributes.map { send(_1) }
          unless values.all? { _1.is_a?(Integer) }
            raise ArgumentError, <<~MSG
              Encoding supports integers between 0 and #{Sqids.max_value}.

              Received: #{attributes.zip(values).to_h}
            MSG
          end
          coder.encode(values)
        end

        database_methods.each do |base_method, dynamic_method|
          # @!method find_by_<dynamic_method>(encoding)
          #   Find a record by decoding the given encoding into the configured
          #   attributes, then delegating to the corresponding Active Record
          #   query method (e.g. `find_by`, `find_by!`, `destroy_by`, `delete_by`).
          #
          #   @param encoding [String] Sqids-encoded identifier
          #   @return [Object, nil] model instance or result of the delegated
          #     query method
          #
          # The actual method names are generated dynamically, e.g.:
          # `find_by_id_encoding`, `find_by_id_encoding!`,
          # `destroy_by_id_encoding`, `delete_by_id_encoding`.
          define_singleton_method(dynamic_method) do |encoding|
            values = coder.decode(encoding)
            args = attributes.zip(values).to_h
            send(base_method, args)
          end
        end

        unless decodes_as.blank?
          decoding_method_name = decodes_as.to_s
          # @!method <decodes_as>(encoding)
          #   Decode the given encoding into a hash mapping each configured
          #   attribute to its decoded numeric value.
          #
          #   @param encoding [String] Sqids-encoded identifier
          #   @return [Hash{Symbol=>Integer}] decoded attribute values
          define_singleton_method(decoding_method_name) do |encoding|
            values = coder.decode(encoding)
            attributes.zip(values).to_h
          end
        end
      end
    end
  end
end
