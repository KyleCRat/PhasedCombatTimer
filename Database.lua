local ADDON_NAME, PCT = ...

local SimpleDB = LibStub("LibSimpleDB-1.0")

local DEFAULTS = {
    enabled = true,
    showOnlyDuringEncounter = false,
    useOutOfCombatOpacity = true,
    outOfCombatOpacity = 0.35,
    showLabels = true,
    showTenths = false,
    fontName = "Friz Quadrata TT",
    fontSize = 28,
    fontOutline = "OUTLINE",
    timerSpacing = 6,
    scale = 1,
    phasePlacement = "BELOW",
    combatLabel = "",
    phaseLabel = "P",
    combatColor = { r = 1, g = 1, b = 1, a = 1 },
    phaseColor = { r = 0.35, g = 0.85, b = 1, a = 1 },
    backgroundColor = { r = 0, g = 0, b = 0, a = 0 },
    backgroundPaddingTop = 0,
    backgroundPaddingRight = 0,
    backgroundPaddingBottom = 0,
    backgroundPaddingLeft = 0,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 160,
    },
}

PCT.defaults = DEFAULTS

function PCT:InitializeDatabase()
    PhasedCombatTimerDB = PhasedCombatTimerDB or {}
    self.db = SimpleDB:New(PhasedCombatTimerDB, DEFAULTS)
end

function PCT:ResetDatabase()
    if not self.db then
        PhasedCombatTimerDB = PhasedCombatTimerDB or {}
        self.db = SimpleDB:New(PhasedCombatTimerDB, DEFAULTS)
    end

    self.db:Reset()
end
