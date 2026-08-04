# Changelog

All notable changes to ZodRails are documented here.

## Unreleased

## 0.3.4 - 2026-08-03

### Upgrade Notes

- Regenerate committed schemas after upgrading if any model uses `validates :attr, format: { with: ... }` on a column
  that is nullable or has a database default. Those schemas contain a silently corrupted `new RegExp(...)` pattern.

### Fixed

- Preserve backslash escaping in generated `new RegExp(...)` patterns. A validation chain was spliced ahead of a
  `.nullable()`, `.nullish()`, or `.optional()` suffix through a `String#sub` replacement string, which expanded the
  chain's backslash sequences: `\\.` collapsed to `\.` and `\\s` to `\s`. The emitted pattern still parsed as valid
  TypeScript but no longer matched the Ruby regexp it came from — most damagingly, the `\z` end anchor degraded from
  `(?![\s\S])` to `(?![sS])`, so `.regex()` began accepting any value with a merely valid prefix. Columns without a
  nullability suffix took a different branch and were unaffected, which is why input schemas were hit far more often
  than response schemas.
- Preserve backslash sequences inside a `ZOD_RAILS:CUSTOM:IMPORTS` block across regeneration. The same
  replacement-string expansion rewrote hand-authored content the writer is meant to carry over untouched.

## 0.3.3 - 2026-08-03

### Changed

- Add the `arm64-darwin-25` Bundler platform so development on macOS 26 does not continually modify `Gemfile.lock`.

## 0.3.2 - 2026-08-03

### Upgrade Notes

- Upgrade from `0.3.0` or `0.3.1` immediately. Those releases omitted the Railtie's Rake task file from the packaged
  gem, causing `Rails.application.load_tasks` and unrelated Rails tasks such as `db:migrate` and `assets:precompile`
  to fail with `LoadError`.

### Fixed

- Include `lib/tasks/zod_rails.rake` in the published gem.
- Verify the runtime manifest and task loading in the test suite.

## 0.3.1 - 2026-08-03

### Upgrade Notes

- Regenerate committed schemas after upgrading if your models contain PostgreSQL arrays, adapter-reported `:bigint`
  columns, or `time` columns. Their generated wire schemas now match Rails payload shapes more closely.

### Fixed

- Generate `z.array(...)` schemas for PostgreSQL array columns, with inclusion constraints on elements and
  presence, length, default, and nullability constraints on the outer array.
- Map adapter-reported `:bigint` columns to the JSON number shape emitted by Rails.
- Validate Rails `time` payloads as ISO datetimes with timezone-offset support.

### Changed

- Run a generated-schema runtime contract against the pinned Zod version in CI.

## 0.3.0 - 2026-08-03

### Upgrade Notes

- Regenerate committed schemas after upgrading. Presence, range, regular-expression, and datetime output has changed
  to more closely match Rails behavior.
- `schema_suffix`, `input_schema_suffix`, and `generate_input_schemas` now take effect. Applications that configured
  these previously ignored options will see the configured output for the first time.
- Configured model names must resolve to concrete ActiveRecord models; nonmodels and abstract models now produce a
  targeted configuration error.

### Fixed

- Honor custom schema suffixes and `generate_input_schemas`.
- Generate safe TypeScript for unusual column names, enum values, and regular expressions.
- Preserve negative, zero, exclusive, beginless, and endless numeric range bounds.
- Match Rails presence semantics for whitespace-only strings and required nullable columns.
- Accept ISO datetimes with timezone offsets and detect database expression defaults.
- Keep preserved custom blocks from causing false drift reports.
- Detect output filename collisions before writing files.

### Changed

- Declare ActiveRecord and Railties as runtime dependencies.
- Reject configured constants that are not concrete ActiveRecord models.
- Skip dynamic numericality constraints and Ruby extended-mode regular expressions instead of emitting invalid TypeScript.

## 0.2.0

- Added response and input schema generation, enums, validation mapping, namespaced models, drift detection,
  custom block preservation, dry runs, and formatter integration.
