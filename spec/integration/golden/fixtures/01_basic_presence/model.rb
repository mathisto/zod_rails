# frozen_string_literal: true

# A minimal model: presence validations on a couple of string columns.
# Locks in baseline behavior: z.string() with .min(1) for required text.
{
  name: "Article",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "title", type: :string, null: false, default: nil },
    { name: "body", type: :text, null: false, default: nil },
    { name: "created_at", type: :datetime, null: false, default: nil },
    { name: "updated_at", type: :datetime, null: false, default: nil }
  ],
  enums: {},
  validators: [
    { kind: :presence, attributes: [:title], options: {} },
    { kind: :presence, attributes: [:body], options: {} }
  ]
}
