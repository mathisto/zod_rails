# frozen_string_literal: true

module ZodRails
  module Generation
    class SchemaBuilder
      attr_reader :inspector, :excluded_columns

      def initialize(inspector, excluded_columns: [])
        @inspector = inspector
        @excluded_columns = excluded_columns.map(&:to_s)
      end

      def build(input_schema: false)
        columns = input_schema ? filtered_columns : inspector.columns
        fields = columns.map do |column|
          field_definition(column, input_schema: input_schema)
        end

        "z.object({\n  #{fields.join(",\n  ")}\n})"
      end

      def schema_name(input_schema: false)
        suffix = input_schema ? "InputSchema" : "Schema"
        "#{inspector.model_name.gsub('::', '')}#{suffix}"
      end

      private

      def field_definition(column, input_schema:)
        type_str = build_type_string(column, input_schema: input_schema)
        "#{column.name}: #{type_str}"
      end

      def build_type_string(column, input_schema:)
        if enum_column?(column.name)
          build_enum_type(column, input_schema: input_schema)
        else
          build_regular_type(column, input_schema: input_schema)
        end
      end

      def build_enum_type(column, input_schema:)
        values = inspector.enums[column.name]
        Mapping::EnumMapper.call(
          values,
          nullable: column.nullable,
          input_schema: input_schema,
          has_default: column.has_default
        )
      end

      def build_regular_type(column, input_schema:)
        validations = inspector.validations_for(column.name)
        base_type = Mapping::TypeMapper.call(
          column.type,
          nullable: column.nullable,
          input_schema: input_schema,
          has_default: column.has_default
        )

        validation_chain = Mapping::ValidationMapper.call_all(validations, base_type: column.type)
        insert_validation_chain(base_type, validation_chain)
      end

      def insert_validation_chain(base_type, validation_chain)
        return base_type if validation_chain.empty?

        if base_type.include?(".nullable()") || base_type.include?(".nullish()") || base_type.include?(".optional()")
          suffix_match = base_type.match(/(\.(nullable|nullish|optional)\(\))$/)
          if suffix_match
            base_type.sub(suffix_match[0], "#{validation_chain}#{suffix_match[0]}")
          else
            "#{base_type}#{validation_chain}"
          end
        else
          "#{base_type}#{validation_chain}"
        end
      end

      def enum_column?(column_name)
        inspector.enums.key?(column_name)
      end

      def filtered_columns
        inspector.columns.reject { |col| excluded_columns.include?(col.name) }
      end
    end
  end
end
