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
      config = ZodRails.configuration
      builder = Generation::SchemaBuilder.new(
        inspector,
        excluded_columns: config.excluded_columns,
        schema_suffix: config.schema_suffix,
        input_schema_suffix: config.input_schema_suffix
      )

      response_schema = {
        name: builder.schema_name,
        type_name: builder.type_name,
        body: builder.build
      }
      content = emit_content(builder, response_schema, generate_input: config.generate_input_schemas)
      { filename: file_writer.output_path_for(inspector.model_name), content: content }
    end

    def generate_all(model_classes)
      targets = model_classes.map { |klass| generate_content(klass) }
      duplicate = targets.group_by { |target| target[:filename] }.find { |_filename, matches| matches.size > 1 }
      raise ZodRails::Error, "Output filename collision: #{duplicate.first}" if duplicate

      files = targets.map do |target|
        file_writer.write(filename: target[:filename], content: target[:content])
        target[:filename]
      end
      run_post_generate_command
      files
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

    private

    def emit_content(builder, response, generate_input:)
      unless generate_input
        return emitter.emit(
          schema_name: response[:name], schema_body: response[:body], type_name: response[:type_name]
        )
      end

      input = {
        name: builder.schema_name(input_schema: true),
        type_name: builder.type_name(input_schema: true),
        body: builder.build(input_schema: true)
      }
      if input[:name] == response[:name]
        raise ZodRails::Error, "Response and input schemas have the same export name: #{input[:name]}"
      end

      emitter.emit_combined(response: response, input: input)
    end

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
