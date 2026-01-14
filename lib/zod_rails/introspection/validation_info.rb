# frozen_string_literal: true

module ZodRails
  module Introspection
    class ValidationInfo
      CONDITIONAL_KEYS = %i[if unless on].freeze

      attr_reader :kind, :attribute, :options

      def initialize(kind:, attribute:, options:, conditional:)
        @kind = kind
        @attribute = attribute
        @options = options
        @conditional = conditional
        freeze
      end

      def self.from_validator(validator, attribute)
        opts = validator.options.dup
        conditional = CONDITIONAL_KEYS.any? { |key| opts.key?(key) }

        new(
          kind: validator.kind,
          attribute: attribute,
          options: opts.except(*CONDITIONAL_KEYS),
          conditional: conditional
        )
      end

      def conditional?
        @conditional
      end

      def ==(other)
        other.is_a?(self.class) &&
          kind == other.kind &&
          attribute == other.attribute &&
          options == other.options &&
          conditional? == other.conditional?
      end
      alias eql? ==

      def hash
        [self.class, kind, attribute, options, @conditional].hash
      end
    end
  end
end
