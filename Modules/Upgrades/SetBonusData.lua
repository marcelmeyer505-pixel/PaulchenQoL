-- Numeric set membership, bonus thresholds and flat stats from Forever DB2 build 1.60.1.71037.
-- Tables: ItemSet, ItemSetSpell, SpellEffect. Includes sets referenced by the item catalog.
-- A threshold marked unknown also has an effect that cannot be expressed as flat profile stats.
local _, suite = ...
local app = suite.upgrades
if not app then return end

app.setBonusData = {
    [1] = { items = { 11729, 11726, 11728, 11731, 11730, 277117 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { ap = 20, rap = 20 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [41] = { items = { 12940, 12939 }, bonuses = {
        [2] = { stats = { ap = 50, rap = 50 } },
    } },
    [65] = { items = { 13218, 13183 }, bonuses = {
        [2] = { unknown = true },
    } },
    [81] = { items = { 13390, 13388, 13391, 13392, 13389 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [5] = { stats = { hit = 1, spellHit = 1 } },
    } },
    [121] = { items = { 14637, 14636, 14640, 14638, 14641 }, bonuses = {
        [3] = { stats = { ap = 10, rap = 10 }, unknown = true },
        [4] = { unknown = true },
        [5] = { stats = { hit = 2, spellHit = 2 } },
    } },
    [122] = { items = { 14631, 14629, 14632, 14633, 14626 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { stats = { heal = 23, sp = 23 } },
    } },
    [123] = { items = { 14614, 14616, 14615, 14611, 14612 }, bonuses = {
        [2] = { stats = { ap = 10, rap = 10 } },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [124] = { items = { 14624, 14622, 14620, 14623, 14621 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [141] = { items = { 15053, 15054, 15055 }, bonuses = {
        [3] = { unknown = true },
    } },
    [142] = { items = { 15056, 15057, 15058, 21278 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { stats = { ap = 14, rap = 14 } },
    } },
    [143] = { items = { 15062, 15063 }, bonuses = {
        [2] = { stats = { hit = 2, spellHit = 2 } },
    } },
    [144] = { items = { 15066, 15067 }, bonuses = {
        [2] = { stats = { heal = 20, sp = 20 } },
    } },
    [161] = { items = { 10399, 10403, 10402, 10401, 10400 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [162] = { items = { 10412, 10411, 10413, 10410, 6473 }, bonuses = {
        [2] = { stats = { int = 10 } },
        [3] = { stats = { ap = 10, rap = 10 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [163] = { items = { 10329, 10332, 10328, 10331, 10330, 10333 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { stats = { hit = 1, spellHit = 1 } },
        [6] = { unknown = true },
    } },
    [181] = { items = { 16685, 16683, 16686, 16684, 16687, 16689, 16688, 16682 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 18, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [182] = { items = { 16696, 16691, 16697, 16693, 16692, 16695, 16694, 16690 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 18, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [183] = { items = { 16702, 16703, 16699, 16701, 16700, 16704, 16698, 16705 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 18, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [184] = { items = { 16713, 16711, 16710, 16721, 16708, 16709, 16712, 16707 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { ap = 30, rap = 30 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { unknown = true },
    } },
    [185] = { items = { 16716, 16715, 16714, 16720, 16706, 16718, 16719, 16717 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { ap = 30, heal = 18, rap = 30, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [186] = { items = { 16680, 16675, 16681, 16677, 16674, 16678, 16679, 16676 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { ap = 30, rap = 30 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [187] = { items = { 16673, 16670, 16671, 16667, 16672, 16668, 16669, 16666 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 18, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [188] = { items = { 16723, 16725, 16722, 16726, 16724, 16728, 16729, 16727 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 18, sp = 18 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { stats = { mp5 = 8 } },
    } },
    [189] = { items = { 16736, 16734, 16735, 16730, 16737, 16731, 16732, 16733 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { str = 15 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
        [6] = { unknown = true },
    } },
    [201] = { items = { 16802, 16799, 16795, 16800, 16801, 16796, 16797, 16798 }, bonuses = {
        [3] = { stats = { heal = 18, sp = 18 } },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [202] = { items = { 16811, 16813, 16817, 16812, 16814, 16816, 16815, 16819 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { spellCrit = 2 } },
        [8] = { unknown = true },
    } },
    [203] = { items = { 16806, 16804, 16805, 16810, 16809, 16807, 16808, 16803 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [204] = { items = { 16827, 16824, 16825, 16820, 16821, 16826, 16822, 16823 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [205] = { items = { 16828, 16829, 16830, 16833, 16831, 16834, 16835, 16836 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { spellCrit = 2 } },
        [8] = { unknown = true },
    } },
    [206] = { items = { 16851, 16849, 16850, 16845, 16848, 16852, 16846, 16847 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [207] = { items = { 16838, 16837, 16840, 16841, 16844, 16839, 16842, 16843 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [208] = { items = { 16858, 16859, 16857, 16853, 16860, 16854, 16855, 16856 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { crit = 1, spellCrit = 1 } },
        [8] = { unknown = true },
    } },
    [209] = { items = { 16864, 16861, 16865, 16863, 16866, 16867, 16868, 16862 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [210] = { items = { 16818, 16918, 16912, 16914, 16917, 16913, 16915, 16916 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [211] = { items = { 16925, 16926, 16919, 16921, 16920, 16922, 16924, 16923 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [212] = { items = { 16933, 16927, 16934, 16928, 16930, 16931, 16929, 16932 }, bonuses = {
        [3] = { stats = { heal = 23, sp = 23 } },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [213] = { items = { 16910, 16906, 16911, 16905, 16907, 16908, 16909, 16832 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [214] = { items = { 16903, 16898, 16904, 16897, 16900, 16899, 16901, 16902 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [215] = { items = { 16936, 16935, 16942, 16940, 16941, 16939, 16938, 16937 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [216] = { items = { 16944, 16943, 16950, 16945, 16948, 16949, 16947, 16946 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { spellCrit = 3 } },
        [8] = { unknown = true },
    } },
    [217] = { items = { 16952, 16951, 16958, 16955, 16956, 16954, 16957, 16953 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { heal = 47, sp = 47 } },
        [8] = { unknown = true },
    } },
    [218] = { items = { 16959, 16966, 16964, 16963, 16962, 16961, 16965, 16960 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
        [8] = { unknown = true },
    } },
    [221] = { items = { 7950, 7948, 7952, 7951, 7953, 7949 }, bonuses = {
        [6] = { stats = { crit = 1 } },
    } },
    [241] = { items = { 278476, 17064 }, bonuses = {
        [2] = { unknown = true },
    } },
    [261] = { items = { 18203, 18202, 18204, 18205 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
    } },
    [321] = { items = { 12424, 12426, 12425, 12422, 12427, 12429, 12428, 250589 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { hit = 1, spellHit = 1 } },
        [4] = { unknown = true },
        [5] = { stats = { str = 20 } },
        [6] = { unknown = true },
    } },
    [341] = { items = { 16485, 16487, 16491, 16490, 16489, 16492 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 15 } },
    } },
    [342] = { items = { 17616, 17617, 17612, 17611, 17613, 17610 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 15 } },
    } },
    [347] = { items = { 16498, 16499, 16505, 16508, 16506, 16507 }, bonuses = {
        [2] = { stats = { parry = 1 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 15 } },
    } },
    [421] = { items = { 19682, 19683, 19684 }, skill = 197, rank = 300, bonuses = {
        [3] = { stats = { spellCrit = 2 } },
    } },
    [441] = { items = { 19685, 19687, 19686 }, skill = 165, rank = 300, bonuses = {
        [3] = { unknown = true },
    } },
    [442] = { items = { 19688, 19689 }, skill = 165, rank = 300, bonuses = {
        [2] = { stats = { crit = 1, spellCrit = 1 } },
    } },
    [443] = { items = { 19690, 19691, 19692 }, bonuses = {
        [3] = { stats = { mp5 = 12 } },
    } },
    [444] = { items = { 19693, 19694, 19695 }, skill = 164, rank = 300, bonuses = {
        [3] = { unknown = true },
    } },
    [461] = { items = { 19865, 19866 }, bonuses = {
        [2] = { unknown = true },
    } },
    [462] = { items = { 19905, 19893 }, bonuses = {
        [2] = { stats = { heal = 6, sp = 6, spellHit = 1 } },
    } },
    [463] = { items = { 19896, 19910 }, bonuses = {
        [2] = { unknown = true },
    } },
    [464] = { items = { 19873, 19912 }, bonuses = {
        [2] = { stats = { dodge = 1 } },
    } },
    [465] = { items = { 19863, 19920 }, bonuses = {
        [2] = { stats = { heal = 33 } },
    } },
    [466] = { items = { 19898, 19925 }, bonuses = {
        [2] = { stats = { ap = 30, rap = 30 } },
    } },
    [467] = { items = { 20041, 20048, 20057 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [468] = { items = { 20042, 20049, 20058 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [469] = { items = { 20043, 20050, 20055 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [470] = { items = { 20044, 20051, 20056 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { spellCrit = 1 } },
    } },
    [471] = { items = { 20052, 20045, 20059 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [472] = { items = { 20053, 20046, 20060 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { spellCrit = 1 } },
    } },
    [473] = { items = { 20054, 20047, 20061 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { spellCrit = 1 } },
    } },
    [474] = { items = { 19951, 19577, 19824, 19823, 19822 }, bonuses = {
        [2] = { stats = { block = 2 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [475] = { items = { 19952, 19588, 19827, 19826, 19825 }, bonuses = {
        [2] = { stats = { mp5 = 4 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [476] = { items = { 19609, 19956, 19830, 19829, 19828 }, bonuses = {
        [2] = { stats = { mp5 = 4 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [477] = { items = { 19621, 19953, 19833, 19832, 19831 }, bonuses = {
        [2] = { stats = { ap = 20, rap = 20 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [478] = { items = { 19617, 19954, 19836, 19835, 19834 }, bonuses = {
        [2] = { stats = { ap = 20, rap = 20 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [479] = { items = { 19613, 19955, 19840, 19839, 19838 }, bonuses = {
        [2] = { stats = { mp5 = 4 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [480] = { items = { 19594, 19958, 19843, 19842, 19841 }, bonuses = {
        [2] = { stats = { heal = 22 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [481] = { items = { 19605, 19957, 19848, 19849, 20033 }, bonuses = {
        [2] = { stats = { heal = 12, sp = 12 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [482] = { items = { 19601, 19959, 19846, 19845, 20034 }, bonuses = {
        [2] = { stats = { heal = 12, sp = 12 } },
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [483] = { items = { 20158, 20154, 20150 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [484] = { items = { 20195, 20199, 20203 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [485] = { items = { 20176, 20159, 20163 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { spellCrit = 1 } },
    } },
    [486] = { items = { 20186, 20190, 20194 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [487] = { items = { 20204, 20208, 20212 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { crit = 1 } },
    } },
    [488] = { items = { 20167, 20171, 20175 }, bonuses = {
        [2] = { stats = { sta = 5 } },
        [3] = { stats = { spellCrit = 1 } },
    } },
    [489] = { items = { 15050, 15052, 15051 }, bonuses = {
        [2] = { stats = { hit = 1, spellHit = 1 } },
        [3] = { stats = { crit = 2 } },
    } },
    [490] = { items = { 15045, 15046, 20296 }, bonuses = {
        [2] = { stats = { mp5 = 3 } },
        [3] = { unknown = true },
    } },
    [491] = { items = { 15048, 20295, 15049 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { heal = 28, sp = 28 } },
    } },
    [492] = { items = { 20406, 20408, 20407 }, bonuses = {
        [3] = { unknown = true },
    } },
    [493] = { items = { 21355, 21353, 21354, 21356, 21357 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [494] = { items = { 21408, 21409, 21407 }, bonuses = {
        [3] = { unknown = true },
    } },
    [495] = { items = { 21394, 21392, 21393 }, bonuses = {
        [3] = { unknown = true },
    } },
    [496] = { items = { 21331, 21329, 21333, 21332, 21330 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [497] = { items = { 21359, 21360, 21361, 21362, 21364 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [498] = { items = { 21405, 21406, 21404 }, bonuses = {
        [3] = { unknown = true },
    } },
    [499] = { items = { 21337, 21338, 21335, 21334, 21336 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [500] = { items = { 21416, 21417, 21418 }, bonuses = {
        [3] = { unknown = true },
    } },
    [501] = { items = { 21372, 21373, 21374, 21375, 21376 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [502] = { items = { 21400, 21398, 21399 }, bonuses = {
        [3] = { unknown = true },
    } },
    [503] = { items = { 21344, 21347, 21346, 21343, 21345 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [504] = { items = { 21414, 21413, 21415 }, bonuses = {
        [3] = { unknown = true },
    } },
    [505] = { items = { 21389, 21387, 21388, 21390, 21391 }, bonuses = {
        [3] = { unknown = true },
        [5] = { stats = { heal = 71, sp = 71 } },
    } },
    [506] = { items = { 21397, 21395, 21396 }, bonuses = {
        [3] = { unknown = true },
    } },
    [507] = { items = { 21349, 21350, 21348, 21352, 21351 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [508] = { items = { 21410, 21411, 21412 }, bonuses = {
        [3] = { unknown = true },
    } },
    [509] = { items = { 21366, 21365, 21370, 21368, 21367 }, bonuses = {
        [3] = { unknown = true },
        [5] = { unknown = true },
    } },
    [510] = { items = { 21403, 21401, 21402 }, bonuses = {
        [3] = { unknown = true },
    } },
    [511] = { items = { 21994, 21995, 21996, 21997, 21998, 21999, 22000, 22001 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { ap = 40, rap = 40 } },
        [8] = { unknown = true },
    } },
    [512] = { items = { 22002, 22003, 22004, 22005, 22006, 22007, 22008, 22009 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { ap = 40, rap = 40 } },
        [8] = { unknown = true },
    } },
    [513] = { items = { 22106, 22107, 22108, 22109, 22110, 22111, 22112, 22113 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { ap = 26, heal = 15, rap = 26, sp = 15 } },
        [8] = { unknown = true },
    } },
    [514] = { items = { 22078, 22079, 22080, 22081, 22082, 22083, 22084, 22085 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { heal = 23, sp = 23 } },
        [8] = { unknown = true },
    } },
    [515] = { items = { 22010, 22011, 22061, 22013, 22015, 22016, 22017, 22060 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { ap = 40, rap = 40 } },
        [8] = { unknown = true },
    } },
    [516] = { items = { 22086, 22087, 22088, 22089, 22090, 22091, 22092, 22093 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { ap = 40, rap = 40 } },
        [8] = { unknown = true },
    } },
    [517] = { items = { 22062, 22063, 22064, 22065, 22066, 22067, 22068, 22069 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { heal = 23, sp = 23 } },
        [8] = { unknown = true },
    } },
    [518] = { items = { 22070, 22071, 22072, 22073, 22074, 22075, 22076, 22077 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { heal = 23, sp = 23 } },
        [8] = { unknown = true },
    } },
    [519] = { items = { 22095, 22096, 22097, 22098, 22099, 22100, 22101, 22102 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { stats = { heal = 23, sp = 23 } },
        [8] = { unknown = true },
    } },
    [520] = { items = { 22306, 22311, 22313, 22302, 22304, 22305, 22303, 22301 }, bonuses = {
        [2] = { unknown = true },
        [3] = { unknown = true },
        [4] = { unknown = true },
        [5] = { stats = { heal = 23, sp = 23 } },
        [6] = { unknown = true },
    } },
    [521] = { items = { 22492, 22494, 22493, 22490, 22489, 22491, 22488, 22495, 23064 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [523] = { items = { 22423, 22416, 22421, 22422, 22418, 22417, 22419, 22420, 23059 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [524] = { items = { 22483, 22476, 22481, 22478, 22477, 22479, 22480, 22482, 23060 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [525] = { items = { 22518, 22519, 22514, 22517, 22513, 22512, 22516, 22515, 23061 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [526] = { items = { 22502, 22503, 22498, 22501, 22497, 22496, 22500, 22499, 23062 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [527] = { items = { 22468, 22470, 22469, 22466, 22465, 22467, 22464, 22471, 23065 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [528] = { items = { 22430, 22431, 22426, 22428, 22427, 22429, 22425, 22424, 23066 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [529] = { items = { 22510, 22511, 22506, 22509, 22505, 22504, 22508, 22507, 23063 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [530] = { items = { 22440, 22442, 22441, 22438, 22437, 22439, 22436, 22443, 23067 }, bonuses = {
        [2] = { unknown = true },
        [4] = { unknown = true },
        [6] = { unknown = true },
        [8] = { unknown = true },
    } },
    [533] = { items = { 23090, 23087, 23078 }, bonuses = {
        [3] = { unknown = true },
    } },
    [534] = { items = { 23081, 23089, 23093 }, bonuses = {
        [3] = { unknown = true },
    } },
    [535] = { items = { 23088, 23082, 23092 }, bonuses = {
        [3] = { unknown = true },
    } },
    [536] = { items = { 23091, 23084, 23085 }, bonuses = {
        [3] = { unknown = true },
    } },
    [537] = { items = { 22868, 22858, 22872, 22873, 23244, 23243 }, bonuses = {
        [2] = { stats = { ap = 40, rap = 40 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [538] = { items = { 22857, 22867, 22876, 22887, 23259, 23260 }, bonuses = {
        [2] = { stats = { ap = 40, rap = 40 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [540] = { items = { 22869, 22859, 22882, 22885, 23261, 23262 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [541] = { items = { 22865, 22855, 23255, 23256, 22881, 22884 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [542] = { items = { 22870, 22860, 23263, 23264, 22883, 22886 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [543] = { items = { 22843, 22862, 23251, 23252, 22874, 22875 }, bonuses = {
        [2] = { stats = { agi = 20 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [544] = { items = { 23272, 23273, 23274, 23275, 23276, 23277 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [545] = { items = { 23300, 23301, 23286, 23287, 23314, 23315 }, bonuses = {
        [2] = { stats = { ap = 40, rap = 40 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [547] = { items = { 23296, 23297, 23282, 23283, 23310, 23311 }, bonuses = {
        [2] = { stats = { heal = 23, sp = 23 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [548] = { items = { 23298, 23299, 23284, 23285, 23312, 23313 }, bonuses = {
        [2] = { stats = { ap = 40, rap = 40 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [550] = { items = { 23292, 23293, 23278, 23279, 23306, 23307 }, bonuses = {
        [2] = { stats = { agi = 20 } },
        [4] = { unknown = true },
        [6] = { stats = { sta = 20 } },
    } },
    [1968] = { items = { 250594, 250593, 250592, 250591, 250590, 250588, 250587, 250586 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { str = 20 } },
        [4] = { unknown = true },
        [5] = { stats = { hit = 2, spellHit = 2 } },
        [6] = { stats = { spHoly = 29 } },
    } },
    [1972] = { items = { 10010, 10011, 10020, 10032, 10038, 10039 }, bonuses = {
        [3] = { stats = { spi = 10 } },
        [6] = { stats = { heal = 22, sp = 8 } },
    } },
    [2071] = { items = { 21326, 268873 }, bonuses = {
        [2] = { unknown = true },
    } },
    [2131] = { items = { 284715, 284716 }, bonuses = {
        [2] = { stats = { str = 22 }, unknown = true },
    } },
    [2133] = { items = { 286978, 286980, 271207, 271214, 286979 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { int = 10 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
    [2134] = { items = { 273051, 286988, 286987, 286989, 273044 }, bonuses = {
        [2] = { unknown = true },
        [3] = { stats = { spi = 10 } },
        [4] = { unknown = true },
        [5] = { unknown = true },
    } },
}
