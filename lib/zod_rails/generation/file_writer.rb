# frozen_string_literal: true

require "fileutils"

module ZodRails
  module Generation
    class FileWriter
      IMPORTS_BLOCK_RE = %r{^// ZOD_RAILS:CUSTOM:IMPORTS:BEGIN\n.*?^// ZOD_RAILS:CUSTOM:IMPORTS:END\n}m
      TAIL_BLOCK_RE = %r{^// ZOD_RAILS:CUSTOM:BEGIN\n.*?^// ZOD_RAILS:CUSTOM:END\n}m
      ZOD_IMPORT_RE = /^(import \{ z \} from "zod";\n)/

      attr_reader :output_dir

      def initialize(output_dir:)
        @output_dir = output_dir
      end

      def write(filename:, content:)
        full_path = File.join(output_dir, filename)
        FileUtils.mkdir_p(File.dirname(full_path))

        final = File.exist?(full_path) ? splice_custom_blocks(content, File.read(full_path)) : content
        File.write(full_path, final)
      end

      def preview(filename:, content:)
        content
      end

      def output_path_for(model_name)
        parts = model_name.split("::")
        filename = underscore(parts.pop)
        path_parts = parts.map { |p| underscore(p) }
        path_parts << "#{filename}.ts"
        path_parts.join("/")
      end

      private

      def splice_custom_blocks(new_content, existing)
        imports = existing[IMPORTS_BLOCK_RE]
        tail = existing[TAIL_BLOCK_RE]

        result = new_content
        result = insert_imports_block(result, imports) if imports
        result = append_tail_block(result, tail) if tail
        result
      end

      def insert_imports_block(content, imports_block)
        content.sub(ZOD_IMPORT_RE, "\\1\n#{imports_block}")
      end

      def append_tail_block(content, tail_block)
        "#{content.rstrip}\n\n#{tail_block}"
      end

      def underscore(str)
        str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .downcase
      end
    end
  end
end
