# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Introspection::ModelInspector do
  let(:model_class) { class_double("Article") }

  subject(:inspector) { described_class.new(model_class) }

  describe "#columns" do
    let(:id_column) { double(:column, name: "id", type: :integer, null: false, default: nil) }
    let(:title_column) { double(:column, name: "title", type: :string, null: false, default: nil) }
    let(:body_column) { double(:column, name: "body", type: :text, null: true, default: nil) }

    before do
      allow(model_class).to receive(:columns).and_return([id_column, title_column, body_column])
    end

    it "returns an array of ColumnInfo objects" do
      expect(inspector.columns).to all(be_a(ZodRails::Introspection::ColumnInfo))
    end

    it "includes all columns from the model" do
      expect(inspector.columns.map(&:name)).to eq(%w[id title body])
    end

    it "preserves column types" do
      types = inspector.columns.map(&:type)
      expect(types).to eq(%i[integer string text])
    end

    it "preserves nullable status" do
      nullable_flags = inspector.columns.map(&:nullable)
      expect(nullable_flags).to eq([false, false, true])
    end
  end

  describe "#validations_for" do
    let(:presence_validator) do
      double(:validator, kind: :presence, options: {}, attributes: [:title])
    end

    let(:length_validator) do
      double(:validator, kind: :length, options: { minimum: 5, maximum: 255 }, attributes: [:title])
    end

    let(:body_presence_validator) do
      double(:validator, kind: :presence, options: { if: :published? }, attributes: [:body])
    end

    before do
      allow(model_class).to receive(:validators).and_return([
                                                              presence_validator,
                                                              length_validator,
                                                              body_presence_validator
                                                            ])
    end

    it "returns ValidationInfo objects for the given attribute" do
      validations = inspector.validations_for(:title)
      expect(validations).to all(be_a(ZodRails::Introspection::ValidationInfo))
    end

    it "filters validations by attribute" do
      title_validations = inspector.validations_for(:title)
      expect(title_validations.map(&:kind)).to eq(%i[presence length])
    end

    it "returns empty array for attributes without validations" do
      expect(inspector.validations_for(:id)).to eq([])
    end

    it "includes conditional validations" do
      body_validations = inspector.validations_for(:body)
      expect(body_validations.first).to be_conditional
    end
  end

  describe "#enums" do
    before do
      allow(model_class).to receive(:defined_enums).and_return({
                                                                 "status" => { "draft" => 0, "published" => 1,
                                                                               "archived" => 2 }
                                                               })
    end

    it "returns enum definitions keyed by attribute name" do
      expect(inspector.enums).to have_key("status")
    end

    it "returns enum values as keys" do
      expect(inspector.enums["status"].keys).to eq(%w[draft published archived])
    end
  end

  describe "#model_name" do
    before do
      allow(model_class).to receive(:name).and_return("Article")
    end

    it "returns the model class name" do
      expect(inspector.model_name).to eq("Article")
    end
  end
end
