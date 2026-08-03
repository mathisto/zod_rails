# frozen_string_literal: true

module ZodRails
  module Generation
    class SchemaBuilder
      STRING_TYPES = %i[string text].freeze
      NULLABILITY_SUFFIX_RE = /(\.(?:nullable|nullish|optional)\(\))\z/
      TYPESCRIPT_IDENTIFIER_RE = /\A[$A-Z_a-z][$\w]*\z/

      attr_reader :inspector, :excluded_columns, :schema_suffix, :input_schema_suffix

      def initialize(inspector, excluded_columns: [], schema_suffix: "Schema", input_schema_suffix: "InputSchema")
        @inspector = inspector
        @excluded_columns = excluded_columns.map(&:to_s)
        @schema_suffix = schema_suffix
        @input_schema_suffix = input_schema_suffix
      end

      def build(input_schema: false)
        columns = input_schema ? filtered_columns : inspector.columns
        fields = columns.map do |column|
          field_definition(column, input_schema: input_schema)
        end

        "z.object({\n  #{fields.join(",\n  ")}\n})"
      end

      def schema_name(input_schema: false)
        suffix = input_schema ? input_schema_suffix : schema_suffix
        name = "#{inspector.model_name.gsub("::", "")}#{suffix}"
        return name if name.match?(TYPESCRIPT_IDENTIFIER_RE)

        raise ZodRails::Error, "Invalid TypeScript schema name: #{name.inspect}"
      end

      def type_name(input_schema: false)
        name = inspector.model_name.gsub("::", "")
        input_schema ? "#{name}Input" : name
      end

      private

      def field_definition(column, input_schema:)
        type_str = build_type_string(column, input_schema: input_schema)
        key = column.name.match?(TYPESCRIPT_IDENTIFIER_RE) ? column.name : JSON.generate(column.name)
        "#{key}: #{type_str}"
      end

      def build_type_string(column, input_schema:)
        validations = inspector.validations_for(column.name)

        if enum_column?(column.name)
          build_enum_type(column, validations, input_schema: input_schema)
        elsif (inclusion = string_array_inclusion(column, validations))
          build_inclusion_enum_type(column, inclusion, validations, input_schema: input_schema)
        else
          build_regular_type(column, validations, input_schema: input_schema)
        end
      end

      def string_array_inclusion(column, validations)
        return nil if column.array || !STRING_TYPES.include?(column.type)

        validations.find { |validation| string_array_inclusion?(validation) }
      end

      def string_array_inclusion?(validation)
        return false unless validation.kind == :inclusion && !validation.conditional?

        values = validation.options[:in]
        values.is_a?(Array) && !values.empty? && values.all? { |x| x.is_a?(String) }
      end

      def build_inclusion_enum_type(column, inclusion, validations, input_schema:)
        remaining = validations.reject { |validation| validation.equal?(inclusion) }
        Mapping::EnumMapper.call(
          inclusion.options[:in],
          validation_chain: Mapping::ValidationMapper.call_all(remaining, base_type: :string, array: column.array),
          nullable: nullable?(column, validations),
          input_schema: input_schema,
          has_default: column.has_default,
          array: column.array
        )
      end

      def build_enum_type(column, validations, input_schema:)
        values = inspector.enums[column.name]
        Mapping::EnumMapper.call(
          values,
          validation_chain: Mapping::ValidationMapper.call_all(validations, base_type: :string, array: column.array),
          nullable: nullable?(column, validations),
          input_schema: input_schema,
          has_default: column.has_default,
          array: column.array,
          element_validation_chain: array_element_validation_chain(column, validations)
        )
      end

      def build_regular_type(column, validations, input_schema:)
        base_type = Mapping::TypeMapper.call(
          column.type,
          nullable: nullable?(column, validations),
          input_schema: input_schema,
          has_default: column.has_default,
          array: column.array,
          element_validation_chain: array_element_validation_chain(column, validations)
        )

        validation_chain = Mapping::ValidationMapper.call_all(validations, base_type: column.type, array: column.array)
        insert_validation_chain(base_type, validation_chain)
      end

      def insert_validation_chain(base_type, validation_chain)
        return base_type if validation_chain.empty?

        if (match = base_type.match(NULLABILITY_SUFFIX_RE))
          base_type.sub(NULLABILITY_SUFFIX_RE, "#{validation_chain}#{match[0]}")
        else
          "#{base_type}#{validation_chain}"
        end
      end

      def enum_column?(column_name)
        inspector.enums.key?(column_name)
      end

      def nullable?(column, validations)
        column.nullable && validations.none? do |validation|
          validation.kind == :presence && !validation.conditional? &&
            !validation.options[:allow_nil] && !validation.options[:allow_blank]
        end
      end

      def array_element_validation_chain(column, validations)
        return "" unless column.array

        element_validations = validations.select { |validation| validation.kind == :inclusion }
        Mapping::ValidationMapper.call_all(element_validations, base_type: column.type)
      end

      def filtered_columns
        inspector.columns.reject { |col| excluded_columns.include?(col.name) }
      end
    end
  end
end
