# frozen_string_literal: true

{
  name: "ArrayRecord",
  columns: [
    { name: "tags", type: :string, null: false, default: [], array: true },
    { name: "optional_tags", type: :string, null: true, default: nil, array: true },
    { name: "scores", type: :integer, null: false, default: nil, array: true }
  ],
  validators: [
    { kind: :presence, attributes: [:tags] },
    { kind: :length, attributes: [:tags], options: { maximum: 5 } },
    { kind: :inclusion, attributes: [:tags], options: { in: %w[alpha beta] } }
  ]
}
