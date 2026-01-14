# frozen_string_literal: true

module ZodRails
  class Generator
    attr_reader :output_dir, :file_writer, :emitter

    def initialize(output_dir:)
      @output_dir = output_dir
      @file_writer = Generation::FileWriter.new(output_dir: output_dir)
      @emitter = Generation::TypescriptEmitter.new
    end

    def generate(model_class)
      inspector = Introspection::ModelInspector.new(model_class)
      builder = Generation::SchemaBuilder.new(inspector)

      response_schema = {
        name: builder.schema_name,
        body: builder.build
      }

      input_schema = {
        name: builder.schema_name(input_schema: true),
        body: builder.build(input_schema: true)
      }

      content = emitter.emit_combined(response: response_schema, input: input_schema)
      filename = file_writer.output_path_for(inspector.model_name)

      file_writer.write(filename: filename, content: content)
      filename
    end

    def generate_all(model_classes)
      model_classes.map { |klass| generate(klass) }
    end
  end
end
