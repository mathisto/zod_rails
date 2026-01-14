# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Introspection::ValidationInfo do
  describe ".from_validator" do
    context "with presence validator" do
      let(:validator) { double(:validator, kind: :presence, options: {}) }

      subject(:validation_info) { described_class.from_validator(validator, :name) }

      it "extracts the kind" do
        expect(validation_info.kind).to eq(:presence)
      end

      it "extracts the attribute name" do
        expect(validation_info.attribute).to eq(:name)
      end

      it "extracts empty options" do
        expect(validation_info.options).to eq({})
      end
    end

    context "with length validator" do
      let(:validator) { double(:validator, kind: :length, options: { minimum: 2, maximum: 100 }) }

      subject(:validation_info) { described_class.from_validator(validator, :title) }

      it "extracts length options" do
        expect(validation_info.options).to eq({ minimum: 2, maximum: 100 })
      end
    end

    context "with numericality validator" do
      let(:validator) do
        double(:validator, kind: :numericality, options: { greater_than: 0, less_than_or_equal_to: 100 })
      end

      subject(:validation_info) { described_class.from_validator(validator, :quantity) }

      it "extracts numericality options" do
        expect(validation_info.options).to eq({ greater_than: 0, less_than_or_equal_to: 100 })
      end
    end

    context "with inclusion validator" do
      let(:validator) { double(:validator, kind: :inclusion, options: { in: %w[draft published archived] }) }

      subject(:validation_info) { described_class.from_validator(validator, :status) }

      it "extracts inclusion options" do
        expect(validation_info.options).to eq({ in: %w[draft published archived] })
      end
    end

    context "with format validator" do
      let(:regex) { /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i }
      let(:validator) { double(:validator, kind: :format, options: { with: regex }) }

      subject(:validation_info) { described_class.from_validator(validator, :email) }

      it "extracts format regex" do
        expect(validation_info.options[:with]).to eq(regex)
      end
    end

    context "with conditional validator" do
      let(:validator) { double(:validator, kind: :presence, options: { if: :published? }) }

      subject(:validation_info) { described_class.from_validator(validator, :body) }

      it "marks as conditional" do
        expect(validation_info).to be_conditional
      end
    end

    context "with on: option (context-specific)" do
      let(:validator) { double(:validator, kind: :presence, options: { on: :create }) }

      subject(:validation_info) { described_class.from_validator(validator, :password) }

      it "marks as conditional" do
        expect(validation_info).to be_conditional
      end
    end
  end

  describe "value object behavior" do
    subject(:validation_info) do
      described_class.new(kind: :presence, attribute: :name, options: {}, conditional: false)
    end

    it "is frozen" do
      expect(validation_info).to be_frozen
    end

    it "supports equality based on attributes" do
      other = described_class.new(kind: :presence, attribute: :name, options: {}, conditional: false)
      expect(validation_info).to eq(other)
    end
  end
end
