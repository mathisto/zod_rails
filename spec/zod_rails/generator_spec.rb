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
end
