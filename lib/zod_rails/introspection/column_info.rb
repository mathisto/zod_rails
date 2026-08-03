# frozen_string_literal: true

module ZodRails
  module Introspection
    class ColumnInfo
      attr_reader :name, :type, :nullable, :has_default, :array

      def initialize(name:, type:, nullable:, has_default:, array: false)
        @name = name
        @type = type
        @nullable = nullable
        @has_default = has_default
        @array = array
        freeze
      end

      def self.from_column(column)
        new(
          name: column.name,
          type: column.type,
          nullable: column.null,
          has_default: !column.default.nil? ||
            (column.respond_to?(:default_function) && !column.default_function.nil?),
          array: column.respond_to?(:array?) && column.array?
        )
      end

      def ==(other)
        other.is_a?(self.class) &&
          name == other.name &&
          type == other.type &&
          nullable == other.nullable &&
          has_default == other.has_default &&
          array == other.array
      end
      alias eql? ==

      def hash
        [self.class, name, type, nullable, has_default, array].hash
      end
    end
  end
end
