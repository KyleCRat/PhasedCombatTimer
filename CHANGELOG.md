# Changelog

## [12.0.7-2] - 2026-07-12

### Fixed
- Fixed NSRT callback argument handling so detected phase changes reset the
  phase timer.
- Prevented fractional phase labels such as `1.5` and `2.5` from being clipped.

## [12.0.7-1] - 2026-07-11

### Added
- Added combat and encounter timing with separate phase timing provided by
  Northern Sky Raid Tools.
- Added default tracking for all combat, with encounter-only and out-of-combat
  visibility options.
- Added configurable out-of-combat opacity.
- Added Edit Mode positioning, appearance controls, and live preview.
- Added `/pct test`, `/pct preview`, and `/pct reset` commands.

### Improved
- Cached display settings and limited text redraws to visible timer changes to
  minimize combat overhead.
- Added validated position restoration and embedded CallbackHandler support.
