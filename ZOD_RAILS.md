# ZodRails: Complete Architectural Plan

> **Status**: Planning Phase  
> **Last Updated**: 2025-01-13  
> **Development Approach**: Prose-Driven TDD with RSpec

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Summary of Decisions](#2-summary-of-decisions)
3. [Gem File Structure](#3-gem-file-structure)
4. [Type Mapping Tables](#4-type-mapping-tables)
5. [Validation Mapping Tables](#5-validation-mapping-tables)
6. [Prose-Driven RSpec Specifications](#6-prose-driven-rspec-specifications)
7. [Example Generated Output](#7-example-generated-output)
8. [Configuration DSL](#8-configuration-dsl)
9. [Implementation Order](#9-implementation-order)
10. [Open Questions](#10-open-questions)
11. [Research Findings](#11-research-findings)

---

## 1. Problem Statement

### The "Type Gap"

The core issue is that **ActiveRecord (Ruby)** and **Zod (TypeScript)** speak two different languages regarding data structure.

- **Implicit vs. Explicit**: Rails models are "magic." Attributes are discovered at runtime by querying the database schema. Zod requires explicit, static definitions.

- **Type Mapping**: A Rails `:datetime` needs to become a `z.coerce.date()`. A `:string` with a `validates :presence` needs to be `z.string().min(1)`, while an optional one needs `.nullable()`.

- **The Sync Problem**: Every time you run a migration in Rails, your Zod schemas are instantly out of date. Without a gem, you are manually typing the same structure in two places, which is the primary source of "undefined is not a function" errors in production.

### Why This Matters

Building this gem solves a major pain point in the Rails ecosystem. Currently, developers have to choose between:

- **Manual duplication** (Error prone)
- **JSON Schema intermediate steps** (Overly complex)
- **TypeScript Interfaces** (No runtime protection)

By creating a gem that outputs **Zod Schemas** specifically, you provide the frontend with a "contract" that actually has teeth—it won't just tell you the data is a string; it will crash safely or handle the error if the backend sends a null.

### Market Gap

**No gem exists that directly generates Zod schemas from Rails/ActiveRecord.** Research confirmed:

- `zod_rails` ❌ unclaimed
- `rails_zod` ❌ unclaimed
- `active_record_zod` ❌ unclaimed

The closest solutions are either archived, don't read from ActiveRecord, or require manual DSL definitions.

---

## 2. Summary of Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Gem Name** | `zod_rails` | Clear, follows Rails gem conventions |
| **Output Strategy** | File generation + optional file watcher | Deterministic, version-controllable |
| **File Watcher** | `listen` (optional dependency) | Already in most Rails apps, actively maintained |
| **Validation Mapping** | Tier 1 + 2 for v1 | Covers 90% of use cases |
| **Association Strategy** | Columns-only by default | `belongs_to` FKs only; `has_one`/`has_many` require opt-in |
| **Schema Types** | Generate both Response + Input schemas | `ModelSchema` (full) + `ModelInputSchema` (forms) |
| **Property Naming** | `snake_case` by default | Matches Rails API responses; `camelCase` opt-in |
| **Serializer Awareness** | v2 roadmap item | Keep v1 scope focused |
| **Enum Handling** | String keys (modern Rails convention) | Matches typical API responses |
| **Development Approach** | Prose-driven TDD with RSpec | Specs as executable documentation |

---

## 3. Gem File Structure

```
zod_rails/
├── .rspec                          # RSpec configuration
├── .rubocop.yml                    # Code style (optional)
├── Gemfile                         # Gem dependencies
├── LICENSE.txt                     # MIT License
├── README.md                       # Documentation
├── ROADMAP.md                      # Completed + Future features
├── ARCHITECTURE.md                 # This document
├── Rakefile                        # Gem build tasks
├── zod_rails.gemspec               # Gem specification
│
├── lib/
│   ├── zod_rails.rb                # Main entry point
│   ├── zod_rails/
│   │   ├── version.rb              # Version constant
│   │   ├── configuration.rb        # Configuration DSL
│   │   ├── railtie.rb              # Rails integration (rake tasks)
│   │   │
│   │   ├── introspection/          # Reading from ActiveRecord
│   │   │   ├── model_inspector.rb  # Reads columns, validators, enums
│   │   │   ├── column_info.rb      # Value object for column metadata
│   │   │   └── validation_info.rb  # Value object for validation metadata
│   │   │
│   │   ├── mapping/                # Type translation logic
│   │   │   ├── type_mapper.rb      # Rails type → Zod type
│   │   │   ├── validation_mapper.rb # Rails validation → Zod chain
│   │   │   └── enum_mapper.rb      # Rails enum → z.enum()
│   │   │
│   │   ├── generation/             # Output generation
│   │   │   ├── schema_builder.rb   # Builds Zod schema string per model
│   │   │   ├── file_writer.rb      # Writes the .ts file
│   │   │   └── typescript_emitter.rb # Formats TypeScript output
│   │   │
│   │   └── associations/           # Association handling
│   │       ├── association_resolver.rb  # Determines how to represent assocs
│   │       └── nesting_strategy.rb      # ID-only vs nested objects
│   │
│   └── tasks/
│       └── zod_rails.rake          # Rake tasks (generate, watch)
│
└── spec/
    ├── spec_helper.rb              # RSpec configuration
    ├── support/
    │   ├── rails_app/              # Dummy Rails app for integration tests
    │   └── model_helpers.rb        # Test model factories
    │
    ├── zod_rails/
    │   ├── configuration_spec.rb
    │   ├── introspection/
    │   │   └── model_inspector_spec.rb
    │   ├── mapping/
    │   │   ├── type_mapper_spec.rb
    │   │   ├── validation_mapper_spec.rb
    │   │   └── enum_mapper_spec.rb
    │   ├── generation/
    │   │   ├── schema_builder_spec.rb
    │   │   └── file_writer_spec.rb
    │   └── associations/
    │       └── association_resolver_spec.rb
    │
    └── integration/
        ├── full_generation_spec.rb     # End-to-end tests
        └── rails_integration_spec.rb   # Rake task tests
```

---

## 4. Type Mapping Tables

> **Zod Version**: This gem targets **Zod 4** (stable as of 2025). Zod 4 introduces top-level string formats and number formats that we prefer over the deprecated method equivalents.

### Column Types → Zod Types

| Rails Type | Zod Type | Notes |
|------------|----------|-------|
| `:string` | `z.string()` | |
| `:text` | `z.string()` | |
| `:integer` | `z.int()` | Zod 4 top-level, replaces `z.number().int()` |
| `:bigint` | `z.string()` | Avoids JS safe integer overflow; use `z.int()` only if values guaranteed safe |
| `:float` | `z.number()` | |
| `:decimal` | `z.string()` | Preserves precision; `z.number()` opt-in via config |
| `:boolean` | `z.boolean()` | |
| `:date` | `z.iso.date()` | ISO date string by default; `z.coerce.date()` opt-in |
| `:datetime` | `z.iso.datetime()` | ISO datetime string; `z.coerce.date()` opt-in for Date objects |
| `:time` | `z.string()` | ISO time string |
| `:json` / `:jsonb` | `z.json()` | Zod 4 native; accepts any JSON-encodable value |
| `:uuid` | `z.uuid()` | Zod 4 top-level |
| `:binary` | `z.string()` | Base64 encoded |
| `:array` (PostgreSQL) | `z.array(innerType)` | Depends on inner type |

### Zod 4 Number Formats (for strict typing)

| Use Case | Zod Type | Range |
|----------|----------|-------|
| General integer | `z.int()` | `[Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER]` |
| 32-bit signed | `z.int32()` | `[-2147483648, 2147483647]` |
| 32-bit unsigned | `z.uint32()` | `[0, 4294967295]` |
| 32-bit float | `z.float32()` | IEEE 754 single precision |
| 64-bit float | `z.float64()` | IEEE 754 double precision |

These can be used via configuration for stricter database-aware typing.

### Nullability vs Optionality (CRITICAL)

Zod distinguishes three concepts that Rails conflates:

| Zod Method | Meaning | Use Case |
|------------|---------|----------|
| `.nullable()` | Accepts `null` value | Column allows NULL in DB |
| `.optional()` | Key can be missing (`undefined`) | PATCH payloads, sparse responses |
| `.nullish()` | Accepts `null` OR `undefined` | Flexible API contracts |

**Mapping Rules:**

| Rails Condition | Response Schema | Input Schema |
|-----------------|-----------------|--------------|
| `null: false` in DB | Required (no modifier) | Required |
| `null: true` in DB | `.nullable()` | `.nullish()` |
| `validates :presence` | Removes `.nullable()` | `.min(1)` for strings |
| `allow_nil: true` on validator | Preserves `.nullable()` | `.nullable()` |
| `allow_blank: true` on validator | Allows empty string | No `.min(1)` |
| DB default exists | Required in response | `.optional()` in input |

### Nullability Rules (Legacy - Simplified)

| Condition | Zod Output |
|-----------|------------|
| `null: false` in schema | Base type (required) |
| `null: true` or unspecified | `.nullable()` |
| `validates :presence` | `.min(1)` for strings, removes nullable |

---

## 5. Validation Mapping Tables

### Tier 1: Essential Validations (v1)

| Rails Validation | Zod Equivalent |
|------------------|----------------|
| `presence: true` | `.min(1)` (string), removes `.nullable()` |
| `length: { minimum: N }` | `.min(N)` |
| `length: { maximum: N }` | `.max(N)` |
| `length: { is: N }` | `.length(N)` |
| `length: { in: X..Y }` | `.min(X).max(Y)` |
| `inclusion: { in: [...] }` | `z.enum([...])` (replaces base type) |
| `numericality: true` | `z.number()` |
| `numericality: { only_integer: true }` | `.int()` |
| `numericality: { greater_than: N }` | `.gt(N)` |
| `numericality: { greater_than_or_equal_to: N }` | `.gte(N)` |
| `numericality: { less_than: N }` | `.lt(N)` |
| `numericality: { less_than_or_equal_to: N }` | `.lte(N)` |
| `numericality: { other_than: N }` | `.refine(v => v !== N)` |
| `numericality: { odd: true }` | `.refine(v => v % 2 === 1)` |
| `numericality: { even: true }` | `.refine(v => v % 2 === 0)` |

### Tier 2: Valuable Validations (v1)

| Rails Validation | Zod Equivalent |
|------------------|----------------|
| `format: { with: /regex/ }` | `.regex(/regex/)` |
| `exclusion: { in: [...] }` | `.refine(v => ![...].includes(v))` |
| `acceptance: true` | `z.literal(true)` or `z.boolean()` |
| `allow_nil: true` (on any validator) | Preserves `.nullable()` on type |
| `allow_blank: true` (on string) | Skips `.min(1)` from presence |

### Presence on Booleans (CAUTION)

Rails `presence: true` on booleans effectively means "must be truthy" because `false.blank? == true`. This is almost always a bug in Rails code.

**Our behavior**: Emit warning comment + map to `z.literal(true)`. Recommend user fix to `inclusion: { in: [true, false] }` if they want non-nil boolean.

### Validation Deduplication

When multiple validations apply to the same constraint, use the **stricter** value:

| Combined Validations | Deduped Output |
|---------------------|----------------|
| `presence: true` + `length: { minimum: 2 }` | `.min(2)` (not `.min(1).min(2)`) |
| `numericality: { greater_than: 0 }` + `numericality: { greater_than: 5 }` | `.gt(5)` |

The `ValidationMapper` must consolidate constraints before emitting Zod chains.

### Regex Conversion Strategy

Ruby regexes don't always translate cleanly to JavaScript. Use a **whitelist approach**:

| Rails Pattern | Detection | JavaScript Equivalent |
|--------------|-----------|----------------------|
| `URI::MailTo::EMAIL_REGEXP` | Check class/constant | `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` |
| `URI.regexp` | Check class/constant | Known URL regex |
| Simple patterns | Direct conversion | Escape as needed |
| Complex/unknown | Emit warning comment | Skip or use `.refine()` |

For unrecognized regexes, emit a TODO comment and optionally use `.refine()` with a runtime check.

### Zod 4 Built-in Email Regexes

Zod 4 provides several email regex options we can leverage:

| Rails Pattern | Zod 4 Equivalent |
|--------------|------------------|
| `URI::MailTo::EMAIL_REGEXP` | `z.email()` (default Gmail-style) |
| Loose validation | `z.email({ pattern: z.regexes.unicodeEmail })` |
| Browser-compatible | `z.email({ pattern: z.regexes.html5Email })` |
| RFC 5322 strict | `z.email({ pattern: z.regexes.rfc5322Email })` |

### Skipped Validations (Server-Side Only)

| Rails Validation | Reason |
|------------------|--------|
| `uniqueness` | Requires database query |
| `confirmation` | UI pattern - handled separately in InputSchema |
| Custom validators with `if:`/`unless:` | Conditional logic |
| `inclusion: { in: -> { ... } }` | Dynamic proc/lambda - cannot introspect statically |

**Dynamic Inclusions**: When `in:` is a proc/lambda, skip with comment. Allow config override to provide static list.

### Tier 3: Advanced Validations (v2 Roadmap)

| Rails Validation | Potential Zod Equivalent |
|------------------|--------------------------|
| Conditional validations (`if:`) | `.refine()` with runtime check |
| Custom validators | Extension point for user mapping |
| Associated validations | Nested schema validation |

---

## 6. Prose-Driven RSpec Specifications

> **Philosophy**: Each `it` statement without a block is a pending spec—our implementation checklist. Write the behavior we want in plain English first, then implement.

### `spec/zod_rails/configuration_spec.rb`

```ruby
RSpec.describe ZodRails::Configuration do
  describe "output path" do
    it "defaults to 'app/javascript/schemas/zod_schemas.ts'"
    it "can be configured via initializer"
    it "expands relative paths from Rails.root"
    it "creates the output directory if it does not exist"
  end

  describe "model selection" do
    it "includes all ApplicationRecord descendants by default"
    it "filters out abstract models (abstract_class = true)"
    it "filters out models without tables (table_exists? = false)"
    it "allows explicit model list via 'only' option"
    it "allows exclusion list via 'except' option"
    it "supports glob patterns for model selection"
    it "eager loads Rails app before introspection"
  end

  describe "association handling" do
    it "defaults to :ids_only mode"
    it "can be set to :nested mode globally"
    it "can be overridden per-model"
    it "supports :omit mode to exclude associations entirely"
  end

  describe "enum format" do
    it "defaults to string keys"
    it "can be configured to use integer values"
    it "documents the enum format choice in generated comments"
  end

  describe "custom type mappings" do
    it "allows overriding default type mappings"
    it "allows registering custom column types"
    it "applies custom mappings before defaults"
  end
end
```

### `spec/zod_rails/introspection/model_inspector_spec.rb`

```ruby
RSpec.describe ZodRails::Introspection::ModelInspector do
  describe "column extraction" do
    it "extracts all column names from an ActiveRecord model"
    it "extracts column types (string, integer, datetime, etc.)"
    it "detects nullability from column definition"
    it "identifies primary key columns"
    it "identifies foreign key columns"
    it "handles PostgreSQL-specific types (uuid, jsonb, array)"
  end

  describe "validation extraction" do
    it "extracts presence validations"
    it "extracts length validations with all options (min, max, is, in)"
    it "extracts inclusion validations with array values"
    it "extracts numericality validations with all constraints"
    it "extracts format validations with regex patterns"
    it "extracts allow_nil option from validators"
    it "extracts allow_blank option from validators"
    it "ignores validations with conditional :if/:unless options"
    it "ignores uniqueness validations (server-side only)"
    it "skips inclusion with proc/lambda :in (dynamic)"
    it "handles multiple validations on same attribute"
  end

  describe "enum extraction" do
    it "extracts Rails enum definitions"
    it "captures enum values as strings"
    it "handles enums with custom database values"
    it "handles enums with prefix/suffix options"
  end

  describe "association extraction" do
    it "extracts belongs_to associations"
    it "extracts has_many associations"
    it "extracts has_one associations"
    it "identifies optional vs required belongs_to"
    it "captures foreign key names"
    it "handles polymorphic associations (marks as v2/unsupported)"
  end
end
```

### `spec/zod_rails/mapping/type_mapper_spec.rb`

```ruby
RSpec.describe ZodRails::Mapping::TypeMapper do
  describe "primitive type mapping" do
    it "maps :string to z.string()"
    it "maps :text to z.string()"
    it "maps :integer to z.number().int()"
    it "maps :bigint to z.number().int()"
    it "maps :float to z.number()"
    it "maps :decimal to z.number() by default"
    it "maps :decimal to z.string() when precision mode enabled"
    it "maps :boolean to z.boolean()"
  end

  describe "date and time mapping" do
    it "maps :date to z.coerce.date()"
    it "maps :datetime to z.coerce.date()"
    it "maps :time to z.string() with time format note"
  end

  describe "special type mapping" do
    it "maps :uuid to z.string().uuid()"
    it "maps :json to z.record(z.unknown())"
    it "maps :jsonb to z.record(z.unknown())"
    it "maps :binary to z.string() with base64 note"
  end

  describe "PostgreSQL array types" do
    it "maps string[] to z.array(z.string())"
    it "maps integer[] to z.array(z.number().int())"
    it "preserves nullability on array elements"
  end

  describe "nullability" do
    it "appends .nullable() when column allows null"
    it "does not append .nullable() when null: false"
    it "removes .nullable() when presence validation exists"
  end

  describe "unknown types" do
    it "falls back to z.unknown() for unrecognized types"
    it "emits a warning comment for unknown types"
    it "allows custom type handlers to be registered"
  end
end
```

### `spec/zod_rails/mapping/validation_mapper_spec.rb`

```ruby
RSpec.describe ZodRails::Mapping::ValidationMapper do
  describe "presence validation" do
    it "adds .min(1) to string types"
    it "removes .nullable() from the type"
    it "has no effect on boolean types (false is valid)"
    it "adds .min(1) to array types"
  end

  describe "length validation" do
    it "maps minimum: N to .min(N)"
    it "maps maximum: N to .max(N)"
    it "maps is: N to .length(N)"
    it "maps in: X..Y to .min(X).max(Y)"
    it "handles length on string types"
    it "handles length on array types"
  end

  describe "inclusion validation" do
    it "converts to z.enum([...]) when all values are strings"
    it "converts to z.union([z.literal()...]) for mixed types"
    it "preserves the original type when inclusion has :in as Range"
    it "uses .refine() for Range-based inclusion"
  end

  describe "numericality validation" do
    it "confirms base type is z.number()"
    it "adds .int() for only_integer: true"
    it "adds .positive() for greater_than: 0"
    it "adds .nonnegative() for greater_than_or_equal_to: 0"
    it "adds .gt(N) for greater_than: N"
    it "adds .gte(N) for greater_than_or_equal_to: N"
    it "adds .lt(N) for less_than: N"
    it "adds .lte(N) for less_than_or_equal_to: N"
    it "adds .multipleOf(N) for other: N (if supported)"
  end

  describe "format validation" do
    it "maps format with regex to .regex()"
    it "escapes regex special characters for TypeScript"
    it "converts Ruby regex to JavaScript regex syntax"
    it "handles common Rails regex patterns (email, url)"
  end

  describe "validation chaining" do
    it "chains multiple validations in correct order"
    it "applies presence before length (removes nullable first)"
    it "applies type-changing validations (inclusion) before chainable ones"
  end

  describe "conditional validations" do
    it "skips validations with :if option"
    it "skips validations with :unless option"
    it "skips validations with :on option (create/update)"
    it "documents skipped validations in comments"
  end
end
```

### `spec/zod_rails/mapping/enum_mapper_spec.rb`

```ruby
RSpec.describe ZodRails::Mapping::EnumMapper do
  describe "basic enum mapping" do
    it "converts enum values to z.enum([...])"
    it "uses string keys by default"
    it "orders values as defined in the model"
  end

  describe "enum with custom values" do
    it "uses the defined keys, not database integers"
    it "handles enums defined with hash syntax"
  end

  describe "enum with prefix/suffix" do
    it "preserves the base enum values without prefix"
    it "documents the prefix/suffix in comments"
  end

  describe "enum format configuration" do
    it "can be configured to use integer values"
    it "outputs z.union([z.literal(0), ...]) for integer mode"
  end
end
```

### `spec/zod_rails/generation/schema_builder_spec.rb`

```ruby
RSpec.describe ZodRails::Generation::SchemaBuilder do
  describe "schema structure" do
    it "generates z.object({...}) wrapper"
    it "includes all mapped columns as properties"
    it "uses snake_case property names by default"
    it "can be configured to use camelCase property names"
  end

  describe "schema naming" do
    it "names schema after model (UserSchema for User)"
    it "flattens namespaced models (Admin::User → AdminUserSchema)"
    it "generates both schema and inferred type export"
  end

  describe "dual schema generation" do
    it "generates ModelSchema for response/DB shape"
    it "generates ModelInputSchema omitting id, timestamps, readonly fields"
    it "applies .optional() to fields with DB defaults in InputSchema"
    it "handles confirmation fields in InputSchema when present"
  end

  describe "generated output format" do
    it "includes import statement for zod"
    it "exports each schema as named export"
    it "exports TypeScript type using z.infer<>"
    it "adds JSDoc comments with model name"
    it "sorts schemas alphabetically"
  end

  describe "association fields" do
    it "adds foreign key fields for belongs_to (column exists)"
    it "does NOT add _id fields for has_one (column on other table)"
    it "does NOT add _ids arrays for has_many by default (virtual)"
    it "adds _ids arrays for has_many when config.include_association_ids = true"
    it "marks optional belongs_to as nullable"
    it "adds nested schema reference in :nested mode"
    it "adds array of nested schemas for has_many in :nested mode"
  end

  describe "topological sorting" do
    it "orders schemas to resolve dependencies (referenced before referencer)"
    it "handles circular dependencies with getter syntax"
    it "emits all leaf models (no outbound associations) first"
  end

  describe "special cases" do
    it "handles models with no validations"
    it "handles models with no associations"
    it "handles STI models (uses base class columns)"
    it "generates z.literal() for STI type discriminator column"
    it "marks unsupported features with TODO comments"
  end
end
```

### `spec/zod_rails/generation/file_writer_spec.rb`

```ruby
RSpec.describe ZodRails::Generation::FileWriter do
  describe "file output" do
    it "writes to configured output path"
    it "creates parent directories if needed"
    it "overwrites existing file"
    it "adds generation timestamp header"
    it "adds 'do not edit' warning comment"
  end

  describe "file formatting" do
    it "uses consistent indentation (2 spaces)"
    it "adds trailing newline"
    it "groups imports at top"
    it "separates schemas with blank lines"
  end

  describe "error handling" do
    it "raises descriptive error if directory not writable"
    it "raises descriptive error if path is invalid"
  end
end
```

### `spec/zod_rails/associations/association_resolver_spec.rb`

```ruby
RSpec.describe ZodRails::Associations::AssociationResolver do
  describe "belongs_to resolution" do
    it "returns foreign key field name (column exists on this model)"
    it "determines if association is optional"
    it "resolves the associated model class"
    it "detects polymorphic and emits both _type and _id columns"
  end

  describe "has_many resolution" do
    it "does NOT generate _ids by default (virtual attribute)"
    it "generates _ids when include_association_ids config enabled"
    it "resolves has_many :through to final target model"
    it "detects polymorphic :through and marks unsupported"
  end

  describe "has_one resolution" do
    it "does NOT generate _id by default (column on other table)"
    it "resolves the associated model class for nested mode"
  end

  describe "nesting strategy" do
    it "returns ID type for :ids_only mode (belongs_to FK only)"
    it "returns schema reference for :nested mode"
    it "handles circular references with getter syntax (Zod 4 pattern)"
    it "limits nesting depth to configurable level (default: 1)"
    it "switches to IDs at depth limit with comment"
  end

  describe "polymorphic associations" do
    it "emits actual _type and _id columns with correct types"
    it "uses z.string() for _type column"
    it "infers _id type from column definition (int vs uuid)"
    it "adds TODO comment noting polymorphic limitation"
  end
end
```

### `spec/integration/full_generation_spec.rb`

```ruby
RSpec.describe "Full schema generation", type: :integration do
  describe "generating from a complete Rails model" do
    it "generates valid TypeScript that compiles without errors"
    it "generates valid Zod that can be imported"
    it "matches expected output for a User model with validations"
    it "matches expected output for a Post model with associations"
  end

  describe "multi-model generation" do
    it "generates all models in a single file"
    it "orders schemas to resolve dependencies"
    it "handles circular dependencies with z.lazy()"
  end

  describe "incremental generation" do
    it "regenerates only changed models when configured"
    it "preserves custom additions in separate file"
  end
end
```

### `spec/integration/rails_integration_spec.rb`

```ruby
RSpec.describe "Rails integration", type: :integration do
  describe "rake zod_rails:generate" do
    it "is available after gem is loaded"
    it "generates schema file to configured path"
    it "outputs success message with file path"
    it "outputs model count in success message"
  end

  describe "rake zod_rails:watch" do
    it "requires listen gem to be available"
    it "outputs helpful error if listen not installed"
    it "watches configured model paths"
    it "regenerates on .rb file changes"
    it "can be stopped with Ctrl+C"
  end

  describe "Rails initializer" do
    it "loads configuration from config/initializers/zod_rails.rb"
    it "provides helpful error for invalid configuration"
  end
end
```

---

## 7. Example Generated Output

### Input: Rails Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  enum role: { member: 0, admin: 1, moderator: 2 }
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :age, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  has_many :posts
  belongs_to :organization, optional: true
end
```

### Output: Zod Schema

```typescript
// app/javascript/schemas/zod_schemas.ts
// Generated by ZodRails - DO NOT EDIT
// Generated at: 2025-01-13T12:00:00Z
// Zod version: ^4.0.0

import { z } from "zod";

// ============================================
// User model schemas
// ============================================

/** User response schema (database shape) */
export const UserSchema = z.object({
  id: z.int(),
  email: z.email(),
  name: z.string(),
  age: z.int().gte(0).nullable(),
  role: z.enum(["member", "admin", "moderator"] as const),
  organization_id: z.int().nullable(),
  created_at: z.iso.datetime(),
  updated_at: z.iso.datetime(),
});

export type User = z.infer<typeof UserSchema>;

/** User input schema (form submission) */
export const UserInputSchema = z.object({
  email: z.email().min(1),
  name: z.string().min(2).max(100),
  age: z.int().gte(0).nullish(),
  role: z.enum(["member", "admin", "moderator"] as const).optional(),
  organization_id: z.int().nullish(),
});

export type UserInput = z.infer<typeof UserInputSchema>;
```

**Key differences between schemas:**
- `UserSchema` (Response): Matches DB shape, all fields present, uses `.nullable()` for NULL columns
- `UserInputSchema` (Input): Omits `id`/timestamps, uses `.nullish()` for optional fields, applies validation chains

---

## 8. Configuration DSL

```ruby
# config/initializers/zod_rails.rb
ZodRails.configure do |config|
  # Output path (relative to Rails.root)
  config.output_path = "app/javascript/schemas/zod_schemas.ts"
  
  # Model selection
  config.only = %w[User Post Comment]  # nil = all models
  config.except = %w[ActiveStorage::Blob]
  
  # Schema generation modes
  config.generate_input_schemas = true  # Generate ModelInputSchema alongside ModelSchema
  
  # Association handling
  config.associations = :columns_only  # :columns_only | :include_ids | :nested | :omit
  # :columns_only = Only belongs_to foreign keys (actual columns)
  # :include_ids = Add virtual _ids arrays for has_many (opt-in)
  # :nested = Reference other schemas directly
  # :omit = Exclude all association fields
  
  config.nesting_depth = 1  # Max depth for :nested mode before switching to IDs
  
  # Property naming (IMPORTANT: must match your API serializer)
  config.property_case = :snake  # :snake | :camel
  # WARNING: Rails APIs default to snake_case. Only use :camel if your 
  # serializer transforms keys (e.g., ActiveModelSerializers key_transform)
  
  # Enum format (string keys = modern Rails convention)
  config.enum_format = :string  # :string | :integer
  
  # Timestamp handling
  config.include_timestamps = true  # true | false
  
  # Primary key handling
  config.include_primary_key = true  # true | false
  
  # Date/time format
  config.datetime_format = :iso_string  # :iso_string | :date_object
  # :iso_string = z.iso.datetime() - keeps as string (recommended)
  # :date_object = z.coerce.date() - parses to Date object
  
  # BigInt handling
  config.bigint_format = :string  # :string | :number
  # :string = Safe for all values (recommended)
  # :number = z.int() - DANGER: overflows beyond Number.MAX_SAFE_INTEGER
  
  # Custom type mappings (advanced)
  config.type_mappings[:money] = "z.string()"  # Or with chain: "z.string().regex(/^\\d+\\.\\d{2}$/)"
  
  # Paths to watch (for file watcher)
  config.watch_paths = ["app/models"]
end
```

---

## 9. Implementation Order

After prose specs are written and approved:

### Phase 1: Foundation
1. `version.rb` - Version constant
2. `configuration.rb` - Configuration DSL (all options)
3. Gem structure and gemspec

### Phase 2: Introspection
4. `ModelInspector` - Read columns, validators, enums from AR models
5. `ColumnInfo` - Value object for column metadata
6. `ValidationInfo` - Value object for validation metadata (including allow_nil/allow_blank)

### Phase 3: Associations (BEFORE Generation)
7. `AssociationResolver` - Determines how to represent associations
8. `NestingStrategy` - Columns-only vs nested, depth limits

### Phase 4: Mapping
9. `TypeMapper` - Rails type → Zod type
10. `ValidationMapper` - Rails validation → Zod chain (with deduplication)
11. `EnumMapper` - Rails enum → z.enum() with `as const`

### Phase 5: Generation
12. `SchemaBuilder` - Builds both Response and Input schemas per model
13. `DependencyResolver` - Topological sort for schema ordering
14. `TypescriptEmitter` - Formats TypeScript output
15. `FileWriter` - Writes the .ts file

### Phase 6: Rails Integration
16. `Railtie` - Rails integration with eager loading
17. Rake tasks (`generate`, `watch`)

### Phase 7: Polish
18. Error messages and edge cases
19. Documentation (README)
20. File watcher (optional `listen` integration)

---

## 10. Open Questions

These questions should be answered before implementation begins:

### Property Naming Default ✅ RESOLVED
- **Decision**: `snake_case` by default
- **Rationale**: Rails APIs send snake_case unless serializer transforms keys. Mismatched keys cause immediate validation failures.
- **Config**: `property_case: :camel` for apps with key transformation

### Timestamps ✅ RESOLVED
- **Decision**: Include by default, opt-out via config
- **Rationale**: Response schemas need them; Input schemas auto-exclude them

### ID Fields ✅ RESOLVED  
- **Decision**: Include by default, opt-out via config
- **Rationale**: Response schemas need them; Input schemas auto-exclude them

### Dual Schema Generation ✅ RESOLVED
- **Decision**: Generate both `ModelSchema` (response) and `ModelInputSchema` (forms) by default
- **Rationale**: Solves Input vs Output conflation; `generate_input_schemas: false` to disable

### Association IDs ✅ RESOLVED
- **Decision**: `has_one`/`has_many` do NOT generate `_id`/`_ids` fields by default
- **Rationale**: These are virtual attributes, not columns. Only `belongs_to` FK columns exist on the model.
- **Config**: `associations: :include_ids` to opt-in to virtual `_ids` arrays

---

## 11. Research Findings

### Zod 4 Considerations

> **Target Version**: Zod 4.x (stable since May 2025, current v4.3.5)

#### Key Zod 4 Features We Leverage

| Feature | Usage in ZodRails |
|---------|-------------------|
| `z.int()`, `z.int32()` | Replace `z.number().int()` for integer columns |
| `z.email()`, `z.uuid()`, `z.url()` | Top-level formats instead of deprecated `.email()` methods |
| `z.iso.date()`, `z.iso.datetime()` | Default for date/time columns (keeps as ISO string) |
| Object getter syntax | Replace `z.lazy()` for circular/recursive associations |
| `.meta()` | Embed Rails metadata (column info, primary key, etc.) |
| `z.json()` | Native Zod 4 type for json/jsonb columns |
| Refinements inside schemas | `.refine()` chains with `.min()` etc. without ZodEffects wrapper |

#### Deprecations to Avoid

| Deprecated | Use Instead |
|------------|-------------|
| `z.string().email()` | `z.email()` |
| `z.string().uuid()` | `z.uuid()` |
| `z.object().merge()` | `.extend()` or spread syntax |
| `z.nativeEnum()` | `z.enum()` |
| `z.lazy()` for objects | Getter syntax: `get field() { return Schema }` |

#### Recursive Schema Pattern (Zod 4)

```typescript
// Old (Zod 3) - avoid
const Category = z.lazy(() => z.object({
  subcategories: z.array(Category)
}));

// New (Zod 4) - preferred
const Category = z.object({
  name: z.string(),
  get subcategories() {
    return z.array(Category)
  }
});
```

### Competitive Landscape

| Existing Solution | Approach | Limitation |
|-------------------|----------|------------|
| `schema2type` | Parse `db/schema.rb` | Archived (2023), no validations |
| `camille` | Custom DSL | Not AR-aware, manual type definition |
| `easy_talk` | Ruby DSL → JSON Schema | Not AR-aware |
| `active_json_schema` | AR → JSON Schema | No Zod output, minimal adoption |
| `json-schema-to-zod` | npm converter | Two-step process, fidelity loss |

**Conclusion**: No direct Rails → Zod solution exists. Clear market opportunity.

### File Watcher Research

| Option | Stars | Status | Best For |
|--------|-------|--------|----------|
| `listen` | 1.9k | Active (Jan 2026) | Our use case |
| `guard` | 6.7k | Active | Complex multi-task workflows |
| `filewatcher` | 463 | Active | Zero-dependency environments |

**Decision**: Use `listen` as optional dependency. Most Rails apps already have it.

---

## 12. Known Challenges & Mitigations

| Challenge | Mitigation |
|-----------|------------|
| **Input vs Output conflation** | Generate both `ModelSchema` (response) and `ModelInputSchema` (forms) |
| **Optional vs Nullable confusion** | Use `.nullable()` for DB NULL, `.optional()` for missing keys, `.nullish()` for both |
| **Association IDs don't exist** | `has_one`/`has_many` don't create columns; only emit `belongs_to` FKs by default |
| **snake_case vs camelCase** | Default to `snake_case` matching Rails; camelCase opt-in with warning |
| **BigInt overflow** | Default to `z.string()` for `:bigint`; `z.int()` opt-in with warning |
| **Decimal precision loss** | Default to `z.string()`; `z.number()` opt-in |
| **json/jsonb type** | Use `z.json()` (Zod 4 native) not `z.record()` |
| **Ruby → JS regex** | Whitelist common patterns; emit TODO for complex regexes |
| **Validation deduplication** | `ValidationMapper` consolidates to strictest constraint |
| **Circular associations** | Getter syntax (Zod 4); topological sort for ordering |
| **Conditional validations** | Skip `:if/:unless/:on`; document in comments |
| **Dynamic inclusions** | Skip proc/lambda `:in`; allow config override |
| **STI discriminators** | Generate `z.literal("ChildClass")` for type column |
| **Polymorphic associations** | Emit actual `_type`/`_id` columns with correct types |
| **Abstract models** | Filter with `table_exists? && !abstract_class?` |
| **Namespaced models** | Flatten `Admin::User` → `AdminUserSchema` |
| **Presence on booleans** | Emit warning; map to `z.literal(true)` |
| **Enum type inference** | Use `as const` assertion for literal types |
| **Forward references** | Topological sort + getter syntax for cycles |

---

### Implementation Strategy

```ruby
# lib/tasks/zod_rails.rake
namespace :zod_rails do
  desc "Watch for model changes and regenerate TypeScript"
  task :watch => :environment do
    begin
      require 'listen'
    rescue LoadError
      abort <<~ERROR
        The 'listen' gem is required for file watching.
        Add to your Gemfile:
          gem 'listen', group: :development
        Then run: bundle install
      ERROR
    end

    paths = ZodRails.configuration.watch_paths
    
    puts "Watching #{paths.join(', ')} for changes..."
    puts "Press Ctrl+C to stop"
    
    listener = Listen.to(*paths, only: /\.rb$/) do |modified, added, removed|
      puts "\n[#{Time.now.strftime('%H:%M:%S')}] Change detected"
      Rake::Task['zod_rails:generate'].reenable
      Rake::Task['zod_rails:generate'].invoke
    end
    
    listener.start
    sleep
  rescue Interrupt
    puts "\nStopping watcher..."
  end
end
```

---

## Next Steps

1. **Answer open questions** (property naming, timestamps, IDs)
2. **Create ROADMAP.md** with completed/future sections
3. **Scaffold gem structure** with Bundler
4. **Write all prose specs** as pending RSpec examples
5. **Review specs** for completeness
6. **Begin implementation** by making specs pass one by one

---

*This document serves as the single source of truth for the ZodRails gem architecture. Update it as decisions are made and implementation progresses.*
# ZodRails Roadmap

> **Last Updated**: 2025-01-13

---

## Completed

*Nothing yet - project in planning phase*

---

## v1.0 Scope (In Progress)

### Core Features
- [ ] Column type → Zod type mapping (all common types)
- [ ] Nullability inference from column definition
- [ ] Validation mapping (Tier 1 + Tier 2)
- [ ] Rails enum support (string keys)
- [ ] Rake task: `rails zod_rails:generate`
- [ ] Configuration file (initializer DSL)
- [ ] Customizable output path
- [ ] Per-model include/exclude options

### Association Handling
- [ ] Foreign key fields for `belongs_to`
- [ ] ID arrays for `has_many`
- [ ] Configurable: IDs-only vs nested schemas
- [ ] Optional association support

### Developer Experience
- [ ] File watcher: `rails zod_rails:watch` (requires `listen` gem)
- [ ] Clear error messages for configuration issues
- [ ] Generation timestamp in output
- [ ] "Do not edit" warning in generated files

### Documentation
- [ ] README with quick start guide
- [ ] Configuration reference
- [ ] Type mapping reference
- [ ] Validation mapping reference

### Quality
- [ ] Comprehensive RSpec test suite (prose-driven TDD)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] RuboCop configuration

---

## v1.1 (Post-Release Polish)

- [ ] Custom type mapping extension point
- [ ] Per-model configuration overrides
- [ ] Multiple output file support (split by namespace)
- [ ] Better regex conversion (Ruby → JavaScript)
- [ ] Common email/URL format detection

---

## v2.0 (Future)

### Serializer Integration
- [ ] Alba adapter - generate from Alba serializers
- [ ] Blueprinter adapter - generate from Blueprinter views
- [ ] ActiveModelSerializers adapter
- [ ] Custom serializer extension point

### Advanced Features
- [ ] Polymorphic association support
- [ ] STI (Single Table Inheritance) handling
- [ ] Conditional validation mapping (Tier 3)
- [ ] Custom validator extension API
- [ ] Schema versioning support

### Performance
- [ ] Incremental generation (only changed models)
- [ ] Parallel model introspection
- [ ] Caching layer for large codebases

### Ecosystem
- [ ] VS Code extension for jump-to-definition
- [ ] Integration with TypeScript Language Server
- [ ] Rails generator: `rails g zod_rails:install`

---

## v3.0 (Vision)

### Bidirectional Sync
- [ ] Detect drift between Rails and generated schemas
- [ ] Generate Rails migrations from Zod schema changes
- [ ] Schema diff tool

### API Documentation
- [ ] OpenAPI spec generation alongside Zod
- [ ] Swagger UI integration
- [ ] API versioning support

### Runtime Features
- [ ] Runtime API endpoint serving schema JSON
- [ ] Schema hot-reloading in development
- [ ] Client library generation (fetch/axios wrappers)

---

## Ideas Backlog

*Unscheduled ideas for future consideration*

- GraphQL type generation
- Prisma schema generation
- Database-level constraint extraction (beyond AR validations)
- Multi-database support
- Encrypted attribute handling
- Action Text rich text field support
- Active Storage attachment field support
- I18n support for validation messages
- JSON Schema output (alternative to Zod)
- Yup schema output (alternative to Zod)

---

## Contributing

Have an idea? Open an issue or PR! We especially welcome:

1. New type mappings for database-specific types
2. Validation mapping improvements
3. Serializer adapter implementations
4. Documentation improvements

---

*This roadmap is a living document. Priorities may shift based on community feedback.*
