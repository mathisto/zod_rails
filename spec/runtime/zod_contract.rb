# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "generated Zod runtime contract" do
  it "parses representative Rails payload shapes with the installed Zod version" do
    columns = [
      column_info("tags", :string, array: true, has_default: true),
      column_info("external_id", :bigint),
      column_info("opens_at", :time),
      column_info("published_at", :datetime)
    ]
    inspector = instance_double(
      ZodRails::Introspection::ModelInspector,
      model_name: "RuntimePayload",
      columns: columns,
      enums: {}
    )
    allow(inspector).to receive(:validations_for).and_return([])
    inclusion = ZodRails::Introspection::ValidationInfo.new(
      kind: :inclusion,
      attribute: :tags,
      options: { in: %w[alpha beta] },
      conditional: false
    )
    allow(inspector).to receive(:validations_for).with("tags").and_return([inclusion])

    builder = ZodRails::Generation::SchemaBuilder.new(inspector)
    schema = ZodRails::Generation::TypescriptEmitter.new.emit(
      schema_name: builder.schema_name,
      schema_body: builder.build,
      type_name: builder.type_name
    )
    payload = {
      tags: %w[alpha beta],
      external_id: 42,
      opens_at: "2000-01-01T09:00:00.000Z",
      published_at: "2026-08-03T11:04:05-04:00"
    }

    Dir.mktmpdir("zod-rails-runtime-", Dir.pwd) do |directory|
      schema_path = File.join(directory, "runtime_payload.ts")
      File.write(schema_path, schema)
      script = <<~TS
        import { RuntimePayloadSchema } from #{JSON.generate(schema_path)};
        const payload = JSON.parse(process.env.PAYLOAD);
        RuntimePayloadSchema.parse(payload);
        if (RuntimePayloadSchema.safeParse({ ...payload, tags: ["invalid"] }).success) {
          throw new Error("array element inclusion was not enforced");
        }
      TS
      _stdout, stderr, status = Open3.capture3(
        { "PAYLOAD" => JSON.generate(payload) }, "bun", "-e", script, chdir: Dir.pwd
      )

      expect(stderr).to eq("")
      expect(status).to be_success
    end
  end

  def column_info(name, type, array: false, has_default: false)
    ZodRails::Introspection::ColumnInfo.new(
      name: name,
      type: type,
      nullable: false,
      has_default: has_default,
      array: array
    )
  end
end
