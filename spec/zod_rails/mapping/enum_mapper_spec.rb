# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Mapping::EnumMapper do
  subject(:mapper) { described_class }

  describe ".call" do
    it "maps string enum values to z.enum()" do
      values = { "draft" => 0, "published" => 1, "archived" => 2 }
      expect(mapper.call(values)).to eq('z.enum(["draft", "published", "archived"])')
    end

    it "preserves order of enum values" do
      values = { "pending" => 0, "processing" => 1, "completed" => 2, "failed" => 3 }
      expect(mapper.call(values)).to eq('z.enum(["pending", "processing", "completed", "failed"])')
    end

    it "handles single value enum" do
      values = { "active" => 0 }
      expect(mapper.call(values)).to eq('z.enum(["active"])')
    end

    it "escapes double quotes in values" do
      values = { 'say "hello"' => 0 }
      expect(mapper.call(values)).to eq('z.enum(["say \\"hello\\""])')
    end

    it "escapes JavaScript control characters and backslashes" do
      values = ["back\\slash", "new\nline", "tab\tvalue"]
      expect(mapper.call(values)).to eq('z.enum(["back\\\\slash", "new\\nline", "tab\\tvalue"])')
    end
  end

  describe ".call with nullable option" do
    it "appends .nullable() when nullable: true" do
      values = { "draft" => 0, "published" => 1 }
      expect(mapper.call(values, nullable: true)).to eq('z.enum(["draft", "published"]).nullable()')
    end
  end

  describe ".call with input_schema option" do
    it "uses .nullish() for nullable input schemas" do
      values = { "draft" => 0, "published" => 1 }
      expect(mapper.call(values, nullable: true, input_schema: true)).to eq('z.enum(["draft", "published"]).nullish()')
    end

    it "uses .optional() for columns with defaults in input schema" do
      values = { "draft" => 0, "published" => 1 }
      expect(mapper.call(values, has_default: true,
                                 input_schema: true)).to eq('z.enum(["draft", "published"]).optional()')
    end
  end
end
