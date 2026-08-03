# frozen_string_literal: true

module ZodRails
  module ModelResolver
    def self.resolve(names)
      resolved = []
      missing = []
      invalid = []

      names.each do |name|
        model = resolve_constant(name)
        if active_record_model?(model)
          resolved << model
        else
          invalid << name
        end
      rescue NameError => e
        raise unless missing_constant?(e, name)

        missing << name
      end

      { resolved: resolved, missing: missing, invalid: invalid }
    end

    def self.resolve_constant(name)
      name.split("::").reject(&:empty?).reduce(Object) do |namespace, constant_name|
        namespace.const_get(constant_name, false)
      end
    end

    def self.active_record_model?(constant)
      constant.is_a?(Class) && constant < ActiveRecord::Base && !constant.abstract_class?
    end

    def self.missing_constant?(error, requested_name)
      requested_name.split("::").include?(error.name.to_s)
    end

    private_class_method :resolve_constant, :active_record_model?, :missing_constant?
  end
end
