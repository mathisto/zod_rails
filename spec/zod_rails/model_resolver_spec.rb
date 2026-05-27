# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::ModelResolver do
  describe ".resolve" do
    it "returns resolved constants for valid names" do
      result = described_class.resolve(%w[String Integer])
      expect(result[:resolved]).to eq([String, Integer])
      expect(result[:missing]).to be_empty
    end

    it "collects names that do not resolve" do
      result = described_class.resolve(%w[String NoSuchModel])
      expect(result[:resolved]).to eq([String])
      expect(result[:missing]).to eq(["NoSuchModel"])
    end

    it "treats every name independently" do
      result = described_class.resolve(%w[NoSuchA String NoSuchB])
      expect(result[:resolved]).to eq([String])
      expect(result[:missing]).to eq(%w[NoSuchA NoSuchB])
    end

    it "handles an empty input" do
      result = described_class.resolve([])
      expect(result[:resolved]).to be_empty
      expect(result[:missing]).to be_empty
    end

    it "resolves namespaced constants" do
      stub_const("FooNs::BarModel", Class.new)
      result = described_class.resolve(%w[FooNs::BarModel])
      expect(result[:resolved]).to eq([FooNs::BarModel])
      expect(result[:missing]).to be_empty
    end
  end
end
