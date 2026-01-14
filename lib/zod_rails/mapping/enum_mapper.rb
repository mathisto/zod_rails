# frozen_string_literal: true

module ZodRails
  module Mapping
    class EnumMapper
      def self.call(values, nullable: false, input_schema: false, has_default: false)
        keys = values.keys.map { |k| "\"#{escape_quotes(k)}\"" }
        base = "z.enum([#{keys.join(", ")}])"

        suffix = determine_suffix(nullable: nullable, input_schema: input_schema, has_default: has_default)
        "#{base}#{suffix}"
      end

      def self.escape_quotes(str)
        str.to_s.gsub('"', '\\"')
      end

      def self.determine_suffix(nullable:, input_schema:, has_default:)
        return "" unless nullable || has_default

        if input_schema
          nullable ? ".nullish()" : ".optional()"
        else
          nullable ? ".nullable()" : ""
        end
      end

      private_class_method :escape_quotes, :determine_suffix
    end
  end
end
