# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Mapping::ValidationMapper do
  subject(:mapper) { described_class }

  describe ".call" do
    context "with presence validation" do
      let(:validation) do
        ZodRails::Introspection::ValidationInfo.new(
          kind: :presence,
          attribute: :name,
          options: {},
          conditional: false
        )
      end

      it "returns .min(1) for strings" do
        expect(mapper.call(validation, base_type: :string)).to eq(".min(1)")
      end

      it "returns empty string for non-strings (handled by nullability)" do
        expect(mapper.call(validation, base_type: :integer)).to eq("")
      end
    end

    context "with length validation" do
      it "maps minimum to .min(n)" do
        validation = build_validation(:length, minimum: 5)
        expect(mapper.call(validation, base_type: :string)).to eq(".min(5)")
      end

      it "maps maximum to .max(n)" do
        validation = build_validation(:length, maximum: 255)
        expect(mapper.call(validation, base_type: :string)).to eq(".max(255)")
      end

      it "maps is to .length(n)" do
        validation = build_validation(:length, is: 10)
        expect(mapper.call(validation, base_type: :string)).to eq(".length(10)")
      end

      it "combines minimum and maximum" do
        validation = build_validation(:length, minimum: 5, maximum: 255)
        expect(mapper.call(validation, base_type: :string)).to eq(".min(5).max(255)")
      end
    end

    context "with numericality validation" do
      it "maps greater_than to .gt(n)" do
        validation = build_validation(:numericality, greater_than: 0)
        expect(mapper.call(validation, base_type: :integer)).to eq(".gt(0)")
      end

      it "maps greater_than_or_equal_to to .gte(n)" do
        validation = build_validation(:numericality, greater_than_or_equal_to: 1)
        expect(mapper.call(validation, base_type: :integer)).to eq(".gte(1)")
      end

      it "maps less_than to .lt(n)" do
        validation = build_validation(:numericality, less_than: 100)
        expect(mapper.call(validation, base_type: :integer)).to eq(".lt(100)")
      end

      it "maps less_than_or_equal_to to .lte(n)" do
        validation = build_validation(:numericality, less_than_or_equal_to: 99)
        expect(mapper.call(validation, base_type: :integer)).to eq(".lte(99)")
      end

      it "combines multiple constraints" do
        validation = build_validation(:numericality, greater_than: 0, less_than_or_equal_to: 100)
        expect(mapper.call(validation, base_type: :integer)).to eq(".gt(0).lte(100)")
      end
    end

    context "with format validation" do
      it "maps regex to .regex()" do
        validation = build_validation(:format, with: /\A[a-z]+\z/)
        expect(mapper.call(validation, base_type: :string)).to eq(".regex(/^[a-z]+$/)")
      end

      it "converts Ruby anchors to JS anchors" do
        validation = build_validation(:format, with: /\A\d+\z/)
        expect(mapper.call(validation, base_type: :string)).to eq('.regex(/^\\d+$/)')
      end
    end

    context "with conditional validation" do
      let(:validation) do
        ZodRails::Introspection::ValidationInfo.new(
          kind: :presence,
          attribute: :name,
          options: {},
          conditional: true
        )
      end

      it "returns empty string (skipped)" do
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end
    end

    context "with unsupported validation" do
      it "returns empty string for uniqueness" do
        validation = build_validation(:uniqueness)
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end

      it "returns empty string for confirmation" do
        validation = build_validation(:confirmation)
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end
    end
  end

  describe ".call_all" do
    it "combines multiple validations into a single chain" do
      validations = [
        build_validation(:presence),
        build_validation(:length, minimum: 2, maximum: 100)
      ]
      expect(mapper.call_all(validations, base_type: :string)).to eq(".min(2).max(100)")
    end

    it "deduplicates min constraints (presence + length minimum)" do
      validations = [
        build_validation(:presence),
        build_validation(:length, minimum: 5)
      ]
      expect(mapper.call_all(validations, base_type: :string)).to eq(".min(5)")
    end
  end

  def build_validation(kind, **options)
    ZodRails::Introspection::ValidationInfo.new(
      kind: kind,
      attribute: :test,
      options: options,
      conditional: false
    )
  end
end
