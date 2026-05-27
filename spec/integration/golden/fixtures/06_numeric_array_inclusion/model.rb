# frozen_string_literal: true

# Bug 1, numeric variant: inclusion array on a numeric column. Becomes
# .pipe(z.literal(...)) for a single value, .pipe(z.union([...])) for many.
# z.enum is string-only in Zod 4, so numeric arrays need the union path.
{
  name: "Priority",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "level", type: :integer, null: false, default: nil }
  ],
  enums: {},
  validators: [
    { kind: :inclusion, attributes: [:level], options: { in: [1, 5, 10] } }
  ]
}
