# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "End-to-end generation", type: :integration do
  let(:output_dir) { Dir.mktmpdir }
  let(:generator) { ZodRails::Generator.new(output_dir: output_dir) }

  after { FileUtils.remove_entry(output_dir) }

  let(:model_class) do
    columns = [
      double(:column, name: "id", type: :integer, null: false, default: 1),
      double(:column, name: "name", type: :string, null: false, default: nil),
      double(:column, name: "email", type: :string, null: false, default: nil),
      double(:column, name: "age", type: :integer, null: true, default: nil),
      double(:column, name: "status", type: :integer, null: false, default: 0),
      double(:column, name: "bio", type: :text, null: true, default: nil),
      double(:column, name: "metadata", type: :json, null: true, default: nil),
      double(:column, name: "uuid", type: :uuid, null: false, default: nil),
      double(:column, name: "born_on", type: :date, null: true, default: nil),
      double(:column, name: "created_at", type: :datetime, null: false, default: nil),
      double(:column, name: "score", type: :decimal, null: true, default: nil),
      double(:column, name: "active", type: :boolean, null: false, default: true)
    ]

    presence_validator = double(:validator, kind: :presence, options: {}, attributes: [:name])
    length_validator = double(:validator, kind: :length, options: { minimum: 2, maximum: 100 }, attributes: [:name])
    format_validator = double(:validator, kind: :format, options: { with: /\A[\w+\-.]+@[a-z\d-]+\.[a-z]+\z/i },
                                          attributes: [:email])
    numericality_validator = double(:validator, kind: :numericality, options: { greater_than: 0, less_than: 150 },
                                                attributes: [:age])
    score_numericality_validator = double(:validator, kind: :numericality,
                                                      options: { greater_than_or_equal_to: 0 },
                                                      attributes: [:score])

    klass = class_double("User")
    allow(klass).to receive(:name).and_return("User")
    allow(klass).to receive(:columns).and_return(columns)
    allow(klass).to receive(:defined_enums).and_return({
                                                         "status" => { "pending" => 0, "active" => 1, "suspended" => 2 }
                                                       })
    allow(klass).to receive(:validators).and_return([
                                                      presence_validator,
                                                      length_validator,
                                                      format_validator,
                                                      numericality_validator,
                                                      score_numericality_validator
                                                    ])
    klass
  end

  describe "full generation pipeline" do
    it "generates a valid TypeScript file" do
      filename = generator.generate(model_class)
      expect(filename).to eq("user.ts")

      content = File.read(File.join(output_dir, filename))
      expect(content).to include('import { z } from "zod"')
    end

    it "includes both response and input schemas" do
      filename = generator.generate(model_class)
      content = File.read(File.join(output_dir, filename))

      expect(content).to include("export const UserSchema =")
      expect(content).to include("export const UserInputSchema =")
      expect(content).to include("export type User = z.infer<typeof UserSchema>")
      expect(content).to include("export type UserInput = z.infer<typeof UserInputSchema>")
    end

    it "maps all column types correctly" do
      filename = generator.generate(model_class)
      content = File.read(File.join(output_dir, filename))

      expect(content).to include("id: z.int()")
      expect(content).to include("name: z.string()")
      expect(content).to include("bio: z.string().nullable()")
      expect(content).to include("metadata: z.json().nullable()")
      expect(content).to include("uuid: z.uuid()")
      expect(content).to include("born_on: z.iso.date().nullable()")
      expect(content).to include("created_at: z.iso.datetime({ offset: true })")
      expect(content).to include("score: z.string().nullable()")
      expect(content).to include("active: z.boolean()")
    end

    it "maps enum columns to z.enum" do
      filename = generator.generate(model_class)
      content = File.read(File.join(output_dir, filename))

      expect(content).to include('status: z.enum(["pending", "active", "suspended"])')
    end

    it "applies validation chains" do
      filename = generator.generate(model_class)
      content = File.read(File.join(output_dir, filename))

      expect(content).to match(/name: z\.string\(\)\.min\(2\)\.max\(100\)/)
      expect(content).to match(/email: z\.string\(\)\.regex\(/)
      expect(content).to match(/age: z\.int\(\)\.gt\(0\)\.lt\(150\)/)
      expect(content).to include("score: z.string().nullable()")
    end

    it "excludes id/timestamps from input schema" do
      filename = generator.generate(model_class)
      content = File.read(File.join(output_dir, filename))

      response_section = content.split("export const UserInputSchema")[0]
      input_section = content.split("export const UserInputSchema")[1]

      expect(response_section).to include("id: z.int()")
      expect(input_section).not_to match(/\bid:\s*z\./)
      expect(input_section).not_to match(/\bcreated_at:\s*z\./)
      expect(input_section).not_to match(/\bupdated_at:\s*z\./)
      expect(input_section).to include("active: z.boolean().optional()")
    end
  end

  describe "edge cases" do
    let(:empty_model) do
      klass = class_double("EmptyModel")
      allow(klass).to receive(:name).and_return("EmptyModel")
      allow(klass).to receive(:columns).and_return([])
      allow(klass).to receive(:defined_enums).and_return({})
      allow(klass).to receive(:validators).and_return([])
      klass
    end

    it "handles models with no columns" do
      filename = generator.generate(empty_model)
      content = File.read(File.join(output_dir, filename))

      expect(content).to include("z.object({")
      expect(content).to include("})")
    end

    let(:namespaced_model) do
      klass = class_double("Admin::Dashboard::Widget")
      allow(klass).to receive(:name).and_return("Admin::Dashboard::Widget")
      allow(klass).to receive(:columns).and_return([
                                                     double(:column, name: "id", type: :integer, null: false,
                                                                     default: nil)
                                                   ])
      allow(klass).to receive(:defined_enums).and_return({})
      allow(klass).to receive(:validators).and_return([])
      klass
    end

    it "handles namespaced models with correct path" do
      filename = generator.generate(namespaced_model)
      expect(filename).to eq("admin/dashboard/widget.ts")

      full_path = File.join(output_dir, filename)
      expect(File.exist?(full_path)).to be true
    end
  end

  describe "generate_all" do
    it "generates multiple models" do
      model2 = class_double("Post")
      allow(model2).to receive(:name).and_return("Post")
      allow(model2).to receive(:columns).and_return([
                                                      double(:column, name: "id", type: :integer, null: false,
                                                                      default: nil),
                                                      double(:column, name: "title", type: :string, null: false,
                                                                      default: nil)
                                                    ])
      allow(model2).to receive(:defined_enums).and_return({})
      allow(model2).to receive(:validators).and_return([])

      files = generator.generate_all([model_class, model2])

      expect(files).to contain_exactly("user.ts", "post.ts")
      expect(File.exist?(File.join(output_dir, "user.ts"))).to be true
      expect(File.exist?(File.join(output_dir, "post.ts"))).to be true
    end
  end
end
