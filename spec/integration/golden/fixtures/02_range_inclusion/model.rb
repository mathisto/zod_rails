# frozen_string_literal: true

# Inclusion with a numeric Range — existing supported case.
# Locks in: range bounds become .min/.max on integer.
{
  name: "Survey",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "rating", type: :integer, null: false, default: nil }
  ],
  enums: {},
  validators: [
    { kind: :inclusion, attributes: [:rating], options: { in: 1..5 } }
  ]
}
