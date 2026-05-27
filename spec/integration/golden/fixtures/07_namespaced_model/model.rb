# frozen_string_literal: true

# Namespaced model names: file path stays admin/user.ts, but the
# export const / type identifiers collapse to AdminUserSchema /
# AdminUser to produce valid TypeScript. Before the fix, the gem
# emitted `export const Admin::UserSchema` — illegal identifier.
{
  name: "Admin::User",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "email", type: :string, null: false, default: nil }
  ],
  enums: {},
  validators: [
    { kind: :presence, attributes: [:email], options: {} }
  ]
}
