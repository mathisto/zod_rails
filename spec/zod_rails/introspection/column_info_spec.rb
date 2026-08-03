# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Introspection::ColumnInfo do
  describe ".from_column" do
    let(:column) do
      double(:column, name: "email", type: :string, null: false, default: nil)
    end

    subject(:column_info) { described_class.from_column(column) }

    it "extracts the column name" do
      expect(column_info.name).to eq("email")
    end

    it "extracts the column type" do
      expect(column_info.type).to eq(:string)
    end

    it "extracts nullable status" do
      expect(column_info.nullable).to be false
    end

    it "detects presence of default value" do
      expect(column_info.has_default).to be false
    end

    it "defaults to a scalar for adapters without array metadata" do
      expect(column_info.array).to be false
    end

    context "with a nullable column with default" do
      let(:column) do
        double(:column, name: "status", type: :string, null: true, default: "pending")
      end

      it "reflects nullable as true" do
        expect(column_info.nullable).to be true
      end

      it "reflects has_default as true" do
        expect(column_info.has_default).to be true
      end
    end

    context "with a database expression default" do
      let(:column) do
        double(:column, name: "created_at", type: :datetime, null: false, default: nil,
                        default_function: "CURRENT_TIMESTAMP")
      end

      it "detects the default" do
        expect(column_info.has_default).to be true
      end
    end

    context "with a PostgreSQL array column" do
      let(:column) do
        double(:column, name: "tags", type: :string, null: false, default: [], array?: true)
      end

      it "captures the array metadata" do
        expect(column_info.array).to be true
      end
    end
  end

  describe "value object behavior" do
    subject(:column_info) do
      described_class.new(name: "id", type: :integer, nullable: false, has_default: true)
    end

    it "is frozen" do
      expect(column_info).to be_frozen
    end

    it "supports equality based on attributes" do
      other = described_class.new(name: "id", type: :integer, nullable: false, has_default: true)
      expect(column_info).to eq(other)
    end

    it "supports hash-based comparison" do
      other = described_class.new(name: "id", type: :integer, nullable: false, has_default: true)
      expect(column_info.hash).to eq(other.hash)
    end

    it "includes array metadata in equality" do
      array_column = described_class.new(
        name: "id", type: :integer, nullable: false, has_default: true, array: true
      )
      expect(column_info).not_to eq(array_column)
    end
  end
end
