# frozen_string_literal: true

# Kitchen-sink fixture: every supported validation kind, multiple column
# types, nullables, defaults, enums. If a refactor breaks output shape
# anywhere, this fixture catches it. (Namespaced model names produce
# invalid TS today — tracked as a separate bug.)
{
  name: "User",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "email", type: :string, null: false, default: nil },
    { name: "name", type: :string, null: false, default: nil },
    { name: "age", type: :integer, null: true, default: nil },
    { name: "bio", type: :text, null: true, default: nil },
    { name: "score", type: :decimal, null: true, default: nil },
    { name: "active", type: :boolean, null: false, default: true },
    { name: "uuid", type: :uuid, null: false, default: nil },
    { name: "born_on", type: :date, null: true, default: nil },
    { name: "metadata", type: :json, null: true, default: nil },
    { name: "role", type: :integer, null: false, default: 0 },
    { name: "created_at", type: :datetime, null: false, default: nil },
    { name: "updated_at", type: :datetime, null: false, default: nil }
  ],
  enums: {
    "role" => { "member" => 0, "admin" => 1 }
  },
  validators: [
    { kind: :presence, attributes: [:email], options: {} },
    { kind: :format, attributes: [:email], options: { with: /\A[\w+\-.]+@[a-z\d-]+\.[a-z]+\z/i } },
    { kind: :presence, attributes: [:name], options: {} },
    { kind: :length, attributes: [:name], options: { minimum: 2, maximum: 100 } },
    { kind: :numericality, attributes: [:age], options: { greater_than: 0, less_than: 150 } }
  ]
}
