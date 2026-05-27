# frozen_string_literal: true

module ZodRails
  module GoldenSupport
    Column = Struct.new(:name, :type, :null, :default, keyword_init: true)

    Validator = Struct.new(:kind, :attributes, :options, keyword_init: true)

    ModelDouble = Struct.new(:name, :columns, :defined_enums, :validators, keyword_init: true)

    module_function

    def build(spec)
      columns = spec.fetch(:columns, []).map do |c|
        Column.new(
          name: c.fetch(:name),
          type: c.fetch(:type),
          null: c.fetch(:null, true),
          default: c[:default]
        )
      end

      validators = spec.fetch(:validators, []).map do |v|
        Validator.new(
          kind: v.fetch(:kind),
          attributes: v.fetch(:attributes),
          options: v.fetch(:options, {})
        )
      end

      ModelDouble.new(
        name: spec.fetch(:name),
        columns: columns,
        defined_enums: spec.fetch(:enums, {}),
        validators: validators
      )
    end

    def load_spec(path)
      eval(File.read(path), TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
    end
  end
end
