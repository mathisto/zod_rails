# frozen_string_literal: true

# Bug 1: validates :decision, inclusion: { in: %w[...] } on a string column
# silently dropped the constraint. After the fix, an array inclusion of
# strings on a string column should emit .pipe(z.enum([...])), composing
# cleanly with .min(1) from presence.
{
  name: "FileReviewDecision",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "decision", type: :string, null: false, default: nil }
  ],
  enums: {},
  validators: [
    { kind: :presence, attributes: [:decision], options: {} },
    { kind: :inclusion, attributes: [:decision], options: { in: %w[pending approved not_applicable] } }
  ]
}
