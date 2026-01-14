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

      def self.call(validation, base_type:)
        return "" if validation.conditional?

        case validation.kind
        when :presence then map_presence(validation, base_type)
        when :length then map_length(validation)
        when :numericality then map_numericality(validation)
        when :format then map_format(validation)
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
        base_type == :string ? ".min(1)" : ""
      end

      def self.map_length(validation)
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

      def self.map_numericality(validation)
        validation.options.filter_map do |key, value|
          method = NUMERICALITY_MAP[key]
          ".#{method}(#{value})" if method
        end.join
      end

      def self.map_format(validation)
        regex = validation.options[:with]
        return "" unless regex

        js_pattern = convert_ruby_regex_to_js(regex)
        ".regex(/#{js_pattern}/)"
      end

      def self.convert_ruby_regex_to_js(regex)
        pattern = regex.source
        pattern = pattern.gsub("\\A", "^")
        pattern.gsub(/\\z/i, "$")
      end

      def self.collect_constraints(validation, base_type, constraints)
        return if validation.conditional?

        case validation.kind
        when :presence
          constraints[:min] = [constraints[:min] || 0, 1].max if base_type == :string
        when :length
          opts = validation.options
          constraints[:length] = opts[:is] if opts[:is]
          constraints[:min] = [constraints[:min] || 0, opts[:minimum]].max if opts[:minimum]
          constraints[:max] = [constraints[:max] || Float::INFINITY, opts[:maximum]].min if opts[:maximum]
        when :numericality
          validation.options.each do |key, value|
            method = NUMERICALITY_MAP[key]
            constraints[:others] << ".#{method}(#{value})" if method
          end
        when :format
          regex = validation.options[:with]
          if regex
            js_pattern = convert_ruby_regex_to_js(regex)
            constraints[:others] << ".regex(/#{js_pattern}/)"
          end
        end
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

      private_class_method :map_presence, :map_length, :map_numericality, :map_format,
                           :convert_ruby_regex_to_js, :collect_constraints, :build_chain
    end
  end
end
