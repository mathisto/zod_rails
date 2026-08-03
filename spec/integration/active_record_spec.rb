# frozen_string_literal: true

require "spec_helper"
require "sqlite3"
require "tmpdir"

RSpec.describe "ActiveRecord integration" do
  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table :integration_articles, force: true do |table|
        table.string :title
        table.integer :rating
        table.bigint :external_id
        table.time :opens_at
        table.datetime :published_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      end
    end
  end

  after(:all) do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  it "generates constraints from real columns and validators" do
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "integration_articles"

      validates :title, presence: true
      validates :rating, inclusion: { in: -5...5 }
    end
    stub_const("IntegrationArticle", model)

    content = Dir.mktmpdir do |output_dir|
      ZodRails::Generator.new(output_dir: output_dir).generate_content(model)[:content]
    end

    expect(content).to include("title: z.string().min(1).refine(")
    expect(content).to include("rating: z.int().gte(-5).lt(5).nullable()")
    expect(content).to include("external_id: z.int().nullable()")
    expect(content).to include("opens_at: z.iso.datetime({ offset: true }).nullable()")
    expect(content).to include("published_at: z.iso.datetime({ offset: true }).optional()")
  end

  it "matches the JSON shapes emitted by real time and bigint attributes" do
    model = Class.new(ActiveRecord::Base) { self.table_name = "integration_articles" }
    record = model.new(opens_at: "09:00:00", external_id: 42)

    expect(record.as_json.slice("opens_at", "external_id")).to eq(
      "opens_at" => "2000-01-01T09:00:00.000Z",
      "external_id" => 42
    )
  end
end
