-- HealIQ SpellData.lua
-- Canonical Restoration Druid spell-ID registry.
--
-- Single source of truth shared by the Engine (suggestion metadata) and the
-- Tracker / rules (cooldown and aura tracking). Define each spell ID exactly
-- once here; everything else references HealIQ.SpellData.<KEY>.
--
-- Buff checks reuse the casting spell's ID (e.g. the Clearcasting buff shares
-- spell 16870), so there are no separate "_BUFF" entries.

local addonName, HealIQ = ...

HealIQ.SpellData = {
    LIFEBLOOM = 33763,
    REJUVENATION = 774,
    REGROWTH = 8936,
    WILD_GROWTH = 48438,
    SWIFTMEND = 18562,
    CLEARCASTING = 16870,
    IRONBARK = 102342,
    EFFLORESCENCE = 145205,
    TRANQUILITY = 740,
    INCARNATION_TREE = 33891,
    NATURES_SWIFTNESS = 132158,
    BARKSKIN = 22812,
    FLOURISH = 197721,
    WRATH = 5176,
}
