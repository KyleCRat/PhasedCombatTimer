local ADDON_NAME, PCT = ...

local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("LibEditMode-RPGBossBar-1.0")
local DEFAULTS = PCT.defaults

local OUTLINE_OPTIONS = {
    { text = "None", value = "" },
    { text = "Outline", value = "OUTLINE" },
    { text = "Thick Outline", value = "THICKOUTLINE" },
    { text = "Monochrome", value = "MONOCHROME" },
    { text = "Monochrome Outline", value = "MONOCHROMEOUTLINE" },
    { text = "Monochrome Thick", value = "MONOCHROMETHICKOUTLINE" },
}

local PLACEMENT_OPTIONS = {
    { text = "Below", value = "BELOW" },
    { text = "Above", value = "ABOVE" },
    { text = "Right", value = "RIGHT" },
    { text = "Left", value = "LEFT" },
}

function PCT:RestorePosition()
    local pos = self.db:Get("position")
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
end

local function OnPositionChanged(frame, layoutName, point, x, y)
    local actualPoint, _, relativePoint, actualX, actualY = frame:GetPoint(1)
    local uiScale = UIParent:GetScale() or 1

    actualX = PixelUtil.GetNearestPixelSize(actualX or x or 0, uiScale)
    actualY = PixelUtil.GetNearestPixelSize(actualY or y or 0, uiScale)

    PCT.db:Set("position", {
        point = actualPoint or point or DEFAULTS.position.point,
        relativePoint = relativePoint or actualPoint or DEFAULTS.position.relativePoint,
        x = actualX,
        y = actualY,
    })
end

local function GetEditModeSelection()
    if not PCT.frame then
        return nil
    end

    return PCT.frame.Selection or (LEM.frameSelections and LEM.frameSelections[PCT.frame])
end

local function SetEditModeSelectionState(alpha, isLabelVisible)
    local selection = GetEditModeSelection()
    if not selection then
        return
    end

    selection:SetAlpha(alpha)
    if selection.Label then
        if isLabelVisible then
            selection.Label:Show()
        else
            selection.Label:Hide()
        end
    end
end

local function HookEditModeSelectionVisuals()
    local selection = GetEditModeSelection()
    if not selection or selection.pctSelectionVisualsHooked then
        return
    end

    selection.pctSelectionVisualsHooked = true
    selection:HookScript("OnMouseDown", function(self)
        if self.isSelected then
            SetEditModeSelectionState(0, false)
        end
    end)
    selection:HookScript("OnLeave", function(self)
        if self.isSelected then
            SetEditModeSelectionState(0, false)
        else
            SetEditModeSelectionState(1, false)
        end
    end)

    if LEM.internal and LEM.internal.dialog and not LEM.internal.dialog.pctSelectionVisualsHooked then
        LEM.internal.dialog.pctSelectionVisualsHooked = true
        LEM.internal.dialog:HookScript("OnHide", function()
            local currentSelection = GetEditModeSelection()
            if currentSelection and not currentSelection.isSelected then
                SetEditModeSelectionState(1, false)
            end
        end)
    end
end

local function SetAndApply(value, ...)
    local args = { ... }
    args[#args + 1] = value
    PCT.db:Set(unpack(args))
    PCT:ApplySettings()
    PCT:UpdateVisibility()
end

local function CreateCheckboxSetting(name, path, disabled)
    return {
        name = name,
        kind = LEM.SettingType.Checkbox,
        default = PCT.db:GetDefault(unpack(path)),
        get = function()
            return PCT.db:Get(unpack(path))
        end,
        set = function(layoutName, value)
            SetAndApply(value, unpack(path))
        end,
        disabled = disabled,
    }
end

local function CreateSliderSetting(name, path, minValue, maxValue, valueStep, formatter, disabled)
    return {
        name = name,
        kind = LEM.SettingType.Slider,
        default = PCT.db:GetDefault(unpack(path)),
        get = function()
            return PCT.db:Get(unpack(path))
        end,
        set = function(layoutName, value)
            SetAndApply(value, unpack(path))
        end,
        minValue = minValue,
        maxValue = maxValue,
        valueStep = valueStep or 1,
        snapToStep = true,
        formatter = formatter or function(value) return value end,
        disabled = disabled,
    }
end

local function GetBackgroundPadding()
    return math.max(
        PCT.db:Get("backgroundPaddingTop") or 0,
        PCT.db:Get("backgroundPaddingRight") or 0,
        PCT.db:Get("backgroundPaddingBottom") or 0,
        PCT.db:Get("backgroundPaddingLeft") or 0
    )
end

local function CreateBackgroundPaddingSetting()
    return {
        name = "Padding",
        kind = LEM.SettingType.Slider,
        default = 0,
        get = GetBackgroundPadding,
        set = function(layoutName, value)
            PCT.db:Set("backgroundPaddingTop", value)
            PCT.db:Set("backgroundPaddingRight", value)
            PCT.db:Set("backgroundPaddingBottom", value)
            PCT.db:Set("backgroundPaddingLeft", value)
            PCT:ApplySettings()
            PCT:UpdateVisibility()
        end,
        minValue = 0,
        maxValue = 80,
        valueStep = 1,
        snapToStep = true,
        formatter = function(value) return math.floor(value) end,
    }
end

local function CreateTextInputSetting(name, path)
    return {
        name = name,
        kind = LEM.SettingType.TextInput,
        default = PCT.db:GetDefault(unpack(path)),
        get = function()
            return PCT.db:Get(unpack(path))
        end,
        set = function(layoutName, value)
            SetAndApply(value, unpack(path))
        end,
    }
end

local function CreateColorSetting(name, path)
    local defaultR, defaultG, defaultB, defaultA = PCT.db:GetColorDefault(unpack(path))
    return {
        name = name,
        kind = LEM.SettingType.ColorPicker,
        default = CreateColor(defaultR, defaultG, defaultB, defaultA),
        hasOpacity = true,
        get = function()
            return CreateColor(PCT.db:GetColor(unpack(path)))
        end,
        set = function(layoutName, value)
            local r, g, b, a = value:GetRGBA()
            local args = { unpack(path) }
            args[#args + 1] = { r = r, g = g, b = b, a = a or 1 }
            PCT.db:SetColor(unpack(args))
            PCT:ApplySettings()
        end,
    }
end

local function IsSelected(path, value)
    return PCT.db:Get(unpack(path)) == value
end

local function CreateDropdownSetting(name, path, values, height)
    return {
        name = name,
        kind = LEM.SettingType.Dropdown,
        default = PCT.db:GetDefault(unpack(path)),
        set = function(layoutName, value, fromReset)
            if fromReset then
                SetAndApply(value, unpack(path))
            end
        end,
        generator = function(owner, rootDescription)
            if height then
                rootDescription:SetScrollMode(height)
            end
            for _, option in ipairs(values) do
                rootDescription:CreateCheckbox(option.text, function(value)
                    return IsSelected(path, value)
                end, function(value)
                    SetAndApply(value, unpack(path))
                end, option.value)
            end
        end,
    }
end

local function CreateFontSetting()
    return {
        name = "Font",
        kind = LEM.SettingType.Dropdown,
        default = DEFAULTS.fontName,
        set = function(layoutName, value, fromReset)
            if fromReset then
                SetAndApply(value, "fontName")
            end
        end,
        generator = function(owner, rootDescription)
            rootDescription:SetScrollMode(400)
            for _, name in ipairs(LSM:List("font")) do
                rootDescription:CreateCheckbox(name, function(value)
                    return PCT.db:Get("fontName") == value
                end, function(value)
                    SetAndApply(value, "fontName")
                end, name)
            end
        end,
    }
end

function PCT:RegisterEditModeSettings()
    local defaultPosition = CopyTable(DEFAULTS.position)
    self.frame.editModeName = "Phased Combat Timer"
    LEM:AddFrame(self.frame, OnPositionChanged, defaultPosition, "Phased Combat Timer")
    HookEditModeSelectionVisuals()
    LEM:AddFrameSettings(self.frame, {
        { name = "Behavior", kind = LEM.SettingType.Divider, collapsed = false },
        CreateCheckboxSetting("Enabled", { "enabled" }),
        CreateCheckboxSetting("Only Show During Encounter", { "showOnlyDuringEncounter" }),
        CreateCheckboxSetting("Use Out Of Combat Opacity", { "useOutOfCombatOpacity" }, function()
            return PCT.db:Get("showOnlyDuringEncounter")
        end),
        CreateSliderSetting("Out Of Combat Opacity", { "outOfCombatOpacity" }, 0.05, 1, 0.05, function(value)
            return string.format("%d%%", math.floor((value * 100) + 0.5))
        end, function()
            return PCT.db:Get("showOnlyDuringEncounter") or not PCT.db:Get("useOutOfCombatOpacity")
        end),
        CreateCheckboxSetting("Show Labels", { "showLabels" }),
        CreateCheckboxSetting("Show Tenths Under 60s", { "showTenths" }),

        { name = "Text", kind = LEM.SettingType.Divider, collapsed = true },
        CreateFontSetting(),
        CreateDropdownSetting("Outline", { "fontOutline" }, OUTLINE_OPTIONS),
        CreateSliderSetting("Font Size", { "fontSize" }, 10, 72, 1, function(value) return math.floor(value) end),
        CreateTextInputSetting("Combat Label", { "combatLabel" }),
        CreateTextInputSetting("Phase Label", { "phaseLabel" }),
        CreateColorSetting("Combat Color", { "combatColor" }),
        CreateColorSetting("Phase Color", { "phaseColor" }),

        { name = "Background", kind = LEM.SettingType.Divider, collapsed = true },
        CreateColorSetting("Background Color", { "backgroundColor" }),
        CreateBackgroundPaddingSetting(),
        CreateSliderSetting("Padding: Top", { "backgroundPaddingTop" }, 0, 80, 1, function(value) return math.floor(value) end),
        CreateSliderSetting("Padding: Right", { "backgroundPaddingRight" }, 0, 80, 1, function(value) return math.floor(value) end),
        CreateSliderSetting("Padding: Bottom", { "backgroundPaddingBottom" }, 0, 80, 1, function(value) return math.floor(value) end),
        CreateSliderSetting("Padding: Left", { "backgroundPaddingLeft" }, 0, 80, 1, function(value) return math.floor(value) end),

        { name = "Layout", kind = LEM.SettingType.Divider, collapsed = true },
        CreateSliderSetting("Timer Spacing", { "timerSpacing" }, 0, 120, 1, function(value) return math.floor(value) end),
        CreateSliderSetting("Scale", { "scale" }, 0.5, 2, 0.05, function(value) return string.format("%.2f", value) end),
        CreateDropdownSetting("Phase Position", { "phasePlacement" }, PLACEMENT_OPTIONS),
    })

    LEM:RegisterCallback("enter", function()
        if PCT.OnEditModeEnter then
            PCT:OnEditModeEnter()
        end
    end)
    LEM:RegisterCallback("exit", function()
        if PCT.OnEditModeExit then
            PCT:OnEditModeExit()
        end
    end)
end
