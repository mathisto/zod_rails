# frozen_string_literal: true

module ZodRails
  module Mapping
    class EnumMapper
      def self.call(values, nullable: false, input_schema: false, has_default: false, validation_chain: "")
        names = values.is_a?(Hash) ? values.keys : values
        quoted = names.map { |name| JSON.generate(name.to_s) }
        enum = "z.enum([#{quoted.join(", ")}])"
        base = validation_chain.empty? ? enum : "z.string()#{validation_chain}.pipe(#{enum})"

        suffix = determine_suffix(nullable: nullable, input_schema: input_schema, has_default: has_default)
        "#{base}#{suffix}"
      end

      def self.determine_suffix(nullable:, input_schema:, has_default:)
        return "" unless nullable || has_default

        if input_schema
          nullable ? ".nullish()" : ".optional()"
        else
          nullable ? ".nullable()" : ""
        end
      end

      private_class_method :determine_suffix
    end
  end
end
