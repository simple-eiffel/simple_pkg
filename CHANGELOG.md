# Changelog

## [Unreleased] - 2026-10-08

### Fixed
- `PKG_REGISTRY` reads curl's response from `last_output_bytes` and UTF-8 encodes the process error, instead of `to_string_8` of decoded text (simple_process 1.1.0).

