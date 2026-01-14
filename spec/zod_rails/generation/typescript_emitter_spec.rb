# frozen_string_literal: true

require "spec_helper"

RSpec.describe ZodRails::Generation::TypescriptEmitter do
  subject(:emitter) { described_class.new }

  describe "#emit" do
    let(:schema_name) { "ArticleSchema" }
    let(:schema_body) { "z.object({\n  id: z.int(),\n  title: z.string()\n})" }

    it "includes zod import" do
      output = emitter.emit(schema_name: schema_name, schema_body: schema_body)
      expect(output).to include('import { z } from "zod";')
    end

    it "exports the schema as const" do
      output = emitter.emit(schema_name: schema_name, schema_body: schema_body)
      expect(output).to include("export const ArticleSchema =")
    end

    it "exports inferred type" do
      output = emitter.emit(schema_name: schema_name, schema_body: schema_body)
      expect(output).to include("export type Article = z.infer<typeof ArticleSchema>;")
    end

    it "includes the schema body" do
      output = emitter.emit(schema_name: schema_name, schema_body: schema_body)
      expect(output).to include("z.object({")
    end
  end

  describe "#emit with input schema" do
    let(:schema_name) { "ArticleInputSchema" }
    let(:schema_body) { "z.object({\n  title: z.string()\n})" }

    it "exports input type with Input suffix" do
      output = emitter.emit(schema_name: schema_name, schema_body: schema_body)
      expect(output).to include("export type ArticleInput = z.infer<typeof ArticleInputSchema>;")
    end
  end

  describe "#emit_combined" do
    let(:response_schema) { { name: "ArticleSchema", body: "z.object({ id: z.int() })" } }
    let(:input_schema) { { name: "ArticleInputSchema", body: "z.object({ title: z.string() })" } }

    it "emits both schemas in one file" do
      output = emitter.emit_combined(response: response_schema, input: input_schema)
      expect(output).to include("export const ArticleSchema =")
      expect(output).to include("export const ArticleInputSchema =")
    end

    it "only includes one import statement" do
      output = emitter.emit_combined(response: response_schema, input: input_schema)
      expect(output.scan("import { z }").count).to eq(1)
    end
  end
end
