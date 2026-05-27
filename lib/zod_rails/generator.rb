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
      result = generate_content(model_class)
      file_writer.write(filename: result[:filename], content: result[:content])
      result[:filename]
    end

    def generate_content(model_class)
      inspector = Introspection::ModelInspector.new(model_class)
      excluded = ZodRails.configuration.excluded_columns
      builder = Generation::SchemaBuilder.new(inspector, excluded_columns: excluded)

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

      { filename: filename, content: content }
    end

    def generate_all(model_classes)
      model_classes.map { |klass| generate(klass) }
    end

    def check(model_classes)
      model_classes.each_with_object([]) do |klass, drift|
        target = generate_content(klass)
        full_path = File.join(output_dir, target[:filename])
        expected = file_writer.preview(filename: target[:filename], content: target[:content])

        if !File.exist?(full_path)
          drift << { filename: target[:filename], status: :missing }
        elsif File.read(full_path) != expected
          drift << { filename: target[:filename], status: :drifted }
        end
      end
    end
  end
end
