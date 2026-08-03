# frozen_string_literal: true

module ZodRails
  module Mapping
    class ValidationMapper
      NUMERICALITY_MAP = {
        greater_than: "gt",
        greater_than_or_equal_to: "gte",
        less_than: "lt",
        less_than_or_equal_to: "lte"
      }.freeze

      NUMERIC_ZOD_TYPES = %i[integer float].freeze
      STRING_ZOD_TYPES = %i[string text].freeze

      def self.call(validation, base_type:)
        return "" if validation.conditional? || no_op_presence?(validation)

        case validation.kind
        when :presence then map_presence(validation, base_type)
        when :length then map_length(validation, base_type)
        when :numericality then map_numericality(validation, base_type)
        when :format then map_format(validation, base_type)
        when :inclusion then map_inclusion(validation, base_type)
        else ""
        end
      end

      def self.call_all(validations, base_type:)
        constraints = { min: nil, max: nil, length: nil, others: [] }

        validations.each do |v|
          collect_constraints(v, base_type, constraints)
        end

        build_chain(constraints)
      end

      def self.map_presence(_validation, base_type)
        STRING_ZOD_TYPES.include?(base_type) ? ".min(1)#{presence_suffix}" : ""
      end

      def self.map_length(validation, base_type)
        return "" unless STRING_ZOD_TYPES.include?(base_type)

        parts = []
        opts = validation.options

        if opts[:is]
          parts << ".length(#{opts[:is]})"
        else
          parts << ".min(#{opts[:minimum]})" if opts[:minimum]
          parts << ".max(#{opts[:maximum]})" if opts[:maximum]
        end

        parts.join
      end

      def self.map_numericality(validation, base_type)
        return "" unless NUMERIC_ZOD_TYPES.include?(base_type)

        validation.options.filter_map do |key, value|
          method = NUMERICALITY_MAP[key]
          ".#{method}(#{value})" if method && static_number?(value)
        end.join
      end

      def self.map_format(validation, base_type)
        return "" unless STRING_ZOD_TYPES.include?(base_type)

        regex = validation.options[:with]
        return "" unless regex

        RegexpMapper.call(regex)&.then { |expression| ".regex(#{expression})" } || ""
      end

      def self.map_inclusion(validation, base_type)
        values = validation.options[:in] || validation.options[:within]
        return "" unless values.is_a?(Array)

        build_array_inclusion_suffix(values, base_type) || ""
      end

      def self.build_array_inclusion_suffix(values, base_type)
        return nil if values.empty?

        if string_array_for_string_type?(values, base_type)
          build_string_enum_suffix(values)
        elsif numeric_array_for_numeric_type?(values, base_type)
          build_numeric_literal_suffix(values)
        end
      end

      def self.string_array_for_string_type?(values, base_type)
        STRING_ZOD_TYPES.include?(base_type) && values.all? { |v| v.is_a?(String) }
      end

      def self.numeric_array_for_numeric_type?(values, base_type)
        NUMERIC_ZOD_TYPES.include?(base_type) && values.all? { |v| v.is_a?(Numeric) }
      end

      def self.build_string_enum_suffix(values)
        quoted = values.map { |value| JSON.generate(value) }.join(", ")
        ".pipe(z.enum([#{quoted}]))"
      end

      def self.build_numeric_literal_suffix(values)
        return nil unless values.all? { |value| static_number?(value) }
        return ".pipe(z.literal(#{values.first}))" if values.length == 1

        literals = values.map { |v| "z.literal(#{v})" }.join(", ")
        ".pipe(z.union([#{literals}]))"
      end

      def self.collect_constraints(validation, base_type, constraints)
        return if validation.conditional? || no_op_presence?(validation)

        case validation.kind
        when :presence then handle_presence_constraint(base_type, constraints)
        when :length then handle_length_constraint(validation, base_type, constraints)
        when :numericality then handle_numericality_constraint(validation, base_type, constraints)
        when :format then handle_format_constraint(validation, base_type, constraints)
        when :inclusion then handle_inclusion_constraint(validation, base_type, constraints)
        end
      end

      def self.handle_presence_constraint(base_type, constraints)
        return unless STRING_ZOD_TYPES.include?(base_type)

        constraints[:min] = [constraints[:min] || 0, 1].max
        constraints[:others] << presence_suffix
      end

      def self.handle_length_constraint(validation, base_type, constraints)
        return unless STRING_ZOD_TYPES.include?(base_type)

        opts = validation.options
        constraints[:length] = opts[:is] if opts[:is]
        constraints[:min] = [constraints[:min] || 0, opts[:minimum]].max if opts[:minimum]
        constraints[:max] = [constraints[:max] || Float::INFINITY, opts[:maximum]].min if opts[:maximum]
      end

      def self.handle_format_constraint(validation, base_type, constraints)
        return unless STRING_ZOD_TYPES.include?(base_type)

        regex = validation.options[:with]
        return unless regex

        expression = RegexpMapper.call(regex)
        constraints[:others] << ".regex(#{expression})" if expression
      end

      def self.build_chain(constraints)
        parts = []

        if constraints[:length]
          parts << ".length(#{constraints[:length]})"
        else
          parts << ".min(#{constraints[:min]})" unless constraints[:min].nil?
          parts << ".max(#{constraints[:max].to_i})" if constraints[:max] && constraints[:max] != Float::INFINITY
        end

        parts.concat(constraints[:others])
        parts.join
      end

      def self.handle_inclusion_constraint(validation, base_type, constraints)
        values = validation.options[:in] || validation.options[:within]

        case values
        when Range then apply_range_inclusion(values, base_type, constraints)
        when Array then apply_array_inclusion(values, base_type, constraints)
        end
      end

      def self.apply_range_inclusion(range, base_type, constraints)
        return unless NUMERIC_ZOD_TYPES.include?(base_type)

        apply_numeric_range(range, constraints)
      end

      def self.apply_array_inclusion(values, base_type, constraints)
        suffix = build_array_inclusion_suffix(values, base_type)
        constraints[:others] << suffix if suffix
      end

      def self.handle_numericality_constraint(validation, base_type, constraints)
        return unless NUMERIC_ZOD_TYPES.include?(base_type)

        validation.options.each do |key, value|
          if key == :in
            apply_numeric_range(value, constraints)
          elsif (method = NUMERICALITY_MAP[key]) && static_number?(value)
            constraints[:others] << ".#{method}(#{value})"
          end
        end
      end

      def self.apply_numeric_range(range, constraints)
        return unless range.is_a?(Range)

        constraints[:others] << ".gte(#{range.begin})" if static_number?(range.begin)
        return unless static_number?(range.end)

        constraints[:others] << ".#{range.exclude_end? ? "lt" : "lte"}(#{range.end})"
      end

      def self.presence_suffix
        '.refine((value) => value.trim().length > 0, { message: "can\'t be blank" })'
      end

      def self.static_number?(value)
        value.is_a?(Numeric) && (!value.respond_to?(:finite?) || value.finite?)
      end

      def self.no_op_presence?(validation)
        validation.kind == :presence && validation.options[:allow_blank]
      end

      private_class_method :map_presence, :map_length, :map_numericality, :map_format, :map_inclusion,
                           :build_array_inclusion_suffix, :string_array_for_string_type?,
                           :numeric_array_for_numeric_type?, :build_string_enum_suffix,
                           :build_numeric_literal_suffix, :collect_constraints, :build_chain,
                           :handle_presence_constraint, :handle_length_constraint, :handle_format_constraint,
                           :handle_inclusion_constraint, :apply_range_inclusion, :apply_array_inclusion,
                           :handle_numericality_constraint, :apply_numeric_range, :presence_suffix, :static_number?,
                           :no_op_presence?
    end
  end
end
