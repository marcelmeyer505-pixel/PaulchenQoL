# Changelog

## 0.13.0 — 2026-11-24

- Add world map controls for coordinates, zones, and exploration, plus markers for flight points, portals, crossings, dungeon entrances, and ready quest turn-ins. The map tools run without Leatrix.
- Open Paulchen's instance map with the regular world map key inside supported dungeons. Pan and zoom the map, follow the route, select bosses to inspect loot, and sort drops by upgrade percentage.
- Add an opt-in Comfort section for selling gray items while respecting bag markings, automating quest dialogs, and managing travel and map settings.
- Show eligible group loot rolls in one window with Need, Greed, and Pass, plus upgrade alerts and group results. Advance to the next undecided item after a roll and keep the final result visible for ten seconds.
- Include supported equipment set bonuses in gear comparisons and flag set effects the active profile cannot score.
- Improve tab and farm-round layout in the compact Logbook.

### Instance quests

- Bundle the historical MIT-licensed Dungeon Quest Atlas v1.04 reference dataset (35 dungeon entries, 395 quest associations, 480 quest records and 309 locations), with its original license and attribution.
- The quest planner now works without Polestar or Dungeon Quest Atlas installed. Native WoW waypoints replace the Polestar navigation dependency.
- Add searchable dungeon and quest lists, known quest giver/turn-in locations, chain progress, faction filters, completion states and copyable reports.
- Explicitly label incomplete/unknown Forever content; add Lua 5.1 regression tests against the real bundled dataset.
- Distinguish in-dungeon NPCs, starting items and genuinely missing questgivers rather than displaying blank coordinates.
- Automatically remember questgiver/turn-in NPC locations from actual in-game quest dialogs, saved per character; add a visibly unconfirmed Classic Bodley point as fallback.

## 0.12.0 — 2026-11-23

- Add German and English for the interface and Paulchen’s dialogue. Follow the game client language or choose a language in settings.
- Rework Paulchen's personality around shared dialogue pools, remembered situations and recent lines. Remove sarcasm levels while retaining the existing German dialogue and art.
- Add spontaneous chatter for travel, resting areas and quiet time, plus confirmed loot, group, encounter and bank reactions.
- Add separate chatter, situational comment, repair and opt-in break settings. Preserve played time and reminder thresholds across UI reloads.

## 0.11.3 — 2026-11-22

- Add an opt-in PvP vendor setting under Game Content and a dedicated upgrade source filter for recognized Honor and battleground sellers.

## 0.11.2 — 2026-11-22

- Add an Undermine Real source filter for upgrade items sold by Pix Xizzix.

## 0.11.1 — 2026-11-22

- Show TSM DBMinBuyout in the upgrade window as a `[PREIS]` estimate. Saved buyout offers and live auction results remain available. The tooltip can show both the actual offer and the TSM estimate.

## 0.11.0 — 2026-11-22

- Add sortable vendor, market and percentage difference columns to Paulchen's bag and personal bank lists. The market tooltip shows the source, unit price, stack value and scan time when available.
- Use TradeSkillMaster DBMarket through its optional public addon API. Fall back to matching buyout offers recorded by Paulchen's auction scanner.
- Choose a price source and check its status under Bag / Prices. Cache prices by item variant and share the cache between bags and bank.

## 0.10.3 — 2026-11-22

- Drag a whole category between the bag and personal bank lists. The receiving pane highlights as a drop target and uses the same transfer rules as the deposit and withdraw buttons.

## 0.10.2 — 2026-11-22

- Show the personal bank and bag lists side by side at the banker. Move the panes together, fit them to the screen and restore the regular bag position after closing the bank.

## 0.10.1 — 2026-11-22

- Withdraw an entire category from the personal bank into your bags. Fill compatible stacks first and report how many items moved or stayed in the bank.

## 0.10.0 — 2026-11-22

- Add a personal bank list with the same category names, colors, ordering, grouped stacks, search and sorting as the bag list.
- Deposit a whole bag category into the personal bank while it is open. Merge compatible stacks first and report how many items moved or stayed in the bags.

## 0.9.2 — 2026-11-21

- Drag custom categories into a new order in the bag category editor. The bag list and right-click menu follow the saved order.

## 0.9.1 — 2026-11-21

- Delete custom bag categories from the category editor. Items assigned to a deleted category return to their automatic bag categories.

## 0.9.0 — 2026-11-21

- Create custom bag categories and edit the names and colors of existing marks. The editor supports the color picker and hex values, and the right-click list pages through larger sets of categories.

## 0.8.7 — 2026-11-21

- Rename the Cat and Bear bag marks to DPS Gear and Tank Gear. Existing marks and collapsed categories carry over.

## 0.8.6 — 2026-11-21

- Fix the Forever ScrollBox error when assigning or clearing a mark from a bag row. The bag's own menu closes before the item moves to its new category.

## 0.8.5 — 2026-11-21

- Use addon-owned controls for optional upgrade columns and long filter lists to avoid the Forever ScrollBox error when a scrollable menu closes.

## 0.8.4 — 2026-11-21

- Run upgrade searches on login, UI reload, or a click on Refresh. Loot, equipment changes, profile changes and instance transitions no longer launch background searches.
- Keep the last completed results visible and mark them as out of date when search inputs change. An already requested search can resume after combat.

## 0.8.3 — 2026-11-20

- Resume in-progress upgrade searches after combat from the same position, with their remaining item-data wait budget.
- Bundle automatic upgrade refreshes until leaving a dungeon or raid. The last results stay available and the Refresh button can start a search inside an instance.

## 0.8.2 — 2026-11-20

- Refresh Upgrade % and Gold per % sorting when the Auction House updates existing result rows. Handle unavailable row and price data safely.
- Preserve the last readable Auction House search when a result is temporarily unavailable or protected.
- Keep readable buffs visible during chat-only restrictions. Reserve the persistent personal Wild reminder for druids and suppress automatic reports when there are no buff requirements.
- Resolve portrait and live critical-hit font paths with the installed addon folder's spelling.

## 0.8.1 — 2026-11-20

- Fixed repeated Auction House row-hover errors in Blizzard's TableBuilder. The Upgrade % and Gold per % cells now implement both mandatory row-hover callbacks, including when the addon loads before the shared TableBuilder mixin.
- Added regression checks for both value columns, repeated row enter/leave, cell reuse and value/color rendering. Filtering, sorting and comparison calculations are unchanged.

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
