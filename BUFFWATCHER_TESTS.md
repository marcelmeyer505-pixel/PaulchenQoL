# Buff Watcher validation — 0.8.0

The Lua 5.1 simulations were actually executed on 2026-11-20. They are not a substitute for a live Forever-client test. No real group messages or spells were sent during development.

## Reproducible source tests

Install Python 3 and `lupa` (the Lua 5.1 variant is used), then run from the repository:

```sh
python -m pip install lupa
python tests/test_buff_watcher.py
```

The test fixture simulates APIs, secret values, timers, synchronous chat blocks and UI widgets. It is independent of Polestar, Details and other addons. Tests and their fixture stay in Git; they are excluded from the install ZIP.

| Required case | Executed simulated evidence |
| --- | --- |
| Solo druid without Wild | MISSING only if learned; existing reminder reused; zero solo messages |
| Two/five-player groups, one/multiple missing buffs | Correct family requirements, names, missing counts and class exclusions |
| Fully buffed party | Complete success report; local ready dialogue event |
| Single-target versus group buffs | Equivalent family ranks; target-only update; unchanged other players |
| Dead, offline, distant or invisible members | UNKNOWN, no false missing states; explicitly incomplete report |
| Secret aura table/ID, rejected aura API, combat/restrictions | No secret dereference, UNKNOWN; readable positive evidence retained |
| Consecutive successful Wild casts | One scan/report one second after final cast; state read after aura changes |
| Failed or another druid's cast | No report |
| Multiple druids and roster changes | Only own druid triggers; pending report canceled on roster change |
| Party ↔ raid | Forty raid entries, scrolling; automatic raid chat off until enabled |
| Auto-chat enabled/disabled | Appropriate sends or silence; solo and disabled watcher stay silent |
| Duplicate reports and cooldown | No resend after cooldown for identical results; changed report still respects minimum interval |
| Reload | Fresh Lua VM retains settings, class requirements, blessing selection and successful-send cooldown |
| Optional/talent requirements | Remote talent knowledge UNKNOWN; explicit class override; blessing-specific own spell availability |
| Forever-specific spell rank | Modern spellbook name discovery recognizes custom learned ID and successful cast |
| Chat restriction/throw/synchronous block | No claimed successful send or fallback retry; manual copy field remains available |
| UI and commands | Main-page content, twelve visible raid rows, tooltips, settings, slash commands and manual-report field |
| Event bursts | Fifty aura events cause one affected-unit read, rather than fifty full-party scans |

Existing QoL, inventory, overview, upgrade/cache/content and timeline regressions are checked separately in the development workspace. Release packaging compiles all shipped Lua under Lua 5.1 and verifies TOC paths/order, ZIP CRC and content bytes.

## Forever API verification

The `forever` UI documentation branch was inspected for API signatures and restriction semantics. Runtime calls are feature-detected and guarded; unsupported or unreadable data degrades to UNKNOWN.

- [C_UnitAuras.GetAuraDataByIndex](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua): unit-aura access and secret data restrictions.
- [C_ChatInfo.SendChatMessage and outgoing restrictions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): restricted chat send signature, feature-detected modern/legacy path.
- [RestrictedActions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua) and [restriction enums](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsConstantsDocumentation.lua): active/activating states and synchronous blocked/forbidden events.

These documents describe the exposed API. They do not establish that every spell/rank, remote aura, or automatic chat call is permitted in a particular live encounter or realm state. The implementation does not work around restrictions, inspect another player's spellbook, create secure-action buttons or infer hidden buffs from combat logs.

## Still required in the actual Forever client

1. Fully restart WoW after installing the new TOC file. Check the Buffs tab and settings at the current UI scale, including compact logbook header and hiding/re-enabling the tab.
2. Solo: remove/reapply learned Wild ranks and Gift; verify one persistent personal reminder and no automatic chat.
3. With consenting group members, test a two-player and five-player party. Compare icons/status against their actual visible auras, class composition, optional families and chosen blessing variants.
4. Enable normal automatic reports, cast Wild/Gift successfully, and verify the post-cast state, settling delay and correct party/instance channel. Check failed casts, multiple rapid casts, a second druid, identical results and a changed result inside/outside the configured interval.
5. Move a member out of range, disconnect/reconnect and test death/ghost/resurrection. Confirm UNKNOWN and an incomplete report, then recovery on aura/range events or targeted visible-page retry.
6. Enter combat or a restricted encounter. Confirm no unverified missing claims and no automatic chat attempts. Try the copyable manual report; do not bypass a client restriction.
7. In a raid, confirm all entries/scrolling and that automatic raid reporting stays off by default. Enable it deliberately only if wanted, then verify correct channel and bounded single-message summaries.
8. Reload while options are changed and while within a chat cooldown. Confirm settings/history persist, automatic spam does not resume, and other Paulchen features still work.
9. Verify current Forever-specific rank names and actual client spellbook results. Remote talent availability may intentionally remain UNKNOWN; use explicit requirements only when the group knows the ability is available.

No live FPS, visual layout, server chat acceptance or real aura restriction behavior has been measured by the simulations. No new third-party dependency or addon license was introduced.
