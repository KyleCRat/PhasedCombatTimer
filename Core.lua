local ADDON_NAME, PCT = ...

local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("LibEditMode-RPGBossBar-1.0")

local eventFrame = CreateFrame("Frame")
local isInitialized = false
local inEncounter = false
local trackingCombat = false
local previewMode = false
local encounterStartTime
local phaseStartTime
local currentPhase = 1
local finalCombatElapsed
local finalPhaseElapsed
local finalPhase

local TIMER_WIDTH_SAMPLE_TEXT = "99:99"
local TENTHS_WIDTH_SAMPLE_TEXT = "59.9"
local TEXT_WIDTH_SAFETY_PADDING = 8
local MAX_PHASE_NUMBER = 9
local EDIT_MODE_PREVIEW_INTERVAL = 1.2
local EDIT_MODE_PREVIEW_PHASE_MAX = 9
local EDIT_MODE_PREVIEW_BUCKETS = {
    { min = 601, max = 5999, divisor = 1 },
    { min = 60, max = 599, divisor = 1 },
}
local EDIT_MODE_PREVIEW_TENTHS_BUCKET = { min = 1, max = 599, divisor = 10 }
local editModePreview = {
    nextUpdate = 0,
    bucketIndex = 0,
    combatSeconds = 0,
    phaseSeconds = 0,
    phase = 1,
    showTenths = false,
}
local displaySettings = {
    showTenths = false,
    showLabels = true,
    combatLabel = "",
    phaseLabel = "P",
}
local displayCache = {
    valid = false,
}

local function IsInEditMode()
    return LEM and LEM:IsInEditMode()
end

local function IsPlayerInCombat()
    return not not UnitAffectingCombat("player")
end

local function ShouldShowTimer()
    if inEncounter then
        return true
    end

    if PCT.db:Get("showOnlyDuringEncounter") then
        return false
    end

    if IsPlayerInCombat() then
        return true
    end

    return not PCT.db:Get("hideOutOfCombat")
end

local function RefreshDisplaySettings()
    displaySettings.showTenths = PCT.db:Get("showTenths")
    displaySettings.showLabels = PCT.db:Get("showLabels")
    displaySettings.combatLabel = PCT.db:Get("combatLabel")
    displaySettings.phaseLabel = PCT.db:Get("phaseLabel")
end

local function InvalidateDisplayCache()
    displayCache.valid = false
end

local function ResetEditModePreview()
    editModePreview.nextUpdate = 0
    editModePreview.bucketIndex = 0
    editModePreview.showTenths = displaySettings.showTenths
end

local function GetEditModePreviewBucketCount()
    if displaySettings.showTenths then
        return 3
    end

    return 2
end

local function GetEditModePreviewBucket(index)
    if index == 3 then
        return EDIT_MODE_PREVIEW_TENTHS_BUCKET
    end

    return EDIT_MODE_PREVIEW_BUCKETS[index]
end

local function GetRandomPreviewSeconds(bucket)
    return math.random(bucket.min, bucket.max) / bucket.divisor
end

local function RefreshEditModePreview(now)
    local showTenths = displaySettings.showTenths
    if editModePreview.nextUpdate > now and editModePreview.showTenths == showTenths then
        return
    end

    local bucketCount = GetEditModePreviewBucketCount()
    editModePreview.bucketIndex = (editModePreview.bucketIndex % bucketCount) + 1
    editModePreview.showTenths = showTenths
    editModePreview.nextUpdate = now + EDIT_MODE_PREVIEW_INTERVAL

    local bucket = GetEditModePreviewBucket(editModePreview.bucketIndex)
    editModePreview.combatSeconds = GetRandomPreviewSeconds(bucket)
    editModePreview.phaseSeconds = GetRandomPreviewSeconds(bucket)
    if editModePreview.phaseSeconds > editModePreview.combatSeconds then
        editModePreview.combatSeconds, editModePreview.phaseSeconds = editModePreview.phaseSeconds, editModePreview.combatSeconds
    end
    editModePreview.phase = math.random(1, EDIT_MODE_PREVIEW_PHASE_MAX)
end

local function FormatTime(seconds)
    seconds = math.max(seconds or 0, 0)

    if displaySettings.showTenths and seconds < 60 then
        return string.format("%.1f", seconds)
    end

    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", minutes, secs)
end

local function FormatTimer(label, seconds)
    if displaySettings.showLabels and label and label ~= "" then
        return label .. FormatTime(seconds)
    end

    return FormatTime(seconds)
end

local function FormatPhaseTimer(label, seconds)
    if displaySettings.showLabels and label and label ~= "" then
        return label .. " " .. FormatTime(seconds)
    end

    return FormatTime(seconds)
end

local function GetDisplayPhase(isInEditMode)
    if isInEditMode then
        return editModePreview.phase
    end

    if not encounterStartTime and finalPhase then
        return finalPhase
    end

    return currentPhase or 1
end

local function FormatPhaseLabelForPhase(phase)
    if displaySettings.showLabels then
        return displaySettings.phaseLabel .. tostring(phase or 1)
    end

    return ""
end

local function GetFontPath()
    local fontName = PCT.db:Get("fontName")
    return LSM:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
end

local function ApplyTextStyle()
    local fontPath = GetFontPath()
    local fontSize = PCT.db:Get("fontSize")
    local outline = PCT.db:Get("fontOutline") or ""
    local combatColor = PCT.db:Get("combatColor")
    local phaseColor = PCT.db:Get("phaseColor")

    PCT.frame.combatText:SetFont(fontPath, fontSize, outline)
    PCT.frame.phaseText:SetFont(fontPath, fontSize, outline)
    PCT.frame.measureText:SetFont(fontPath, fontSize, outline)
    PCT.frame.combatText:SetTextColor(combatColor.r, combatColor.g, combatColor.b, combatColor.a)
    PCT.frame.phaseText:SetTextColor(phaseColor.r, phaseColor.g, phaseColor.b, phaseColor.a)
end

local function ApplyBackgroundStyle()
    local backgroundColor = PCT.db:Get("backgroundColor")
    PCT.frame.background:SetColorTexture(
        backgroundColor.r,
        backgroundColor.g,
        backgroundColor.b,
        backgroundColor.a
    )
end

local function MeasureText(text)
    local measureText = PCT.frame.measureText
    measureText:SetText(text or "")
    return math.ceil(measureText:GetStringWidth() or 0), math.ceil(measureText:GetStringHeight() or 0)
end

local function MeasureTimerBox(label, timeText, timeWidth, timeHeight)
    if displaySettings.showLabels and label and label ~= "" then
        return MeasureText(label .. timeText)
    end

    return timeWidth, timeHeight
end

local function MeasurePhaseTimerBox(label, timeText, timeWidth, timeHeight)
    if displaySettings.showLabels and label and label ~= "" then
        return MeasureText(label .. " " .. timeText)
    end

    return timeWidth, timeHeight
end

local function GetTextMetrics()
    local timeText = TIMER_WIDTH_SAMPLE_TEXT
    local timeWidth, timeHeight = MeasureText(timeText)
    if displaySettings.showTenths then
        local tenthsWidth, tenthsHeight = MeasureText(TENTHS_WIDTH_SAMPLE_TEXT)
        if tenthsWidth > timeWidth then
            timeText = TENTHS_WIDTH_SAMPLE_TEXT
            timeWidth = tenthsWidth
        end
        timeHeight = math.max(timeHeight, tenthsHeight)
    end

    local combatWidth, combatHeight = MeasureTimerBox(displaySettings.combatLabel, timeText, timeWidth, timeHeight)
    local phaseWidth, phaseHeight = MeasurePhaseTimerBox(FormatPhaseLabelForPhase(MAX_PHASE_NUMBER), timeText, timeWidth, timeHeight)
    local minimumHeight = math.max(1, PCT.db:Get("fontSize"))

    return {
        combatWidth = combatWidth + TEXT_WIDTH_SAFETY_PADDING,
        phaseWidth = phaseWidth + TEXT_WIDTH_SAFETY_PADDING,
        combatHeight = math.max(combatHeight, minimumHeight),
        phaseHeight = math.max(phaseHeight, minimumHeight),
    }
end

local function ApplyLayout()
    local frame = PCT.frame
    local content = frame.content
    local combatText = frame.combatText
    local phaseText = frame.phaseText
    local metrics = GetTextMetrics()
    local placement = PCT.db:Get("phasePlacement")
    local timerSpacing = PCT.db:Get("timerSpacing") or 0
    local backgroundPaddingTop = PCT.db:Get("backgroundPaddingTop") or 0
    local backgroundPaddingRight = PCT.db:Get("backgroundPaddingRight") or 0
    local backgroundPaddingBottom = PCT.db:Get("backgroundPaddingBottom") or 0
    local backgroundPaddingLeft = PCT.db:Get("backgroundPaddingLeft") or 0
    local stackedWidth = math.max(metrics.combatWidth, metrics.phaseWidth)
    local textAreaWidth
    local textAreaHeight

    frame:SetScale(PCT.db:Get("scale"))
    content:ClearAllPoints()
    combatText:ClearAllPoints()
    phaseText:ClearAllPoints()
    combatText:SetSize(metrics.combatWidth, metrics.combatHeight)
    phaseText:SetSize(metrics.phaseWidth, metrics.phaseHeight)
    combatText:SetJustifyH("CENTER")
    phaseText:SetJustifyH("CENTER")

    if placement == "ABOVE" then
        textAreaWidth = stackedWidth
        textAreaHeight = metrics.combatHeight + metrics.phaseHeight + timerSpacing
        combatText:SetPoint("BOTTOM", content, "BOTTOM", 0, 0)
        phaseText:SetPoint("BOTTOM", combatText, "TOP", 0, timerSpacing)
    elseif placement == "RIGHT" then
        textAreaWidth = metrics.combatWidth + metrics.phaseWidth + timerSpacing
        textAreaHeight = math.max(metrics.combatHeight, metrics.phaseHeight)
        combatText:SetPoint("LEFT", content, "LEFT", 0, 0)
        phaseText:SetPoint("LEFT", combatText, "RIGHT", timerSpacing, 0)
    elseif placement == "LEFT" then
        textAreaWidth = metrics.combatWidth + metrics.phaseWidth + timerSpacing
        textAreaHeight = math.max(metrics.combatHeight, metrics.phaseHeight)
        combatText:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        phaseText:SetPoint("RIGHT", combatText, "LEFT", -timerSpacing, 0)
    else
        textAreaWidth = stackedWidth
        textAreaHeight = metrics.combatHeight + metrics.phaseHeight + timerSpacing
        combatText:SetPoint("TOP", content, "TOP", 0, 0)
        phaseText:SetPoint("TOP", combatText, "BOTTOM", 0, -timerSpacing)
    end

    frame:SetSize(
        textAreaWidth + backgroundPaddingLeft + backgroundPaddingRight,
        textAreaHeight + backgroundPaddingTop + backgroundPaddingBottom
    )
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", backgroundPaddingLeft, -backgroundPaddingTop)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -backgroundPaddingRight, backgroundPaddingBottom)
end

function PCT:ApplySettings()
    if not self.frame then
        return
    end

    RefreshDisplaySettings()
    InvalidateDisplayCache()
    ApplyTextStyle()
    ApplyBackgroundStyle()
    ApplyLayout()
    self:UpdateDisplay()
end

function PCT:UpdateDisplay()
    if not self.frame then
        return
    end

    local now = GetTime()
    local totalElapsed
    local phaseElapsed
    local isInEditMode = IsInEditMode()
    if isInEditMode then
        RefreshEditModePreview(now)
        totalElapsed = editModePreview.combatSeconds
        phaseElapsed = editModePreview.phaseSeconds
    else
        totalElapsed = encounterStartTime and (now - encounterStartTime) or (finalCombatElapsed or 0)
        phaseElapsed = phaseStartTime and (now - phaseStartTime) or (finalPhaseElapsed or 0)
    end

    local combatUsesTenths = displaySettings.showTenths and totalElapsed < 60
    local phaseUsesTenths = displaySettings.showTenths and phaseElapsed < 60
    local combatBucket = combatUsesTenths and math.floor((totalElapsed * 10) + 0.5) or math.floor(totalElapsed)
    local phaseBucket = phaseUsesTenths and math.floor((phaseElapsed * 10) + 0.5) or math.floor(phaseElapsed)
    local displayPhase = GetDisplayPhase(isInEditMode)
    local combatChanged = not displayCache.valid
        or displayCache.combatBucket ~= combatBucket
        or displayCache.combatUsesTenths ~= combatUsesTenths
    local phaseChanged = not displayCache.valid
        or displayCache.phaseBucket ~= phaseBucket
        or displayCache.phaseUsesTenths ~= phaseUsesTenths
        or displayCache.phase ~= displayPhase

    if not combatChanged and not phaseChanged then
        return
    end

    if combatChanged then
        self.frame.combatText:SetText(FormatTimer(displaySettings.combatLabel, totalElapsed))
    end
    if phaseChanged then
        local phaseLabel = FormatPhaseLabelForPhase(displayPhase)
        self.frame.phaseText:SetText(FormatPhaseTimer(phaseLabel, phaseElapsed))
    end

    displayCache.valid = true
    displayCache.combatBucket = combatBucket
    displayCache.combatUsesTenths = combatUsesTenths
    displayCache.phaseBucket = phaseBucket
    displayCache.phaseUsesTenths = phaseUsesTenths
    displayCache.phase = displayPhase
end

function PCT:UpdateAlpha()
    if not self.frame then
        return
    end

    if previewMode or IsInEditMode() then
        self.frame:SetAlpha(1)
        return
    end

    if PCT.db:Get("useOutOfCombatOpacity") and not inEncounter and not IsPlayerInCombat() then
        self.frame:SetAlpha(PCT.db:Get("outOfCombatOpacity"))
        return
    end

    self.frame:SetAlpha(1)
end

function PCT:UpdateVisibility()
    if not self.frame then
        return
    end

    if previewMode or IsInEditMode() then
        self:UpdateAlpha()
        self.frame:Show()
        return
    end

    if not PCT.db:Get("enabled") then
        self.frame:Hide()
        return
    end

    if not ShouldShowTimer() then
        self.frame:Hide()
        return
    end

    self:UpdateAlpha()
    self.frame:Show()
end

function PCT:StartTicker()
    if self.ticker then
        return
    end

    self.ticker = C_Timer.NewTicker(0.1, function()
        PCT:UpdateDisplay()
    end)
end

function PCT:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function PCT:StartEncounter()
    local now = GetTime()
    inEncounter = true
    trackingCombat = false
    previewMode = false
    encounterStartTime = now
    phaseStartTime = now
    currentPhase = 1
    finalCombatElapsed = nil
    finalPhaseElapsed = nil
    finalPhase = nil
    InvalidateDisplayCache()
    if PCT.db:Get("enabled") then
        self:StartTicker()
        self:UpdateDisplay()
    end
    self:UpdateVisibility()
end

function PCT:StartCombat()
    if inEncounter or trackingCombat then
        self:UpdateVisibility()
        return
    end

    local now = GetTime()
    trackingCombat = true
    previewMode = false
    encounterStartTime = now
    phaseStartTime = now
    currentPhase = 1
    finalCombatElapsed = nil
    finalPhaseElapsed = nil
    finalPhase = nil
    InvalidateDisplayCache()
    self:StartTicker()
    self:UpdateDisplay()
    self:UpdateVisibility()
end

function PCT:EndCombat()
    if not trackingCombat then
        self:UpdateVisibility()
        return
    end

    local now = GetTime()
    finalCombatElapsed = encounterStartTime and (now - encounterStartTime) or finalCombatElapsed
    finalPhaseElapsed = phaseStartTime and (now - phaseStartTime) or finalPhaseElapsed
    finalPhase = currentPhase or finalPhase or 1
    trackingCombat = false
    encounterStartTime = nil
    phaseStartTime = nil
    InvalidateDisplayCache()
    if not previewMode and not IsInEditMode() then
        self:StopTicker()
    end
    self:UpdateDisplay()
    self:UpdateVisibility()
end

function PCT:RefreshCombatTracking()
    if inEncounter then
        if PCT.db:Get("enabled") then
            self:StartTicker()
        else
            self:StopTicker()
        end
        self:UpdateVisibility()
        return
    end

    if PCT.db:Get("enabled") and not PCT.db:Get("showOnlyDuringEncounter") and IsPlayerInCombat() then
        self:StartCombat()
    else
        self:EndCombat()
    end
end

function PCT:EndEncounter()
    local now = GetTime()
    finalCombatElapsed = encounterStartTime and (now - encounterStartTime) or finalCombatElapsed
    finalPhaseElapsed = phaseStartTime and (now - phaseStartTime) or finalPhaseElapsed
    finalPhase = currentPhase or finalPhase or 1

    inEncounter = false
    trackingCombat = false
    encounterStartTime = nil
    phaseStartTime = nil
    InvalidateDisplayCache()
    if not previewMode then
        self:StopTicker()
    end
    self:UpdateDisplay()
    self:UpdateVisibility()
end

function PCT:SetPhase(phase, encounterID, testrun)
    if testrun then
        return
    end

    local now = GetTime()
    if not inEncounter or not encounterStartTime then
        finalCombatElapsed = nil
        finalPhaseElapsed = nil
        finalPhase = nil
    end

    currentPhase = phase or currentPhase or 1
    phaseStartTime = now

    if not inEncounter then
        inEncounter = true
        if trackingCombat then
            encounterStartTime = now
        end
        trackingCombat = false
    end
    if not encounterStartTime then
        encounterStartTime = now
    end

    self.encounterID = encounterID
    InvalidateDisplayCache()
    if PCT.db:Get("enabled") then
        self:StartTicker()
        self:UpdateDisplay()
    end
    self:UpdateVisibility()
end

local function OnNSRTPhase(event, phase, encounterID, testrun)
    PCT:SetPhase(phase, encounterID, testrun)
end

local function RefreshMediaSettings()
    if not isInitialized then
        return
    end

    PCT:ApplySettings()
    PCT:RefreshCombatTracking()
end

local function OnSharedMediaRegistered(event, mediaType, key)
    if mediaType == "font" and key == PCT.db:Get("fontName") then
        RefreshMediaSettings()
    end
end

function PCT:OnEditModeEnter()
    ResetEditModePreview()
    InvalidateDisplayCache()
    PCT:ApplySettings()
    PCT:StartTicker()
    PCT:UpdateDisplay()
    PCT:UpdateVisibility()
end

function PCT:OnEditModeExit()
    ResetEditModePreview()
    InvalidateDisplayCache()
    if not inEncounter and not trackingCombat and not previewMode then
        PCT:StopTicker()
    end
    PCT:UpdateDisplay()
    PCT:UpdateVisibility()
end

local function CreateFrameDisplay()
    local frame = CreateFrame("Frame", "PhasedCombatTimerFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints(frame)
    frame.content = CreateFrame("Frame", nil, frame)
    frame.combatText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.phaseText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.measureText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.measureText:SetAlpha(0)

    if frame.combatText.SetWordWrap then
        frame.combatText:SetWordWrap(false)
        frame.phaseText:SetWordWrap(false)
        frame.measureText:SetWordWrap(false)
    end

    PCT.frame = frame
    PCT:RestorePosition()
    PCT:ApplySettings()
    PCT:UpdateVisibility()
end

function PCT:TogglePreview()
    if not previewMode and (inEncounter or trackingCombat) then
        self:Print("Preview is unavailable while the timer is active.")
        return
    end

    previewMode = not previewMode
    InvalidateDisplayCache()
    if previewMode then
        local now = GetTime()
        encounterStartTime = now - 75
        phaseStartTime = now - 18
        currentPhase = 2
        self:StartTicker()
    elseif not inEncounter then
        encounterStartTime = nil
        phaseStartTime = nil
        currentPhase = 1
        self:StopTicker()
    end

    self:UpdateDisplay()
    self:UpdateVisibility()
    self:Print(previewMode and "Preview enabled." or "Preview disabled.")
end

function PCT:Print(message)
    print(("|cff66d9ef%s|r %s"):format(ADDON_NAME, message))
end

local function RegisterSlashCommands()
    local commands = {
        {
            triggers = { "test", "preview" },
            func = function() PCT:TogglePreview() end,
        },
        {
            triggers = { "reset" },
            func = function()
                PCT:ResetDatabase()
                PCT:RestorePosition()
                PCT:ApplySettings()
                PCT:RefreshCombatTracking()
                PCT:Print("Settings reset.")
            end,
        },
    }

    SLASH_PHASEDCOMBATTIMER1 = "/pct"
    SLASH_PHASEDCOMBATTIMER2 = "/phasedcombattimer"
    SlashCmdList.PHASEDCOMBATTIMER = function(msg)
        msg = strtrim(msg or ""):lower()

        for _, command in ipairs(commands) do
            for _, trigger in ipairs(command.triggers) do
                if msg == trigger then
                    command.func()
                    return
                end
            end
        end

        PCT:Print("/pct test - Toggle timer preview.")
        PCT:Print("/pct reset - Reset appearance settings.")
    end
end

local function OnAddonLoaded(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    PCT:InitializeDatabase()

    CreateFrameDisplay()
    PCT:RegisterEditModeSettings()
    RegisterSlashCommands()

    NSAPI.RegisterCallback(PCT, "NSRT_PHASE", OnNSRTPhase)
    LSM.RegisterCallback(PCT, "LibSharedMedia_Registered", OnSharedMediaRegistered)

    self:RegisterEvent("ENCOUNTER_START")
    self:RegisterEvent("ENCOUNTER_END")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_LOGOUT")
    isInitialized = true
    if IsLoggedIn() then
        C_Timer.After(0, RefreshMediaSettings)
    else
        self:RegisterEvent("PLAYER_LOGIN")
    end
end

local EVENT_HANDLERS = {
    ADDON_LOADED = OnAddonLoaded,
    PLAYER_LOGIN = function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        RefreshMediaSettings()
    end,
    ENCOUNTER_START = function()
        if isInitialized then
            PCT:StartEncounter()
        end
    end,
    ENCOUNTER_END = function()
        if isInitialized then
            PCT:EndEncounter()
        end
    end,
    PLAYER_REGEN_DISABLED = function()
        if isInitialized then
            PCT:RefreshCombatTracking()
        end
    end,
    PLAYER_REGEN_ENABLED = function()
        if isInitialized then
            PCT:RefreshCombatTracking()
        end
    end,
    PLAYER_LOGOUT = function()
        if NSAPI and NSAPI.UnregisterAllCallbacks then
            NSAPI.UnregisterAllCallbacks(PCT)
        end
        if LSM and LSM.UnregisterAllCallbacks then
            LSM.UnregisterAllCallbacks(PCT)
        end
    end,
}

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = EVENT_HANDLERS[event]
    if handler then
        handler(self, ...)
    end
end)
eventFrame:RegisterEvent("ADDON_LOADED")
