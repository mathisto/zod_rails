# frozen_string_literal: true

require "fileutils"

module ZodRails
  module Generation
    class FileWriter
      attr_reader :output_dir

      def initialize(output_dir:)
        @output_dir = output_dir
      end

      def write(filename:, content:)
        full_path = File.join(output_dir, filename)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, content)
      end

      def output_path_for(model_name)
        parts = model_name.split("::")
        filename = underscore(parts.pop)
        path_parts = parts.map { |p| underscore(p) }
        path_parts << "#{filename}.ts"
        path_parts.join("/")
      end

      private

      def underscore(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
      end
    end
  end
end
