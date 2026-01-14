# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Generation::SchemaBuilder do
  let(:inspector) { double(:inspector) }
  subject(:builder) { described_class.new(inspector) }

  describe "#build" do
    before do
      allow(inspector).to receive(:model_name).and_return("Article")
      allow(inspector).to receive(:enums).and_return({})
    end

    context "with simple columns" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("id", :integer, nullable: false,
                                                                                       has_default: true),
                                                           column_info("title", :string, nullable: false),
                                                           column_info("body", :text, nullable: true),
                                                           column_info("published", :boolean, nullable: false,
                                                                                              has_default: true)
                                                         ])
        allow(inspector).to receive(:validations_for).and_return([])
      end

      it "builds a z.object with all columns" do
        schema = builder.build
        expect(schema).to include("z.object({")
        expect(schema).to include("id: z.int()")
        expect(schema).to include("title: z.string()")
        expect(schema).to include("body: z.string().nullable()")
        expect(schema).to include("published: z.boolean()")
      end
    end

    context "with validations" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("email", :string, nullable: false)
                                                         ])
        allow(inspector).to receive(:validations_for).with("email").and_return([
                                                                                 validation_info(:presence),
                                                                                 validation_info(:length, minimum: 5,
                                                                                                          maximum: 255)
                                                                               ])
      end

      it "applies validation chains to the type" do
        schema = builder.build
        expect(schema).to include("email: z.string().min(5).max(255)")
      end
    end

    context "with enums" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("status", :integer, nullable: false,
                                                                                           has_default: true)
                                                         ])
        allow(inspector).to receive(:enums).and_return({
                                                         "status" => { "draft" => 0, "published" => 1, "archived" => 2 }
                                                       })
        allow(inspector).to receive(:validations_for).and_return([])
      end

      it "uses z.enum for enum columns" do
        schema = builder.build
        expect(schema).to include('status: z.enum(["draft", "published", "archived"])')
      end
    end

    context "with input_schema: true" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("id", :integer, nullable: false,
                                                                                       has_default: true),
                                                           column_info("title", :string, nullable: false),
                                                           column_info("notes", :text, nullable: true,
                                                                                       has_default: true)
                                                         ])
        allow(inspector).to receive(:validations_for).and_return([])
      end

      it "makes columns with defaults optional" do
        schema = builder.build(input_schema: true)
        expect(schema).to include("id: z.int().optional()")
      end

      it "uses nullish for nullable columns with defaults" do
        schema = builder.build(input_schema: true)
        expect(schema).to include("notes: z.string().nullish()")
      end
    end
  end

  describe "#schema_name" do
    before do
      allow(inspector).to receive(:model_name).and_return("Article")
    end

    it "generates response schema name" do
      expect(builder.schema_name).to eq("ArticleSchema")
    end

    it "generates input schema name" do
      expect(builder.schema_name(input_schema: true)).to eq("ArticleInputSchema")
    end
  end

  def column_info(name, type, nullable: false, has_default: false)
    ZodRails::Introspection::ColumnInfo.new(
      name: name, type: type, nullable: nullable, has_default: has_default
    )
  end

  def validation_info(kind, **options)
    ZodRails::Introspection::ValidationInfo.new(
      kind: kind, attribute: :test, options: options, conditional: false
    )
  end
end
