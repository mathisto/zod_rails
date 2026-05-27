# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe ZodRails::Generator do
  let(:model_class) { double(:model_class) }
  let(:output_dir) { Dir.mktmpdir }

  subject(:generator) { described_class.new(output_dir: output_dir) }

  after { FileUtils.rm_rf(output_dir) }

  describe "#generate" do
    before do
      allow(model_class).to receive(:name).and_return("Article")
      allow(model_class).to receive(:columns).and_return([
                                                           double(:col, name: "id", type: :integer, null: false,
                                                                        default: 1),
                                                           double(:col, name: "title", type: :string, null: false,
                                                                        default: nil),
                                                           double(:col, name: "body", type: :text, null: true,
                                                                        default: nil)
                                                         ])
      allow(model_class).to receive(:validators).and_return([])
      allow(model_class).to receive(:defined_enums).and_return({})
    end

    it "generates a .ts file for the model" do
      generator.generate(model_class)
      expect(File.exist?(File.join(output_dir, "article.ts"))).to be true
    end

    it "includes response schema" do
      generator.generate(model_class)
      content = File.read(File.join(output_dir, "article.ts"))
      expect(content).to include("export const ArticleSchema")
    end

    it "includes input schema" do
      generator.generate(model_class)
      content = File.read(File.join(output_dir, "article.ts"))
      expect(content).to include("export const ArticleInputSchema")
    end

    it "includes type exports" do
      generator.generate(model_class)
      content = File.read(File.join(output_dir, "article.ts"))
      expect(content).to include("export type Article =")
      expect(content).to include("export type ArticleInput =")
    end
  end

  describe "#generate_all" do
    let(:user_class) { double(:model_class) }

    before do
      [model_class, user_class].each_with_index do |klass, i|
        name = i.zero? ? "Article" : "User"
        allow(klass).to receive(:name).and_return(name)
        allow(klass).to receive(:columns).and_return([
                                                       double(:col, name: "id", type: :integer, null: false, default: 1)
                                                     ])
        allow(klass).to receive(:validators).and_return([])
        allow(klass).to receive(:defined_enums).and_return({})
      end
    end

    it "generates files for all models" do
      generator.generate_all([model_class, user_class])
      expect(File.exist?(File.join(output_dir, "article.ts"))).to be true
      expect(File.exist?(File.join(output_dir, "user.ts"))).to be true
    end

    it "returns list of generated files" do
      files = generator.generate_all([model_class, user_class])
      expect(files).to contain_exactly("article.ts", "user.ts")
    end
  end

  describe "post_generate_command" do
    before do
      allow(model_class).to receive(:name).and_return("Article")
      allow(model_class).to receive(:columns).and_return([
                                                           double(:col, name: "id", type: :integer, null: false,
                                                                        default: 1)
                                                         ])
      allow(model_class).to receive(:validators).and_return([])
      allow(model_class).to receive(:defined_enums).and_return({})
    end

    after { ZodRails.reset_configuration! }

    it "does nothing when post_generate_command is nil" do
      expect { generator.generate_all([model_class]) }.not_to raise_error
      expect(File.exist?(File.join(output_dir, "article.ts"))).to be true
    end

    it "runs the configured command after a successful generation" do
      Dir.mktmpdir do |dir|
        sentinel = File.join(dir, "ran")
        ZodRails.configure { |c| c.post_generate_command = "touch '#{sentinel}'" }

        generator.generate_all([model_class])

        expect(File.exist?(sentinel)).to be true
      end
    end

    it "raises ZodRails::Error when the post command exits nonzero" do
      ZodRails.configure { |c| c.post_generate_command = "false" }

      expect { generator.generate_all([model_class]) }
        .to raise_error(ZodRails::Error, /post_generate_command/)
    end

    it "still writes the files when the post command fails" do
      ZodRails.configure { |c| c.post_generate_command = "false" }

      expect { generator.generate_all([model_class]) }.to raise_error(ZodRails::Error)
      expect(File.exist?(File.join(output_dir, "article.ts"))).to be true
    end
  end

  describe "#generate_content" do
    before do
      allow(model_class).to receive(:name).and_return("Article")
      allow(model_class).to receive(:columns).and_return([
                                                           double(:col, name: "id", type: :integer, null: false,
                                                                        default: 1)
                                                         ])
      allow(model_class).to receive(:validators).and_return([])
      allow(model_class).to receive(:defined_enums).and_return({})
    end

    it "returns the filename and content without writing to disk" do
      result = generator.generate_content(model_class)
      expect(result).to include(:filename, :content)
      expect(result[:filename]).to eq("article.ts")
      expect(result[:content]).to include("export const ArticleSchema")
      expect(File.exist?(File.join(output_dir, "article.ts"))).to be false
    end

    it "produces the same content that #generate writes" do
      preview = generator.generate_content(model_class)
      generator.generate(model_class)
      written = File.read(File.join(output_dir, preview[:filename]))
      expect(written).to eq(preview[:content])
    end
  end

  describe "#check" do
    before do
      allow(model_class).to receive(:name).and_return("Article")
      allow(model_class).to receive(:columns).and_return([
                                                           double(:col, name: "id", type: :integer, null: false,
                                                                        default: 1)
                                                         ])
      allow(model_class).to receive(:validators).and_return([])
      allow(model_class).to receive(:defined_enums).and_return({})
    end

    it "returns an empty list when generated content matches disk" do
      generator.generate(model_class)
      drift = generator.check([model_class])
      expect(drift).to be_empty
    end

    it "marks the file as :missing when nothing is on disk" do
      drift = generator.check([model_class])
      expect(drift).to contain_exactly(hash_including(filename: "article.ts", status: :missing))
    end

    it "marks the file as :drifted when disk content does not match" do
      generator.generate(model_class)
      File.write(File.join(output_dir, "article.ts"), "// hand-edited, not a real schema")
      drift = generator.check([model_class])
      expect(drift).to contain_exactly(hash_including(filename: "article.ts", status: :drifted))
    end

    it "does not write anything to disk" do
      mtime_before = nil
      generator.generate(model_class)
      mtime_before = File.mtime(File.join(output_dir, "article.ts"))
      sleep 0.01
      generator.check([model_class])
      expect(File.mtime(File.join(output_dir, "article.ts"))).to eq(mtime_before)
    end
  end
end
