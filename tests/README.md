# Regression tests

Run `python tests/test_comfort.py` to verify opt-in sales, item marks and variants, stale merchant visits, and quest flow with protected or ambiguous data.

Run `python tests/test_world_map.py` to check the map options, native marker deduplication, quest turn-ins, map navigation, exploration overlays, and road crossing detection with Lua client fixtures.

Run `python -m pip install lupa`, then `python tests/test_buff_watcher.py` from the repository. Lua 5.1 compiles and runs the addon code against `buff_watcher_fixture.lua`. No real game client, account, network, spell cast or chat send is used.

See `../BUFFWATCHER_TESTS.md` for the executed cases, API references and remaining client checks. This directory is source-only and is not shipped in the installation archive.

`python tests/test_auction_cells.py` checks the mandatory Auction House TableBuilder cell callbacks with strict Lua tables, repeated six-cell row hover dispatch, both value columns, formatting/colors and pooled-cell reuse. The fix was also verified in the development workspace against Blizzard's [Forever TableBuilder implementation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXML/TableBuilder.lua): the prior addon code reproduces a missing `OnLineEnter` error, while the fixed code passes 1,000 native row enter/leave cycles. Blizzard source is not vendored or included in the addon ZIP.
