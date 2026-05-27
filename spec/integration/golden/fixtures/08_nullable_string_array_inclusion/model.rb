# frozen_string_literal: true

# Nullable string column with array inclusion: z.enum still wins as the
# base type, with the nullability suffixes layered on as usual.
{
  name: "Ticket",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "priority", type: :string, null: true, default: "low" }
  ],
  enums: {},
  validators: [
    { kind: :inclusion, attributes: [:priority], options: { in: %w[low medium high] } }
  ]
}
