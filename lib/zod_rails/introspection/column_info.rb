# frozen_string_literal: true

module ZodRails
  module Introspection
    class ColumnInfo
      attr_reader :name, :type, :nullable, :has_default

      def initialize(name:, type:, nullable:, has_default:)
        @name = name
        @type = type
        @nullable = nullable
        @has_default = has_default
        freeze
      end

      def self.from_column(column)
        new(
          name: column.name,
          type: column.type,
          nullable: column.null,
          has_default: !column.default.nil?
        )
      end

      def ==(other)
        other.is_a?(self.class) &&
          name == other.name &&
          type == other.type &&
          nullable == other.nullable &&
          has_default == other.has_default
      end
      alias eql? ==

      def hash
        [self.class, name, type, nullable, has_default].hash
      end
    end
  end
end
