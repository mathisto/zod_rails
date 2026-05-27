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

      file_writer.write(filename: filename, content: content)
      filename
    end

    def generate_all(model_classes)
      files = model_classes.map { |klass| generate(klass) }
      run_post_generate_command
      files
    end

    private

    def run_post_generate_command
      cmd = ZodRails.configuration.post_generate_command
      return if cmd.nil? || cmd.to_s.strip.empty?

      ok = system(cmd)
      return if ok

      exit_status = Process.last_status&.exitstatus
      raise ZodRails::Error,
            "post_generate_command failed (exit #{exit_status}): #{cmd}"
    end
  end
end
