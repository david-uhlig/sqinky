# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"
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

    # The largest +min_length+ that +Sqids.new+ accepts.
    SQIDS_MAX_MIN_LENGTH = 255

    class_methods do
      # Generates methods for creating and consuming a single identifier attribute encoding, typically for the primary
      # key +id+.
      #
      # #### Note
      # * If the +as+ argument is missing, it is generated as +<attribute>_encoding+.
      # * The referenced +attribute+ must be present when the generated +#{as}+ method is called.
      #
      # #### Generates
      # * +#<as>+ - Generates the Sqids encoding from the attribute value. Returns nil if the value is blank, raises +ArgumentError+ if it is noninteger.
      # * +#<as>!+ - Generates the Sqids encoding from the attribute value. Raises +ArgumentError+ if the attribute value is noninteger, including nil.
      # * +.<decodes_as>(encoding)+ - Decodes a Sqids encoding back to the attribute-value hash. (Optional)
      # * +.find_by_<as>(encoding)+ - Finds record by +encoding+ or returns nil.
      # * +.find_by_<as>!(encoding)+ - Finds record by +encoding+ or raises +ActiveRecord::RecordNotFound+ error.
      # * +.destroy_by_<as>(encoding)+ - Destroys record by +encoding+.
      # * +.delete_by_<as>(encoding)+ - Deletes record by +encoding+.
      #
      # @param attribute [Symbol] Attribute to encode. Must take positive +Integer+ values.
      # @param as [Symbol, nil] Optional name of the instance method that returns the encoding. Also part of the database methods, e.g. +find_by_<as>+. If missing, it is generated from the attribute name, e.g. +id_encoding+.
      # @param decodes_as [Symbol, nil] Optional class method name that, when given an encoding, returns a hash of decoded attribute values. If missing, no such method is generated.
      # @param canonical [Boolean] If +true+ (default), only the canonical encoding of the decoded values is accepted. Set to +false+ to also accept non-canonical encodings, e.g. those issued before +min_length+ was raised or +blocklist+ was changed. Encodings with the wrong number of values are rejected either way.
      # @param sqids_options [Hash] Options forwarded to +Sqids.new+, e.g. +alphabet+, +min_length+, and +blocklist+.
      #
      # @return [void]
      #
      # @see .encodes_identifiers
      def encodes_identifier(attribute = :id, as: nil, decodes_as: nil, canonical: true, **sqids_options)
        encodes_identifiers(attribute, as: as, decodes_as: decodes_as, canonical: canonical, **sqids_options)
      end

      # Generates methods for creating and consuming a single or multiple identifier attribute encoding.
      #
      # #### Note
      # * If the +as+ argument is missing, it is generated as +<attribute>_encoding+. If multiple attributes are present they are joined by +_and_+, e.g. +<attribute>_and_<attribute>_encoding+.
      # * The referenced +attribute+ must be present when the generated +#{as}+ method is called.
      #
      # #### Generates
      # * +#<as>+ - Generates the Sqids encoding from the attribute values. Returns nil if any value is blank, raises +ArgumentError+ if any value is noninteger.
      # * +#<as>!+ - Generates the Sqids encoding from the attribute values. Raises +ArgumentError+ if any attribute value is noninteger, including nil.
      # * +.<decodes_as>(encoding)+ - Decodes a Sqids encoding back to the attributes-values hash. (Optional)
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
      #   encoded = order.public_id           # => "U6Lg"
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
      #     encodes_identifier
      #     # Encodes +id+ (again) into +code+ with the +abc+ alphabet.
      #     encodes_identifier as: :code, alphabet: "abc"
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
      #   # => Internally calls `find_by(user_id: 44, group_id: 12)`
      #
      # @param attributes [Array<Symbol>] List of attributes to encode. At least one attribute must be provided.
      # @param as [Symbol, nil] Name of the instance method that returns the encoding. Also part of the database methods, e.g. +find_by_<as>+. If missing, it is generated from the attribute names, e.g. +id_encoding+ or +id_and_tenant_id_encoding+.
      # @param decodes_as [Symbol, nil] Optional class method name that, when given an encoding, returns a hash of decoded attribute values. If missing, no such method is generated.
      # @param canonical [Boolean] If +true+ (default), only the canonical encoding of the decoded values is accepted. Set to +false+ to also accept non-canonical encodings, e.g. those issued before +min_length+ was raised or +blocklist+ was changed. Encodings with the wrong number of values are rejected either way.
      # @param sqids_options [Hash] Options forwarded to +Sqids.new+, e.g. +alphabet+, +min_length+, and +blocklist+.
      #
      # @raise [ArgumentError] if no attributes are given, or if a generated method would replace an existing method.
      #
      # @return [void]
      def encodes_identifiers(*attributes, as: nil, decodes_as: nil, canonical: true, **sqids_options)
        if attributes.compact_blank!.empty?
          raise ArgumentError, <<~MSG
            Must specify at least one attribute. Hint: Use `encodes_identifier` instead to encode the primary key
            without having to specify the `:id` attribute.
          MSG
        end
        coder = Sqids.new(**sqids_options)
        encoding_method_name = as.presence || attributes.join("_and_").concat("_encoding")
        database_methods = {
          "find_by" => "find_by_#{encoding_method_name}",
          "find_by!" => "find_by_#{encoding_method_name}!",
          "destroy_by" => "destroy_by_#{encoding_method_name}",
          "delete_by" => "delete_by_#{encoding_method_name}"
        }
        sqinky_ensure_method_names_available!(
          instance_methods: [encoding_method_name, "#{encoding_method_name}!"],
          class_methods: database_methods.values + [decodes_as.presence].compact
        )

        # Decoding time grows quadratically with the encoding length, so longer encodings are rejected before decoding.
        # The longest canonical encoding encodes the maximum value for every attribute, padded to +min_length+.
        # Non-canonical encodings may have been issued with a larger +min_length+, up to the Sqids limit.
        max_encoding_length = coder.encode([Sqids.max_value] * attributes.size).length
        max_encoding_length = [max_encoding_length, SQIDS_MAX_MIN_LENGTH].max unless canonical

        # Returns the attribute-value hash for a valid encoding, or nil. An encoding is valid if it is a non-empty
        # String no longer than +max_encoding_length+ that decodes to exactly one value per attribute, no value exceeds
        # +Sqids.max_value+ and, unless +canonical+ is false, is the canonical encoding of those values. This rejects
        # foreign characters, encodings of a different arity, oversized values, and non-canonical aliases of the same
        # values.
        decode = lambda do |encoding|
          values = (encoding.is_a?(String) && encoding.length <= max_encoding_length) ? coder.decode(encoding) : []

          # Covers nil, non-String, empty, too long, and foreign-character input, which all decode to no values.
          if values.size != attributes.size
            nil
          # Sqids decodes long input into values it can't encode, so re-encoding them would raise.
          elsif values.any? { _1 > Sqids.max_value }
            nil
          elsif canonical && coder.encode(values) != encoding
            nil
          else
            attributes.zip(values).to_h
          end
        end

        # Returns the Sqids encoding of the given values. Raises +ArgumentError+ unless every value is an +Integer+, so
        # that, e.g., 1.5 cannot be encoded as the same identifier as 1.
        encode = lambda do |values|
          unless values.all? { _1.is_a?(Integer) }
            raise ArgumentError, <<~MSG
              Encoding supports integers between 0 and #{Sqids.max_value}.

              Received: #{attributes.zip(values).to_h}
            MSG
          end
          coder.encode(values)
        end

        # @!method <encoding_method_name>
        #   Returns the Sqids-encoded identifier for the configured attributes.
        #
        #   @raise [ArgumentError] If any of the attributes is present but not an integer between 0 and +Sqids.max_value+.
        #   @return [String, nil] Encoded identifier or nil if any of the attributes is +blank?+.
        define_method(encoding_method_name) do
          values = attributes.map { public_send(_1) }

          if values.any?(&:blank?)
            nil
          else
            encode.call(values)
          end
        end

        # @!method <encoding_method_name>!
        #   Returns the Sqids-encoded identifier for the configured attributes.
        #
        #   @raise [ArgumentError] If any of the attributes is not an integer between 0 and +Sqids.max_value+, including nil.
        #   @return [String] Encoded identifier.
        define_method("#{encoding_method_name}!") do
          encode.call(attributes.map { public_send(_1) })
        end

        database_methods.each do |base_method, dynamic_method|
          # @!method find_by_<dynamic_method>(encoding)
          #   Find a record by decoding the given encoding into the configured
          #   attributes, then delegating to the corresponding Active Record
          #   query method (e.g. `find_by`, `find_by!`, `destroy_by`, `delete_by`).
          #
          #   An invalid encoding never reaches the database: +find_by+ returns nil, +find_by!+ raises
          #   +ActiveRecord::RecordNotFound+, +destroy_by+ returns [], and +delete_by+ returns 0.
          #
          #   @param encoding [String] Sqids-encoded identifier
          #   @return [Object, nil] model instance or result of the delegated
          #     query method
          #
          # The actual method names are generated dynamically, e.g.:
          # `find_by_id_encoding`, `find_by_id_encoding!`,
          # `destroy_by_id_encoding`, `delete_by_id_encoding`.
          define_singleton_method(dynamic_method) do |encoding|
            args = decode.call(encoding)

            if args
              send(base_method, args)
            else
              case base_method
              when "find_by" then nil
              when "find_by!" then raise ActiveRecord::RecordNotFound.new("Couldn't find #{name} with an invalid encoding", name)
              when "destroy_by" then []
              when "delete_by" then 0
              end
            end
          end
        end

        unless decodes_as.blank?
          decoding_method_name = decodes_as.to_s
          # @!method <decodes_as>(encoding)
          #   Decode the given encoding into a hash mapping each configured
          #   attribute to its decoded numeric value.
          #
          #   @param encoding [String] Sqids-encoded identifier
          #   @return [Hash{Symbol=>Integer}, nil] decoded attribute values, or nil if the encoding is invalid
          define_singleton_method(decoding_method_name) do |encoding|
            decode.call(encoding)
          end
        end
      end

      private

      # Raises +ArgumentError+ if any of the generated methods would replace an existing method, e.g. +as: :id+.
      # Replacing a method that Sqinky generated in a superclass is allowed, so child classes can redeclare an
      # inherited encoding.
      def sqinky_ensure_method_names_available!(instance_methods:, class_methods:)
        conflicts = instance_methods.filter { sqinky_method_name_taken?(self, _1) }.map { "##{_1}" } +
          class_methods.filter { sqinky_method_name_taken?(singleton_class, _1) }.map { ".#{_1}" }

        unless conflicts.empty?
          raise ArgumentError, <<~MSG
            #{name || inspect} already defines #{conflicts.join(", ")}. Choose a different name with `as:` or `decodes_as:`.
          MSG
        end
      end

      # A name is taken if +mod+ already has a method by that name, unless Sqinky generated it in a superclass.
      def sqinky_method_name_taken?(mod, method_name)
        if mod.method_defined?(method_name) || mod.private_method_defined?(method_name)
          method = mod.instance_method(method_name)
          generated_by_sqinky = method.source_location&.first == __FILE__
          inherited = method.owner != mod

          !(generated_by_sqinky && inherited)
        else
          false
        end
      end
    end
  end
end
