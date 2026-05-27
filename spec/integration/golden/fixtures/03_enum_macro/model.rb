# frozen_string_literal: true

# Rails `enum :role, { ... }` declarations — routed through EnumMapper,
# not the validation-chain path. Verifies z.enum is emitted with the right
# nullability/optional semantics on response vs input schemas.
{
  name: "Account",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "role", type: :integer, null: false, default: 0 },
    { name: "status", type: :integer, null: true, default: nil }
  ],
  enums: {
    "role" => { "member" => 0, "admin" => 1, "moderator" => 2 },
    "status" => { "pending" => 0, "active" => 1, "suspended" => 2 }
  },
  validators: []
}
