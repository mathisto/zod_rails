# ZodRails

Generate [Zod](https://zod.dev) schemas from your ActiveRecord models. Bridge the gap between your Rails backend and TypeScript frontend with type-safe validation that stays in sync with your database schema and model validations.

## Why ZodRails?

When building Rails APIs consumed by TypeScript frontends, you often duplicate validation logic: once in your Rails models, again in your frontend forms. ZodRails eliminates this duplication by generating Zod schemas directly from your ActiveRecord models, including:

- Database column types mapped to Zod types
- Rails validations (presence, length, numericality, format) mapped to Zod constraints
- Enums generated as `z.enum()` with proper string literals
- Nullable columns and default values handled correctly
- Separate schemas for API responses vs. form inputs

## Requirements

- Ruby 3.2+
- Rails 7.0+ (uses ActiveRecord and Railtie)
- Zod 4.x in your frontend project

## Installation

Add to your Gemfile:

```ruby
gem "zod_rails"
```

Then run:

```bash
bundle install
```

## Quick Start

### 1. Configure the gem

Create an initializer at `config/initializers/zod_rails.rb`:

```ruby
ZodRails.configure do |config|
  config.output_dir = Rails.root.join("app/javascript/schemas").to_s
  config.models = %w[User Post Comment]
end
```

### 2. Generate schemas

```bash
bin/rails zod_rails:generate
```

### 3. Use in your frontend

```typescript
import { UserSchema, UserInputSchema, type User } from "./schemas/user";

// Validate API response
const user = UserSchema.parse(apiResponse);

// Validate form input
const formData = UserInputSchema.parse(formValues);
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `output_dir` | `app/javascript/schemas` | Directory for generated TypeScript files |
| `models` | `[]` | Array of model names to generate schemas for |
| `schema_suffix` | `Schema` | Suffix for response schemas (e.g., `UserSchema`) |
| `input_schema_suffix` | `InputSchema` | Suffix for input schemas (e.g., `UserInputSchema`) |
| `generate_input_schemas` | `true` | Whether to generate input schemas |
| `excluded_columns` | `["id", "created_at", "updated_at"]` | Columns to exclude from input schemas |

### Full Configuration Example

```ruby
ZodRails.configure do |config|
  config.output_dir = Rails.root.join("frontend/src/schemas").to_s
  config.models = %w[User Post Comment Tag]
  config.schema_suffix = "Schema"
  config.input_schema_suffix = "FormSchema"
  config.generate_input_schemas = true
  config.excluded_columns = %w[id created_at updated_at deleted_at]
end
```

## Type Mappings

| Rails/DB Type | Zod Type |
|---------------|----------|
| `string`, `text` | `z.string()` |
| `integer`, `bigint` | `z.int()` |
| `float`, `decimal` | `z.number()` |
| `boolean` | `z.boolean()` |
| `date` | `z.iso.date()` |
| `datetime`, `timestamp` | `z.iso.datetime()` |
| `json`, `jsonb` | `z.json()` |
| `uuid` | `z.uuid()` |
| `enum` | `z.enum([...])` |

## Validation Mappings

ZodRails introspects your model validations and maps them to Zod constraints:

| Rails Validation | Zod Constraint |
|------------------|----------------|
| `presence: true` | `.min(1)` for strings |
| `length: { minimum: n }` | `.min(n)` |
| `length: { maximum: n }` | `.max(n)` |
| `length: { is: n }` | `.length(n)` |
| `numericality: { greater_than: n }` | `.gt(n)` |
| `numericality: { greater_than_or_equal_to: n }` | `.gte(n)` |
| `numericality: { less_than: n }` | `.lt(n)` |
| `numericality: { less_than_or_equal_to: n }` | `.lte(n)` |
| `format: { with: /regex/ }` | `.regex(/regex/)` |
| `inclusion: { in: n..m }` | `.min(n).max(m)` |

## Generated Output Example

Given this Rails model:

```ruby
class User < ApplicationRecord
  enum :role, { member: 0, admin: 1, moderator: 2 }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :age, numericality: { greater_than: 0, less_than: 150 }, allow_nil: true
end
```

ZodRails generates:

```typescript
import { z } from "zod";

export const UserSchema = z.object({
  id: z.int(),
  email: z.string().min(1).regex(/\A[^@\s]+@[^@\s]+\z/),
  name: z.string().min(2).max(100),
  age: z.int().gt(0).lt(150).nullable(),
  role: z.enum(["member", "admin", "moderator"]),
  created_at: z.iso.datetime(),
  updated_at: z.iso.datetime()
});

export type User = z.infer<typeof UserSchema>;

export const UserInputSchema = z.object({
  email: z.string().min(1).regex(/\A[^@\s]+@[^@\s]+\z/),
  name: z.string().min(2).max(100),
  age: z.int().gt(0).lt(150).nullish(),
  role: z.enum(["member", "admin", "moderator"]).optional()
});

export type UserInput = z.infer<typeof UserInputSchema>;
```

## Schema vs InputSchema

ZodRails generates two schema variants:

**Schema** (e.g., `UserSchema`)
- Represents data as returned from your API
- Includes all columns (`id`, timestamps, etc.)
- Uses `.nullable()` for nullable columns

**InputSchema** (e.g., `UserInputSchema`)
- Represents data for form submission
- Excludes configured columns (defaults: `id`, `created_at`, `updated_at`)
- Uses `.optional()` for columns with database defaults
- Uses `.nullish()` for nullable columns without defaults

## Integrating with Forms

ZodRails pairs well with form libraries that support Zod:

### React Hook Form

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { UserInputSchema, type UserInput } from "./schemas/user";

function UserForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<UserInput>({
    resolver: zodResolver(UserInputSchema)
  });

  const onSubmit = (data: UserInput) => {
    // data is fully typed and validated
  };

  return <form onSubmit={handleSubmit(onSubmit)}>...</form>;
}
```

### Validating API Responses

```typescript
import { UserSchema, type User } from "./schemas/user";

async function fetchUser(id: number): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  const data = await response.json();
  return UserSchema.parse(data); // Throws if invalid
}
```

## CI/CD Integration

Add schema generation to your build process to catch type mismatches early:

```yaml
# .github/workflows/ci.yml
- name: Generate Zod schemas
  run: bin/rails zod_rails:generate

- name: Check for uncommitted schema changes
  run: git diff --exit-code app/javascript/schemas/
```

## Troubleshooting

### Schemas not updating after model changes

Re-run the generator after any model changes:

```bash
bin/rails zod_rails:generate
```

### Validation constraints not appearing

Ensure validations are defined on the model class, not in concerns that might not be loaded. Conditional validations (`:if`, `:unless`) are detected and excluded by default.

### Custom column types

For custom types not in the mapping table, ZodRails falls back to `z.unknown()`. Open an issue if you need support for additional types.

## Development

After checking out the repo:

```bash
bundle install
bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.
