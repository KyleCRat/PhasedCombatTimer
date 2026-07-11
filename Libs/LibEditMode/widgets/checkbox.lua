local MINOR = 16
local lib, minor = LibStub('LibEditMode-RPGBossBar-1.0')
if minor > MINOR then
	return
end

local function showTooltip(self)
	if self.setting and self.setting.desc then
		SettingsTooltip:SetOwner(self, 'ANCHOR_NONE')
		SettingsTooltip:SetPoint('BOTTOMRIGHT', self, 'TOPLEFT')
		SettingsTooltip:SetText(self.setting.name, 1, 1, 1)
		SettingsTooltip:AddLine(self.setting.desc)
		SettingsTooltip:Show()
	end
end

local function refreshOwnerWidgets(widget)
	local owner = widget:GetParent()
	owner = owner and owner:GetParent()

	if owner and not owner.RefreshWidgets then
		owner = owner:GetParent()
	end

	if owner and owner.RefreshWidgets then
		owner:RefreshWidgets()
	end
end

local checkboxMixin = {}

local function isDisabled(data)
	if type(data.disabled) == 'function' then
		return data.disabled(lib:GetActiveLayoutName(), data)
	end

	return data.disabled
end

function checkboxMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self:Refresh()

	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then
		value = data.default
	end

	self.checked = value
	self.Button:SetChecked(not not value) -- force boolean
end

function checkboxMixin:Refresh()
	local data = self.setting
	self:SetEnabled(not isDisabled(data))

	local hidden = data.hidden
	if type(hidden) == 'function' then
		hidden = hidden(lib:GetActiveLayoutName(), data)
	end

	self:SetShown(not hidden)
end

function checkboxMixin:OnCheckButtonClick()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	self.checked = not self.checked
	self.setting.set(lib:GetActiveLayoutName(), not not self.checked, false)

	refreshOwnerWidgets(self)
end

function checkboxMixin:SetEnabled(enabled)
	self.Button:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

lib.internal:CreatePool(lib.SettingType.Checkbox, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'EditModeSettingCheckboxTemplate')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.Button:SetPropagateMouseMotion(true)
	return Mixin(frame, checkboxMixin)
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
