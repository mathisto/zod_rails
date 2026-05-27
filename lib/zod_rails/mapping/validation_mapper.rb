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
        return "" if validation.conditional?

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
        STRING_ZOD_TYPES.include?(base_type) ? ".min(1)" : ""
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
          ".#{method}(#{value})" if method
        end.join
      end

      def self.map_format(validation, base_type)
        return "" unless STRING_ZOD_TYPES.include?(base_type)

        regex = validation.options[:with]
        return "" unless regex

        js_pattern = convert_ruby_regex_to_js(regex)
        ".regex(/#{js_pattern}/#{regex_flags_for(regex)})"
      end

      def self.map_inclusion(validation, base_type)
        values = validation.options[:in] || validation.options[:within]
        return "" unless values.is_a?(Array)

        build_array_inclusion_suffix(values, base_type) || ""
      end

      def self.build_array_inclusion_suffix(values, base_type)
        return nil if values.empty?

        if values.all? { |v| v.is_a?(String) } && STRING_ZOD_TYPES.include?(base_type)
          quoted = values.map { |v| %("#{escape_quotes(v)}") }.join(", ")
          ".pipe(z.enum([#{quoted}]))"
        elsif values.all? { |v| v.is_a?(Numeric) } && NUMERIC_ZOD_TYPES.include?(base_type)
          if values.length == 1
            ".pipe(z.literal(#{values.first}))"
          else
            literals = values.map { |v| "z.literal(#{v})" }.join(", ")
            ".pipe(z.union([#{literals}]))"
          end
        end
      end

      def self.escape_quotes(str)
        str.to_s.gsub('"', '\\"')
      end

      def self.convert_ruby_regex_to_js(regex)
        pattern = regex.source
        pattern = pattern.gsub("\\A", "^")
        pattern.gsub(/\\z/i, "$")
      end

      def self.regex_flags_for(regex)
        flags = +""
        flags << "i" if (regex.options & Regexp::IGNORECASE).positive?
        flags
      end

      def self.collect_constraints(validation, base_type, constraints)
        return if validation.conditional?

        case validation.kind
        when :presence then handle_presence_constraint(base_type, constraints)
        when :length then handle_length_constraint(validation, base_type, constraints)
        when :numericality then handle_numericality_constraint(validation, base_type, constraints)
        when :format then handle_format_constraint(validation, base_type, constraints)
        when :inclusion then handle_inclusion_constraint(validation, base_type, constraints)
        end
      end

      def self.handle_presence_constraint(base_type, constraints)
        constraints[:min] = [constraints[:min] || 0, 1].max if STRING_ZOD_TYPES.include?(base_type)
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

        js_pattern = convert_ruby_regex_to_js(regex)
        constraints[:others] << ".regex(/#{js_pattern}/#{regex_flags_for(regex)})"
      end

      def self.build_chain(constraints)
        parts = []

        if constraints[:length]
          parts << ".length(#{constraints[:length]})"
        else
          parts << ".min(#{constraints[:min]})" if constraints[:min]&.positive?
          parts << ".max(#{constraints[:max].to_i})" if constraints[:max] && constraints[:max] != Float::INFINITY
        end

        parts.concat(constraints[:others])
        parts.join
      end

      def self.handle_inclusion_constraint(validation, base_type, constraints)
        values = validation.options[:in] || validation.options[:within]
        return unless values

        case values
        when Range
          if values.begin.is_a?(Numeric) && values.end.is_a?(Numeric)
            constraints[:min] = [constraints[:min] || 0, values.begin].max
            constraints[:max] = [constraints[:max] || Float::INFINITY, values.end].min
          end
        when Array
          suffix = build_array_inclusion_suffix(values, base_type)
          constraints[:others] << suffix if suffix
        end
      end

      def self.handle_numericality_constraint(validation, base_type, constraints)
        return unless NUMERIC_ZOD_TYPES.include?(base_type)

        validation.options.each do |key, value|
          if key == :in
            apply_numeric_range(value, constraints)
          elsif (method = NUMERICALITY_MAP[key])
            constraints[:others] << ".#{method}(#{value})"
          end
        end
      end

      def self.apply_numeric_range(range, constraints)
        return unless range.is_a?(Range) && range.begin.is_a?(Numeric) && range.end.is_a?(Numeric)

        constraints[:min] = [constraints[:min] || 0, range.begin].max
        constraints[:max] = [constraints[:max] || Float::INFINITY, range.end].min
      end

      private_class_method :map_presence, :map_length, :map_numericality, :map_format, :map_inclusion,
                           :build_array_inclusion_suffix, :escape_quotes,
                           :convert_ruby_regex_to_js, :regex_flags_for, :collect_constraints, :build_chain,
                           :handle_presence_constraint, :handle_length_constraint, :handle_format_constraint,
                           :handle_inclusion_constraint, :handle_numericality_constraint, :apply_numeric_range
    end
  end
end
