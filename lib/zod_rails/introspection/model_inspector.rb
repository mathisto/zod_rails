# frozen_string_literal: true

module ZodRails
  module Introspection
    class ModelInspector
      attr_reader :model_class

      def initialize(model_class)
        @model_class = model_class
      end

      def columns
        @columns ||= model_class.columns.map { |col| ColumnInfo.from_column(col) }
      end

      def validations_for(attribute)
        model_class.validators.each_with_object([]) do |validator, result|
          next unless validator.attributes.include?(attribute)

          result << ValidationInfo.from_validator(validator, attribute)
        end
      end

      def enums
        @enums ||= model_class.defined_enums
      end

      def model_name
        model_class.name
      end
    end
  end
end
