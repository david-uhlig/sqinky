# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `canonical:` option for `encodes_identifier` and `encodes_identifiers`. Pass `canonical: false` to also accept non-canonical encodings, e.g. those issued before `min_length` was raised or `blocklist` was changed.

### Changed

- Only canonical encodings are accepted by default, so each record has exactly one valid encoding. Non-canonical aliases, including encodings issued before a Sqids option was changed, are rejected unless `canonical: false` is set.
- `encodes_identifier` and `encodes_identifiers` raise `ArgumentError` if a generated method would replace an existing method, e.g. `as: :id` or `as: :to_param`, or another encoding's method in the same class. Redeclaring an encoding inherited from a parent class is still allowed.

### Fixed

- The non-bang encoding method (e.g. `id_encoding`) raises `ArgumentError` for non-Integer attribute values instead of returning a misleading encoding. Previously `1.5` encoded to the same identifier as `1`, and `"abc"` to the identifier of `0`. Blank values still return `nil`.
- Reject invalid encodings before querying the database. `nil`, empty, non-String, foreign-character, and wrong-arity encodings no longer decode into `nil` conditions that could find, destroy, or delete unrelated records: `find_by_*` returns `nil`, `find_by_*!` raises `ActiveRecord::RecordNotFound`, `destroy_by_*` returns `[]`, `delete_by_*` returns `0`, and the `decodes_as` helper returns `nil`.
- Reject encodings that decode to a value above `Sqids.max_value`. Long crafted input made `find_by_*`, `find_by_*!`, `destroy_by_*`, `delete_by_*`, and the `decodes_as` helper raise `ArgumentError` instead of treating the encoding as invalid. With `canonical: false` such values now also count as invalid instead of reaching the query.
- Reject encodings longer than the longest valid encoding before decoding them. Decoding time grows quadratically with the input length, so a crafted 100,000-character encoding took about 1.5 seconds to reject. With `canonical: false`, encodings of up to 255 characters, the largest Sqids `min_length`, are still decoded.
- Require the Active Support core extensions the library uses (`compact_blank!`, `presence`, `blank?`), so it no longer depends on Rails having loaded them.

## [0.1.0] - 2026-03-06

- Initial release

[unreleased]: https://github.com/david-uhlig/sqinky/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/david-uhlig/sqinky/releases/tag/v0.1.0
