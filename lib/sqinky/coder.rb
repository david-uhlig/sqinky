# frozen_string_literal: true

require "sqids"

module Sqinky
  # A drop-in replacement for +Sqids+ that encodes several times faster and returns the same encodings.
  #
  # Most of the time +Sqids#encode+ spends is in checking the encoding against every word of the blocklist. This
  # coder encodes without the blocklist first, then checks the encoding by looking up its substrings in sets of
  # blocked words. Only if the encoding is blocked, which is rare, does it fall back to +Sqids#encode+, which
  # re-generates the encoding.
  #
  # @api private
  class Coder
    # @param options [Hash] Options for +Sqids.new+: +alphabet+, +min_length+, and +blocklist+.
    def initialize(**options)
      @sqids = Sqids.new(**options)
      @unblocked_sqids = Sqids.new(**options, blocklist: [])
      @blocklist = Blocklist.new(
        options[:blocklist] || Sqids::DEFAULT_BLOCKLIST,
        alphabet: options[:alphabet] || Sqids::DEFAULT_ALPHABET
      )
    end

    # @param numbers [Array<Integer>]
    # @return [String] The same encoding as +Sqids#encode+.
    def encode(numbers)
      encoding = @unblocked_sqids.encode(numbers)
      @blocklist.blocked?(encoding) ? @sqids.encode(numbers) : encoding
    end

    # @param encoding [String]
    # @return [Array<Integer>] The same values as +Sqids#decode+.
    def decode(encoding)
      @sqids.decode(encoding)
    end

    # Tells whether Sqids blocks an encoding, with the same result as +Sqids#blocked_id?+ (sqids 0.2):
    # * An encoding of up to 3 characters is blocked if it equals a blocked word.
    # * A longer encoding is blocked if it starts or ends with a longer blocked word that contains a digit, or if it
    #   contains a longer blocked word without digits.
    # Blocked words of up to 3 characters never block a longer encoding. The comparison ignores case.
    #
    # @api private
    class Blocklist
      # @param words [Enumerable<String>] Blocked words. Like Sqids, ignores words shorter than 3 characters and words
      #   with characters outside the alphabet.
      # @param alphabet [String]
      def initialize(words, alphabet:)
        characters = alphabet.downcase.chars
        @words = words.map(&:downcase).select { _1.length >= 3 && (_1.chars - characters).empty? }.to_set
        affixes, infixes = @words.select { _1.length > 3 }.partition { _1.match?(/\d/) }
        @affixes = affixes.to_set
        @infixes = infixes.to_set
        @affix_lengths = @affixes.map(&:length).uniq.sort
        @infix_lengths = @infixes.map(&:length).uniq.sort
      end

      # @param encoding [String]
      # @return [Boolean]
      def blocked?(encoding)
        encoding = encoding.downcase
        return @words.include?(encoding) if encoding.length <= 3

        length = encoding.length
        @affix_lengths.any? do |n|
          n <= length && (@affixes.include?(encoding[0, n]) || @affixes.include?(encoding[-n, n]))
        end || @infix_lengths.any? do |n|
          n <= length && (0..length - n).any? { |i| @infixes.include?(encoding[i, n]) }
        end
      end
    end
  end
end
