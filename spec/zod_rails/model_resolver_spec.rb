# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::ModelResolver do
  describe ".resolve" do
    it "returns resolved constants for valid names" do
      stub_const("ArticleModel", Class.new(ActiveRecord::Base))
      result = described_class.resolve(%w[ArticleModel])
      expect(result[:resolved]).to eq([ArticleModel])
      expect(result[:missing]).to be_empty
      expect(result[:invalid]).to be_empty
    end

    it "collects names that do not resolve" do
      stub_const("ArticleModel", Class.new(ActiveRecord::Base))
      result = described_class.resolve(%w[ArticleModel NoSuchModel])
      expect(result[:resolved]).to eq([ArticleModel])
      expect(result[:missing]).to eq(["NoSuchModel"])
    end

    it "treats every name independently" do
      stub_const("ArticleModel", Class.new(ActiveRecord::Base))
      result = described_class.resolve(%w[NoSuchA ArticleModel NoSuchB])
      expect(result[:resolved]).to eq([ArticleModel])
      expect(result[:missing]).to eq(%w[NoSuchA NoSuchB])
    end

    it "handles an empty input" do
      result = described_class.resolve([])
      expect(result[:resolved]).to be_empty
      expect(result[:missing]).to be_empty
      expect(result[:invalid]).to be_empty
    end

    it "resolves namespaced constants" do
      stub_const("FooNs::BarModel", Class.new(ActiveRecord::Base))
      result = described_class.resolve(%w[FooNs::BarModel])
      expect(result[:resolved]).to eq([FooNs::BarModel])
      expect(result[:missing]).to be_empty
    end

    it "collects constants that are not ActiveRecord models" do
      result = described_class.resolve(%w[String])
      expect(result[:resolved]).to be_empty
      expect(result[:invalid]).to eq(["String"])
    end

    it "collects abstract ActiveRecord models" do
      model = Class.new(ActiveRecord::Base)
      model.abstract_class = true
      stub_const("AbstractModel", model)

      expect(described_class.resolve(%w[AbstractModel])[:invalid]).to eq(["AbstractModel"])
    end

    it "does not hide NameError raised while loading a model" do
      namespace = Module.new do
        def self.const_missing(_name)
          MissingDependency
        end
      end
      stub_const("BrokenNamespace", namespace)

      expect { described_class.resolve(%w[BrokenNamespace::Model]) }
        .to raise_error(NameError, /MissingDependency/)
    end
  end
end
