# frozen_string_literal: true

module ZodRails
  class Configuration
    attr_accessor :output_dir, :schema_suffix, :input_schema_suffix,
                  :generate_input_schemas, :excluded_columns, :models

    def initialize
      @output_dir = "app/javascript/schemas"
      @schema_suffix = "Schema"
      @input_schema_suffix = "InputSchema"
      @generate_input_schemas = true
      @excluded_columns = %w[id created_at updated_at]
      @models = []
    end
  end
end
