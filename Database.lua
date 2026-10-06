local ADDON_NAME, PCT = ...

local SimpleDB = LibStub("LibSimpleDB-1.0")

local DEFAULTS = {
    enabled = true,
    showOnlyDuringEncounter = false,
    hideOutOfCombat = false,
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

local CHARACTER_DEFAULTS = {
    lastResult = {
        valid = false,
        combatElapsed = 0,
        phaseElapsed = 0,
        phase = 1,
    },
}

local function IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function IsValidElapsed(value)
    return IsFiniteNumber(value) and value >= 0
end

local function IsValidPhase(value)
    return IsFiniteNumber(value) and value > 0
end

PCT.defaults = DEFAULTS

function PCT:InitializeDatabase()
    PhasedCombatTimerDB = PhasedCombatTimerDB or {}
    PhasedCombatTimerCharacterDB = PhasedCombatTimerCharacterDB or {}
    self.db = SimpleDB:New(PhasedCombatTimerDB, DEFAULTS)
    self.characterDB = SimpleDB:New(PhasedCombatTimerCharacterDB, CHARACTER_DEFAULTS)
end

function PCT:LoadLastResult()
    local result = self.characterDB:GetRaw("lastResult")
    if result == nil then
        return nil
    end

    if type(result) ~= "table"
        or result.valid ~= true
        or not IsValidElapsed(result.combatElapsed)
        or not IsValidElapsed(result.phaseElapsed)
        or not IsValidPhase(result.phase)
    then
        self.characterDB:Delete("lastResult")
        return nil
    end

    return result.combatElapsed, result.phaseElapsed, result.phase
end

function PCT:SaveLastResult(combatElapsed, phaseElapsed, phase)
    if not IsValidElapsed(combatElapsed)
        or not IsValidElapsed(phaseElapsed)
        or not IsValidPhase(phase)
    then
        return false
    end

    self.characterDB:Set("lastResult", {
        valid = true,
        combatElapsed = combatElapsed,
        phaseElapsed = phaseElapsed,
        phase = phase,
    })
    return true
end

function PCT:ClearLastResult()
    self.characterDB:Delete("lastResult")
end

function PCT:ResetDatabase()
    if not self.db then
        PhasedCombatTimerDB = PhasedCombatTimerDB or {}
        self.db = SimpleDB:New(PhasedCombatTimerDB, DEFAULTS)
    end

    self.db:Reset()
end
