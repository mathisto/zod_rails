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

      it "returns .min(1) for text columns" do
        expect(mapper.call(validation, base_type: :text)).to eq(".min(1)")
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

      it "works for text columns" do
        validation = build_validation(:length, minimum: 10)
        expect(mapper.call(validation, base_type: :text)).to eq(".min(10)")
      end

      it "returns empty string for non-string types" do
        validation = build_validation(:length, minimum: 5)
        expect(mapper.call(validation, base_type: :integer)).to eq("")
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

      it "returns empty string for decimal columns (maps to z.string)" do
        validation = build_validation(:numericality, greater_than_or_equal_to: 0)
        expect(mapper.call(validation, base_type: :decimal)).to eq("")
      end

      it "returns empty string for string columns" do
        validation = build_validation(:numericality, greater_than: 0)
        expect(mapper.call(validation, base_type: :string)).to eq("")
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

      it "returns empty string for non-string types" do
        validation = build_validation(:format, with: /\d+/)
        expect(mapper.call(validation, base_type: :integer)).to eq("")
      end

      it "preserves the case-insensitive /i flag" do
        validation = build_validation(:format, with: /\A[a-z]+\z/i)
        expect(mapper.call(validation, base_type: :string)).to eq(".regex(/^[a-z]+$/i)")
      end

      it "omits flags when none are set" do
        validation = build_validation(:format, with: /\A[a-z]+\z/)
        expect(mapper.call(validation, base_type: :string)).to eq(".regex(/^[a-z]+$/)")
      end
    end

    context "with array inclusion validation" do
      it "maps a string array on a string column to .pipe(z.enum(...))" do
        validation = build_validation(:inclusion, in: %w[pending approved not_applicable])
        expect(mapper.call(validation, base_type: :string)).to eq(
          '.pipe(z.enum(["pending", "approved", "not_applicable"]))'
        )
      end

      it "maps a string array on a text column to .pipe(z.enum(...))" do
        validation = build_validation(:inclusion, in: %w[low high])
        expect(mapper.call(validation, base_type: :text)).to eq('.pipe(z.enum(["low", "high"]))')
      end

      it "maps a multi-element numeric array on an integer column to .pipe(z.union(...))" do
        validation = build_validation(:inclusion, in: [1, 5, 10])
        expect(mapper.call(validation, base_type: :integer)).to eq(
          ".pipe(z.union([z.literal(1), z.literal(5), z.literal(10)]))"
        )
      end

      it "maps a single-element numeric array to .pipe(z.literal(...))" do
        validation = build_validation(:inclusion, in: [42])
        expect(mapper.call(validation, base_type: :integer)).to eq(".pipe(z.literal(42))")
      end

      it "maps a numeric array on a float column" do
        validation = build_validation(:inclusion, in: [0.0, 1.5])
        expect(mapper.call(validation, base_type: :float)).to eq(
          ".pipe(z.union([z.literal(0.0), z.literal(1.5)]))"
        )
      end

      it "skips a string array on an integer column (type mismatch)" do
        validation = build_validation(:inclusion, in: %w[a b])
        expect(mapper.call(validation, base_type: :integer)).to eq("")
      end

      it "skips a numeric array on a string column (type mismatch)" do
        validation = build_validation(:inclusion, in: [1, 2])
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end

      it "skips a mixed-type array" do
        validation = build_validation(:inclusion, in: ["a", 1])
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end

      it "skips an empty array" do
        validation = build_validation(:inclusion, in: [])
        expect(mapper.call(validation, base_type: :string)).to eq("")
      end

      it "escapes embedded double quotes in string values" do
        validation = build_validation(:inclusion, in: ['has "quotes"', "normal"])
        expect(mapper.call(validation, base_type: :string)).to eq(
          '.pipe(z.enum(["has \\"quotes\\"", "normal"]))'
        )
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

    it "skips numericality for decimal columns" do
      validations = [
        build_validation(:numericality, greater_than_or_equal_to: 0, less_than: 1000)
      ]
      expect(mapper.call_all(validations, base_type: :decimal)).to eq("")
    end

    it "applies numericality for float columns" do
      validations = [
        build_validation(:numericality, greater_than: 0, less_than_or_equal_to: 100)
      ]
      expect(mapper.call_all(validations, base_type: :float)).to eq(".gt(0).lte(100)")
    end

    it "applies presence and length for text columns" do
      validations = [
        build_validation(:presence),
        build_validation(:length, minimum: 10, maximum: 5000)
      ]
      expect(mapper.call_all(validations, base_type: :text)).to eq(".min(10).max(5000)")
    end

    it "skips length for non-string types" do
      validations = [
        build_validation(:length, minimum: 5, maximum: 100)
      ]
      expect(mapper.call_all(validations, base_type: :integer)).to eq("")
    end

    it "skips format for non-string types" do
      validations = [
        build_validation(:format, with: /\d+/)
      ]
      expect(mapper.call_all(validations, base_type: :integer)).to eq("")
    end

    it "combines presence and array inclusion into .min(1).pipe(z.enum(...))" do
      validations = [
        build_validation(:presence),
        build_validation(:inclusion, in: %w[pending approved])
      ]
      expect(mapper.call_all(validations, base_type: :string)).to eq(
        '.min(1).pipe(z.enum(["pending", "approved"]))'
      )
    end

    it "still maps Range inclusion to .min/.max (unchanged Range branch)" do
      validations = [
        build_validation(:inclusion, in: 1..5)
      ]
      expect(mapper.call_all(validations, base_type: :integer)).to eq(".min(1).max(5)")
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
