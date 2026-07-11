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

local buttonMixin = {}
function buttonMixin:Setup(data)
	self.setting = data
	self:SetText(data.text or data.name)
	self:Refresh()

	if data.click then
		self:SetOnClickHandler(data.click)
	end
end

function buttonMixin:Refresh()
	local data = self.setting
	local disabled = data.disabled
	if type(disabled) == 'function' then
		disabled = disabled(lib:GetActiveLayoutName(), data)
	end

	self:SetEnabled(not disabled)

	local hidden = data.hidden
	if type(hidden) == 'function' then
		hidden = hidden(lib:GetActiveLayoutName(), data)
	end

	self:SetShown(not hidden)
end

lib.internal:CreatePool(lib.SettingType.Button, function()
	local button = CreateFrame('Button', nil, UIParent, 'EditModeSystemSettingsDialogExtraButtonTemplate')
	button:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	button:SetScript('OnEnter', showTooltip)
	return Mixin(button, buttonMixin)
end, function(_, button)
	button:Hide()
	button.setting = nil
	button.layoutIndex = nil
end)
