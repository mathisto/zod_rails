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
