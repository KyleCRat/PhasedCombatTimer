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

local function setEditBoxText(editBox)
	local parent = editBox:GetParent()
	if not parent.setting then
		return
	end

	local value = parent.setting.get(lib:GetActiveLayoutName())

	editBox:SetText(value or '')
	editBox:SetCursorPosition(0)
end

local function onEditSubmit(self)
	local parent = self:GetParent()
	if not parent.setting then
		return
	end

	if parent.submitInProgress then
		return
	end

	local value = self:GetText() or ''

	parent.submitInProgress = true
	parent.setting.set(lib:GetActiveLayoutName(), value, false)
	parent.submitInProgress = false

	self:ClearFocus()
end

local function onEditReset(self)
	local parent = self:GetParent()
	if parent then
		parent.submitInProgress = true
	end

	setEditBoxText(self)
	self:ClearFocus()

	if parent then
		parent.submitInProgress = false
	end
end

local textInputMixin = {}
function textInputMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self:Refresh()
	setEditBoxText(self.EditBox)
end

function textInputMixin:Refresh()
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

function textInputMixin:SetEnabled(enabled)
	self.EditBox:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

lib.internal:CreatePool(lib.SettingType.TextInput, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.fixedHeight = 32
	Mixin(frame, textInputMixin)

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightMedium')
	label:SetPoint('LEFT')
	label:SetWidth(100)
	label:SetJustifyH('LEFT')
	frame.Label = label

	local editBox = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
	editBox:SetAutoFocus(false)
	editBox:SetPoint('LEFT', label, 'RIGHT', 5, 0)
	editBox:SetPoint('RIGHT', frame, 'RIGHT', -4, 0)
	editBox:SetHeight(24)
	editBox:SetScript('OnEnterPressed', onEditSubmit)
	editBox:SetScript('OnEscapePressed', onEditReset)
	editBox:SetScript('OnEditFocusLost', onEditSubmit)
	frame.EditBox = editBox

	return frame
end, function(_, frame)
	frame:Hide()
	frame.setting = nil
	frame.submitInProgress = nil
	frame.layoutIndex = nil
end)
