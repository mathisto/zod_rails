# Changelog

All notable changes to ZodRails are documented here.

## Unreleased

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
