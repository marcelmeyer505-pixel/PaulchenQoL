# Changelog

## 0.8.0 — 2026-11-20

- Added Paulchen's Buff Watcher, integrated into the main window with player, party and scrollable raid views.
- Check Wild/ Fortitude/Intellect/Spirit/Shadow Protection and Paladin blessing families, including ranks and single/group variants. Discover additional learned Forever ranks through the modern spellbook where available.
- Keep PRESENT, MISSING and UNKNOWN separate. Unreadable or restricted aura data, dead/offline members and out-of-range players never become missing-buff claims.
- Added configurable families, class-specific requirements and blessing variants. Optional Spirit and Shadow Protection start disabled; unknown remote talents remain unknown.
- Added coalesced post-cast reports after the player's successful Wild spells, with a one-second settling delay, at least 60 seconds between automatic messages, persistent deduplication/cooldown and no automatic solo or default raid reports.
- Respect chat restrictions and synchronous security denials; provide a local copyable report for manual use.
- Added local personality comments using existing dialogue priorities/cooldowns and reused the existing personal Wild reminder without duplicate warnings.
- Added `/pq buffs`, `check`, `say` and `debug`, settings, targeted/debounced aura updates and repeatable Lua 5.1 regression tests.
- No CurseForge/GitHub publication is performed by this change.

## 0.7.7

- Added colored inventory mark categories, subtle row highlights and destination reveal while preserving grouped stacks and physical item-button identities.

## 0.7.6

- Skip known locked-content candidates before item-data requests and scoring, retaining owned/listed items and verified open alternatives.
- Replaced unsupported arrow glyphs in upgrade controls with native UI textures.

## 0.7.5

- Added per-character content-release controls and locked-source filtering for raid, faction and related quest rewards.
