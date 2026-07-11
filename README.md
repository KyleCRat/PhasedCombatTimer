# Phased Combat Timer

Phased Combat Timer is a World of Warcraft addon that displays an overall
combat timer alongside a timer for the current encounter phase. Encounter
phase changes are provided by Northern Sky Raid Tools.

## Features

- Tracks all player combat by default, including combat outside encounters.
- Starts a dedicated encounter timer when an encounter begins.
- Resets the phase timer when Northern Sky Raid Tools reports a phase change.
- Retains the completed timer values when the frame remains visible after
  combat.
- Can be limited to encounters or hidden while out of combat.
- Supports configurable out-of-combat opacity when the idle frame is visible.
- Uses change-based text updates to avoid unnecessary redraws during combat.

## Edit Mode

Open WoW Edit Mode and select the Phased Combat Timer frame to configure it.
The frame remains visible with a live preview while Edit Mode is active, even
when the addon itself is disabled.

Available controls include:

- Enable state, encounter-only visibility, out-of-combat visibility, and idle
  opacity.
- Labels, tenths display below 60 seconds, font, size, outline, and text colors.
- Background color and per-side padding.
- Timer spacing, scale, and phase timer placement.
- Frame positioning through the standard Edit Mode layout.

Settings and position are stored account-wide.

## Slash Commands

| Command | Description |
|---|---|
| `/pct test` | Toggle the timer preview |
| `/pct preview` | Toggle the timer preview |
| `/pct reset` | Reset appearance and position settings |

`/phasedcombattimer` can be used in place of `/pct`.

## Compatibility

- Supports World of Warcraft 12.0.7.
- Requires Northern Sky Raid Tools for encounter phase detection.
