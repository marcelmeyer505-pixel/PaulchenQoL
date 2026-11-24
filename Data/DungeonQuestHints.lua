local _, app = ...
-- Explicit, source-tagged CLASSIC reference points, used only when the bundled
-- Forever quest database has no exact location. Not verified in Forever.
-- These are individual public map-coordinate facts, not a copied database.
app.dungeonQuestLocationHints = {
    ["npc:16033"] = {
        map = 1428, x = 0.323, y = 0.258, referenceOnly = true,
        source = "https://foreverdb.net/de/quest/8960-bodleys-unfortunate-fate",
        -- Bodley, Blackrock Mountain (Burning Steppes map): Classic 32.3,25.8.
        -- This point is not a confirmed Forever sighting.
    },
}
