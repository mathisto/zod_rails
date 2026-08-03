# frozen_string_literal: true

module ZodRails
  module Mapping
    class RegexpMapper
      UNSUPPORTED_TOKENS = %w[\\K \\R (?> (?~].freeze

      def self.call(regex)
        if unsupported?(regex)
          ZodRails.logger.warn("ZodRails: Skipping regexp with Ruby-only semantics: #{regex.inspect}")
          return nil
        end

        pattern = regex.source
                       .gsub("\\A", "^")
                       .gsub("\\z", "(?![\\s\\S])")
                       .gsub("\\Z", "(?=(?:\\n)?(?![\\s\\S]))")
        flags = flags_for(regex)
        args = [JSON.generate(pattern), (JSON.generate(flags) unless flags.empty?)].compact
        "new RegExp(#{args.join(", ")})"
      end

      def self.flags_for(regex)
        flags = +""
        flags << "i" if regex.options.anybits?(Regexp::IGNORECASE)
        flags << "s" if regex.options.anybits?(Regexp::MULTILINE)
        flags
      end

      def self.unsupported?(regex)
        regex.options.anybits?(Regexp::EXTENDED) || UNSUPPORTED_TOKENS.any? { |token| regex.source.include?(token) }
      end
      private_class_method :flags_for, :unsupported?
    end
  end
end
