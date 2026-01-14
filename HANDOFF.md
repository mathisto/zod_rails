# ZodRails Implementation Handoff

> **Status**: Planning complete. Ready for implementation.
> **Full Plan**: `ZOD_RAILS.md` (1000+ lines of architectural detail)
> **Project Config**: `AGENTS.md`

---

## What We're Building

A Ruby gem that introspects ActiveRecord models and generates Zod 4 TypeScript schemas.

```
Rails Model → ZodRails → TypeScript file with Zod schemas
```

**Output example:**
```typescript
// Response schema (what API returns)
export const UserSchema = z.object({
  id: z.int(),
  email: z.email(),
  name: z.string(),
  role: z.enum(["member", "admin"] as const),
  organization_id: z.int().nullable(),
  created_at: z.iso.datetime(),
  updated_at: z.iso.datetime(),
});

// Input schema (what forms submit)
export const UserInputSchema = z.object({
  email: z.email().min(1),
  name: z.string().min(2).max(100),
  role: z.enum(["member", "admin"] as const).optional(),
  organization_id: z.int().nullish(),
});
```

---

## Critical Decisions (Non-Negotiable)

| Decision | Rationale |
|----------|-----------|
| **Dual schemas** | `ModelSchema` (response) + `ModelInputSchema` (forms) - solves input/output conflation |
| **snake_case default** | Rails APIs send snake_case. Mismatch = immediate validation failure |
| **belongs_to FKs only** | `has_one`/`has_many` don't create columns. Only emit actual FK columns |
| **z.string() for bigint** | Avoids JS Number.MAX_SAFE_INTEGER overflow |
| **z.string() for decimal** | Preserves precision (money, etc.) |
| **z.json() for jsonb** | Zod 4 native type, accepts any JSON value |
| **z.iso.datetime()** | Keeps dates as ISO strings (most common API pattern) |
| **Getter syntax for cycles** | Zod 4 pattern for circular refs, not z.lazy() |
| **Topological sort** | Prevents undefined reference errors in generated TS |

---

## Implementation Phases

### Phase 1: Foundation
```
lib/zod_rails/
├── version.rb
└── configuration.rb
```
- Version constant
- Full configuration DSL (see ZOD_RAILS.md section 8)
- Gemspec with dependencies

### Phase 2: Introspection
```
lib/zod_rails/introspection/
├── model_inspector.rb
├── column_info.rb
└── validation_info.rb
```
- Read columns, validators, enums from AR models
- Filter abstract models (`table_exists? && !abstract_class?`)
- Extract `allow_nil`/`allow_blank` from validators
- Skip conditional validations (`:if/:unless`)

### Phase 3: Associations (BEFORE Generation)
```
lib/zod_rails/associations/
├── association_resolver.rb
└── nesting_strategy.rb
```
- `belongs_to` → emit FK column
- `has_one`/`has_many` → skip by default (opt-in via config)
- Polymorphic → emit actual `_type` + `_id` columns
- Detect circular refs for getter syntax

### Phase 4: Mapping
```
lib/zod_rails/mapping/
├── type_mapper.rb
├── validation_mapper.rb
└── enum_mapper.rb
```
- Rails type → Zod type (see type tables in ZOD_RAILS.md)
- Validation deduplication (take strictest constraint)
- Enum with `as const` for type inference

### Phase 5: Generation
```
lib/zod_rails/generation/
├── schema_builder.rb
├── dependency_resolver.rb
├── typescript_emitter.rb
└── file_writer.rb
```
- Build both Response + Input schemas per model
- Topological sort for dependency ordering
- Format TypeScript output
- Write `.ts` file

### Phase 6: Rails Integration
```
lib/zod_rails/
├── railtie.rb
└── tasks/
    └── zod_rails.rake
```
- Eager load Rails app before introspection
- `rails zod_rails:generate` task
- `rails zod_rails:watch` task (optional `listen`)

---

## Type Mapping Reference

| Rails | Zod 4 |
|-------|-------|
| `:string`, `:text` | `z.string()` |
| `:integer` | `z.int()` |
| `:bigint` | `z.string()` |
| `:float` | `z.number()` |
| `:decimal` | `z.string()` |
| `:boolean` | `z.boolean()` |
| `:date` | `z.iso.date()` |
| `:datetime` | `z.iso.datetime()` |
| `:json`, `:jsonb` | `z.json()` |
| `:uuid` | `z.uuid()` |

---

## Nullability Rules

| Condition | Response Schema | Input Schema |
|-----------|-----------------|--------------|
| `null: false` in DB | Required | Required |
| `null: true` in DB | `.nullable()` | `.nullish()` |
| `validates :presence` | Removes `.nullable()` | `.min(1)` for strings |
| `allow_nil: true` | Preserves `.nullable()` | `.nullable()` |
| DB default exists | Required | `.optional()` |

---

## Validation Mapping Reference

| Rails | Zod |
|-------|-----|
| `presence: true` | Removes nullable, `.min(1)` for strings |
| `length: { minimum: N }` | `.min(N)` |
| `length: { maximum: N }` | `.max(N)` |
| `inclusion: { in: [...] }` | `z.enum([...] as const)` |
| `numericality: { gt: N }` | `.gt(N)` |
| `numericality: { odd: true }` | `.refine(v => v % 2 === 1)` |
| `format: { with: /.../ }` | `.regex(/.../)` or whitelist |

---

## Development Approach

**Prose-Driven TDD**: Write `it` statements as pending specs first, then implement.

```ruby
# Step 1: Write behavior
it "maps :string to z.string()"
it "maps :integer to z.int()"

# Step 2: Implement to pass
it "maps :string to z.string()" do
  expect(mapper.call(:string)).to eq("z.string()")
end
```

---

## File Structure

```
zod_rails/
├── lib/
│   └── zod_rails/
│       ├── version.rb
│       ├── configuration.rb
│       ├── introspection/
│       ├── associations/
│       ├── mapping/
│       ├── generation/
│       ├── railtie.rb
│       └── tasks/
├── spec/
│   └── zod_rails/
│       ├── introspection/
│       ├── associations/
│       ├── mapping/
│       ├── generation/
│       └── integration/
├── zod_rails.gemspec
├── Gemfile
├── Rakefile
├── ZOD_RAILS.md
├── AGENTS.md
└── README.md
```

---

## First Steps

1. **Scaffold gem**: `bundle gem zod_rails`
2. **Write prose specs**: Start with `spec/zod_rails/mapping/type_mapper_spec.rb`
3. **Implement Phase 1**: version.rb, configuration.rb
4. **Iterate**: Spec → Implement → Verify

---

## Commands

```bash
bundle exec rspec                           # Run all specs
bundle exec rspec spec/zod_rails/mapping/   # Run mapping specs
bundle exec rspec --format documentation    # Verbose output
bundle exec rake build                      # Build gem
bundle exec rake install                    # Install locally
```

---

## Key Files

| File | Purpose |
|------|---------|
| `ZOD_RAILS.md` | Full architectural plan (1000+ lines) |
| `AGENTS.md` | Project config for AI assistants |
| `HANDOFF.md` | This file - implementation quick reference |

---

## Warnings

1. **Never use deprecated Zod patterns**: `z.string().email()` → use `z.email()`
2. **Never generate fake columns**: `has_many` doesn't create `_ids` column
3. **Never default to camelCase**: Rails APIs are snake_case
4. **Never use z.lazy() for objects**: Use getter syntax in Zod 4
5. **Never forget topological sort**: Forward references break TS compilation
