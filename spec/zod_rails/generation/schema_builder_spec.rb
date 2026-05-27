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

    context "with a nullable column and a validation chain" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("name", :string, nullable: true)
                                                         ])
        allow(inspector).to receive(:validations_for).with("name").and_return([
                                                                                validation_info(:presence),
                                                                                validation_info(:length, maximum: 50)
                                                                              ])
      end

      it "inserts the chain before the nullable suffix" do
        schema = builder.build
        expect(schema).to include("name: z.string().min(1).max(50).nullable()")
      end
    end

    context "with a string column and array inclusion (0.2 base-type swap)" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("decision", :string, nullable: false)
                                                         ])
        allow(inspector).to receive(:validations_for).with("decision").and_return([
                                                                                    validation_info(:presence),
                                                                                    validation_info(:inclusion,
                                                                                                    in: %w[a b c])
                                                                                  ])
      end

      it "emits z.enum as the base type, dropping .min(1)/.pipe noise" do
        schema = builder.build
        expect(schema).to include('decision: z.enum(["a", "b", "c"])')
        expect(schema).not_to include(".pipe")
        expect(schema).not_to include(".min(1)")
      end
    end

    context "with a nullable string column and array inclusion" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("priority", :string, nullable: true)
                                                         ])
        allow(inspector).to receive(:validations_for).with("priority").and_return([
                                                                                    validation_info(:inclusion,
                                                                                                    in: %w[low high])
                                                                                  ])
      end

      it "keeps the .nullable() suffix after the swap" do
        schema = builder.build
        expect(schema).to include('priority: z.enum(["low", "high"]).nullable()')
      end
    end

    context "with a numeric column and array inclusion (falls back to .pipe)" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("level", :integer, nullable: false)
                                                         ])
        allow(inspector).to receive(:validations_for).with("level").and_return([
                                                                                 validation_info(:inclusion,
                                                                                                 in: [1, 2, 3])
                                                                               ])
      end

      it "still uses .pipe(z.union(...)) since z.enum is string-only" do
        schema = builder.build
        expect(schema).to include("level: z.int().pipe(z.union([z.literal(1), z.literal(2), z.literal(3)]))")
      end
    end

    context "with text column and presence validation" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("body", :text, nullable: false)
                                                         ])
        allow(inspector).to receive(:validations_for).with("body").and_return([
                                                                                validation_info(:presence)
                                                                              ])
      end

      it "produces z.string().min(1)" do
        schema = builder.build
        expect(schema).to include("body: z.string().min(1)")
      end
    end

    context "with decimal column and numericality validation" do
      before do
        allow(inspector).to receive(:columns).and_return([
                                                           column_info("price", :decimal, nullable: true)
                                                         ])
        allow(inspector).to receive(:validations_for).with("price").and_return(
          [validation_info(:numericality, greater_than_or_equal_to: 0)]
        )
      end

      it "produces z.string().nullable() with no numeric methods" do
        schema = builder.build
        expect(schema).to include("price: z.string().nullable()")
        expect(schema).not_to include(".gte(")
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

  describe "#schema_name for namespaced models" do
    it "collapses :: into a single-identifier CamelCase name" do
      allow(inspector).to receive(:model_name).and_return("Admin::User")
      expect(builder.schema_name).to eq("AdminUserSchema")
      expect(builder.schema_name(input_schema: true)).to eq("AdminUserInputSchema")
    end

    it "handles multi-level namespaces" do
      allow(inspector).to receive(:model_name).and_return("Admin::Dashboard::Widget")
      expect(builder.schema_name).to eq("AdminDashboardWidgetSchema")
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
