# frozen_string_literal: true

# Regression fixture for backslash escaping in generated `new RegExp(...)`
# literals. The chain is spliced in ahead of a nullability suffix, which is the
# path that used to run the expression through a `sub` replacement string and
# collapse `\\.` to `\.` and `\\s` to `\s`. `slug` is the contrast case: not
# null and no default, so it carries no suffix in either schema.
{
  name: "Profile",
  columns: [
    { name: "id", type: :integer, null: false, default: nil },
    { name: "slug", type: :string, null: false, default: nil },
    { name: "email", type: :string, null: true, default: nil },
    { name: "website", type: :string, null: true, default: nil },
    { name: "locale", type: :string, null: false, default: "en" }
  ],
  validators: [
    { kind: :format, attributes: [:slug], options: { with: /\A[a-z\d]+(?:-[a-z\d]+)*\z/ } },
    { kind: :format, attributes: [:email], options: { with: /\A[^@\s]+@[^@\s]+\.[A-Za-z]{2,}\z/ } },
    { kind: :format, attributes: [:website], options: { with: %r{\Ahttps://\S+\.\S+\z} } },
    { kind: :format, attributes: [:locale], options: { with: /\A[a-z]{2}\z/ } }
  ]
}
