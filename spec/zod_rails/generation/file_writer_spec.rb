# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe ZodRails::Generation::FileWriter do
  subject(:writer) { described_class.new(output_dir: output_dir) }
  let(:output_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(output_dir) }

  describe "#write" do
    let(:content) { "export const ArticleSchema = z.object({});" }
    let(:filename) { "article.ts" }

    it "creates the file in the output directory" do
      writer.write(filename: filename, content: content)
      expect(File.exist?(File.join(output_dir, filename))).to be true
    end

    it "writes the content to the file" do
      writer.write(filename: filename, content: content)
      expect(File.read(File.join(output_dir, filename))).to eq(content)
    end

    it "creates nested directories if needed" do
      writer.write(filename: "models/article.ts", content: content)
      expect(File.exist?(File.join(output_dir, "models", "article.ts"))).to be true
    end

    it "overwrites existing files" do
      writer.write(filename: filename, content: "old content")
      writer.write(filename: filename, content: "new content")
      expect(File.read(File.join(output_dir, filename))).to eq("new content")
    end
  end

  describe "sentinel block preservation" do
    let(:filename) { "article.ts" }
    let(:full_path) { File.join(output_dir, filename) }
    let(:generated) do
      <<~TS
        import { z } from "zod";

        export const ArticleSchema = z.object({ id: z.int() });

        export type Article = z.infer<typeof ArticleSchema>;
      TS
    end
    let(:tail_block) do
      <<~BLOCK
        // ZOD_RAILS:CUSTOM:BEGIN
        export const ArticleResponseSchema = z.object({
          article: ArticleSchema,
          meta: z.object({ count: z.int() })
        });
        // ZOD_RAILS:CUSTOM:END
      BLOCK
    end
    let(:imports_block) do
      <<~BLOCK
        // ZOD_RAILS:CUSTOM:IMPORTS:BEGIN
        import { customValidator } from "./shared";
        // ZOD_RAILS:CUSTOM:IMPORTS:END
      BLOCK
    end

    it "writes content unchanged when the file does not exist" do
      writer.write(filename: filename, content: generated)
      expect(File.read(full_path)).to eq(generated)
    end

    it "writes content unchanged when the existing file has no sentinels" do
      File.write(full_path, "stale content")
      writer.write(filename: filename, content: generated)
      expect(File.read(full_path)).to eq(generated)
    end

    it "preserves a tail custom block across regen" do
      File.write(full_path, generated + "\n" + tail_block)

      writer.write(filename: filename, content: generated)

      result = File.read(full_path)
      expect(result).to include("ArticleResponseSchema")
      expect(result).to include("// ZOD_RAILS:CUSTOM:BEGIN")
      expect(result).to include("// ZOD_RAILS:CUSTOM:END")
      expect(result).to include("export const ArticleSchema")
    end

    it "preserves a custom imports block across regen" do
      with_imports = generated.sub(
        /^(import \{ z \} from "zod";\n)/,
        "\\1\n#{imports_block}"
      )
      File.write(full_path, with_imports)

      writer.write(filename: filename, content: generated)

      result = File.read(full_path)
      expect(result).to include("import { customValidator }")
      expect(result).to include("// ZOD_RAILS:CUSTOM:IMPORTS:BEGIN")
      expect(result).to include("// ZOD_RAILS:CUSTOM:IMPORTS:END")
    end

    it "preserves both blocks simultaneously" do
      with_both = generated.sub(
        /^(import \{ z \} from "zod";\n)/,
        "\\1\n#{imports_block}"
      ) + "\n" + tail_block
      File.write(full_path, with_both)

      writer.write(filename: filename, content: generated)

      result = File.read(full_path)
      expect(result).to include("customValidator")
      expect(result).to include("ArticleResponseSchema")
      expect(result.scan("ZOD_RAILS:CUSTOM:IMPORTS:BEGIN").size).to eq(1)
      expect(result.scan("ZOD_RAILS:CUSTOM:BEGIN").size).to eq(1)
    end

    it "is idempotent across repeated regens" do
      File.write(full_path, generated + "\n" + tail_block)

      writer.write(filename: filename, content: generated)
      first_pass = File.read(full_path)

      writer.write(filename: filename, content: generated)
      second_pass = File.read(full_path)

      expect(second_pass).to eq(first_pass)
    end

    it "places the tail block at the end of the file" do
      File.write(full_path, generated + "\n" + tail_block)
      writer.write(filename: filename, content: generated)
      result = File.read(full_path)

      expect(result.strip).to end_with("// ZOD_RAILS:CUSTOM:END")
    end

    it "places the imports block right after the zod import" do
      with_imports = generated.sub(
        /^(import \{ z \} from "zod";\n)/,
        "\\1\n#{imports_block}"
      )
      File.write(full_path, with_imports)
      writer.write(filename: filename, content: generated)

      result = File.read(full_path)
      zod_line = result.index("import { z } from \"zod\";")
      imports_marker = result.index("// ZOD_RAILS:CUSTOM:IMPORTS:BEGIN")
      first_export = result.index("export const")

      expect(zod_line).to be < imports_marker
      expect(imports_marker).to be < first_export
    end
  end

  describe "#output_path_for" do
    it "converts model name to snake_case filename" do
      expect(writer.output_path_for("Article")).to eq("article.ts")
    end

    it "handles namespaced models" do
      expect(writer.output_path_for("Admin::User")).to eq("admin/user.ts")
    end

    it "converts CamelCase to snake_case" do
      expect(writer.output_path_for("BlogPost")).to eq("blog_post.ts")
    end
  end
end
