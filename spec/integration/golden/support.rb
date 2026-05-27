# frozen_string_literal: true

module ZodRails
  module GoldenSupport
    Column = Struct.new(:name, :type, :null, :default, keyword_init: true)

    Validator = Struct.new(:kind, :attributes, :options, keyword_init: true)

    ModelDouble = Struct.new(:name, :columns, :defined_enums, :validators, keyword_init: true)

    module_function

    def build(spec)
      ModelDouble.new(
        name: spec.fetch(:name),
        columns: spec.fetch(:columns, []).map { |c| build_column(c) },
        defined_enums: spec.fetch(:enums, {}),
        validators: spec.fetch(:validators, []).map { |v| build_validator(v) }
      )
    end

    def build_column(spec)
      Column.new(
        name: spec.fetch(:name),
        type: spec.fetch(:type),
        null: spec.fetch(:null, true),
        default: spec[:default]
      )
    end

    def build_validator(spec)
      Validator.new(
        kind: spec.fetch(:kind),
        attributes: spec.fetch(:attributes),
        options: spec.fetch(:options, {})
      )
    end

    def load_spec(path)
      eval(File.read(path), TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
    end
  end
end
