# frozen_string_literal: true

module ZodRails
  module Mapping
    class EnumMapper
      def self.call(values, nullable: false, input_schema: false, array: false, **options)
        has_default = options.fetch(:has_default, false)
        validation_chain = options.fetch(:validation_chain, "")
        element_validation_chain = options.fetch(:element_validation_chain, "")
        names = values.is_a?(Hash) ? values.keys : values
        quoted = names.map { |name| JSON.generate(name.to_s) }
        enum = "z.enum([#{quoted.join(", ")}])"
        base = if array
                 array_schema(enum, element_validation_chain, validation_chain)
               elsif validation_chain.empty?
                 enum
               else
                 "z.string()#{validation_chain}.pipe(#{enum})"
               end

        suffix = determine_suffix(nullable: nullable, input_schema: input_schema, has_default: has_default)
        "#{base}#{suffix}"
      end

      def self.array_schema(enum, element_validation_chain, array_validation_chain)
        element = element_validation_chain.empty? ? enum : "z.string()#{element_validation_chain}.pipe(#{enum})"
        "z.array(#{element})#{array_validation_chain}"
      end

      def self.determine_suffix(nullable:, input_schema:, has_default:)
        return "" unless nullable || has_default

        if input_schema
          nullable ? ".nullish()" : ".optional()"
        else
          nullable ? ".nullable()" : ""
        end
      end

      private_class_method :array_schema, :determine_suffix
    end
  end
end
