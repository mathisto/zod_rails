# frozen_string_literal: true

module ZodRails
  module Mapping
    class TypeMapper
      TYPE_MAP = {
        string: "z.string()",
        text: "z.string()",
        integer: "z.int()",
        bigint: "z.string()",
        float: "z.number()",
        decimal: "z.string()",
        boolean: "z.boolean()",
        date: "z.iso.date()",
        datetime: "z.iso.datetime({ offset: true })",
        timestamp: "z.iso.datetime({ offset: true })",
        time: "z.string()",
        json: "z.json()",
        jsonb: "z.json()",
        uuid: "z.uuid()",
        binary: "z.string()"
      }.freeze

      def self.call(type, nullable: false, input_schema: false, has_default: false)
        base = TYPE_MAP.fetch(type.to_sym) do
          ZodRails.logger.warn("ZodRails: Unknown type '#{type}', falling back to z.unknown()")
          "z.unknown()"
        end

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
