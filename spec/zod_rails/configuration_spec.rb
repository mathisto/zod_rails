# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets output_dir to app/javascript/schemas" do
      expect(config.output_dir).to eq("app/javascript/schemas")
    end

    it "sets schema_suffix to Schema" do
      expect(config.schema_suffix).to eq("Schema")
    end

    it "sets input_schema_suffix to InputSchema" do
      expect(config.input_schema_suffix).to eq("InputSchema")
    end

    it "sets generate_input_schemas to true" do
      expect(config.generate_input_schemas).to be true
    end

    it "sets excluded_columns to id, created_at, updated_at" do
      expect(config.excluded_columns).to eq(%w[id created_at updated_at])
    end

    it "sets models to empty array" do
      expect(config.models).to eq([])
    end
  end

  describe "configuration" do
    it "allows setting output_dir" do
      config.output_dir = "frontend/src/schemas"
      expect(config.output_dir).to eq("frontend/src/schemas")
    end

    it "allows setting excluded_columns" do
      config.excluded_columns = %w[id]
      expect(config.excluded_columns).to eq(%w[id])
    end

    it "allows setting models" do
      config.models = %w[User Article]
      expect(config.models).to eq(%w[User Article])
    end
  end
end

RSpec.describe ZodRails do
  describe ".configure" do
    after { ZodRails.reset_configuration! }

    it "yields the configuration" do
      ZodRails.configure do |config|
        config.output_dir = "custom/path"
      end
      expect(ZodRails.configuration.output_dir).to eq("custom/path")
    end
  end

  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(ZodRails.configuration).to be_a(ZodRails::Configuration)
    end

    it "memoizes the configuration" do
      expect(ZodRails.configuration).to be(ZodRails.configuration)
    end
  end
end
