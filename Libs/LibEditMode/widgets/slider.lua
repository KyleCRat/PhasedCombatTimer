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
	local owner = widget
	while owner and not owner.RefreshWidgets do
		owner = owner:GetParent()
	end

	if not owner and lib.internal and lib.internal.dialog and lib.internal.dialog:IsShown() then
		owner = lib.internal.dialog
	end

	if owner and owner.RefreshWidgets then
		owner:RefreshWidgets()
	end
end

local sliderMixin = {}

local function isDisabled(data)
	if type(data.disabled) == 'function' then
		return data.disabled(lib:GetActiveLayoutName(), data)
	end

	return data.disabled
end

local function snapValueToStep(value, minValue, stepSize)
	if not stepSize or stepSize <= 0 then
		return value
	end

	local snappedValue = minValue + (math.floor(((value - minValue) / stepSize) + 0.5) * stepSize)

	return tonumber(string.format('%.10f', snappedValue))
end

function sliderMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self:Refresh()

	self.initInProgress = true
	self.formatters = {}
	self.formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, data.formatter)

	local stepSize = data.valueStep or 1
	local steps = (data.maxValue - data.minValue) / stepSize
	self.Slider:Init(data.get(lib:GetActiveLayoutName()) or data.default, data.minValue or 0, data.maxValue or 1, steps, self.formatters)
	self.initInProgress = false
end

function sliderMixin:Refresh()
	local data = self.setting
	self:SetEnabled(not isDisabled(data))

	if self.formatters and self.Slider and self.Slider.SetValue and not self.EditBox:HasFocus() then
		local value = data.get(lib:GetActiveLayoutName())
		if value == nil then
			value = data.default
		end

		self.suppressSliderChange = true
		self.Slider:SetValue(value)
		self.suppressSliderChange = false
		self.Slider:FormatValue(value)
	end

	local hidden = data.hidden
	if type(hidden) == 'function' then
		hidden = hidden(lib:GetActiveLayoutName(), data)
	end

	self:SetShown(not hidden)
end

function sliderMixin:OnSliderValueChanged(value)
	if not self.initInProgress and not self.suppressSliderChange then
		if self.setting.snapToStep then
			value = snapValueToStep(value, self.setting.minValue or 0, self.setting.valueStep)
		end

		self.setting.set(lib:GetActiveLayoutName(), value, false)

		refreshOwnerWidgets(self)
	end
end

function sliderMixin:SetEnabled(enabled)
	self.Slider:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
	self.EditBox:SetShown(enabled)
end

local function positionEditBoxNormally(self)
	local parent = self:GetParent()

	self:ClearAllPoints()
	self:SetPoint('RIGHT', parent, 'RIGHT', -4, 0)
	self:SetSize(46, 24)
end

local function onEditFocus(self)
	local parent = self:GetParent()
	local value = parent.Slider.Slider:GetValue()

	-- hide slider
	parent.Slider:Hide()

	-- resize editbox to take up the available space
	self:ClearAllPoints()
	self:SetPoint('LEFT', parent.Label, 'RIGHT', 5, 0)
	self:SetPoint('RIGHT', parent, 'RIGHT', -4, 0)
	self:SetHeight(24)

	-- set editbox text to current slider value
	if parent.setting and parent.setting.editFormatter then
		self:SetText(parent.setting.editFormatter(value))
	else
		self:SetText(value)
	end

	self:SetCursorPosition(0)
end

local function onEditSubmit(self)
	local parent = self:GetParent()

	-- get bounds and value
	local min, max = parent.Slider.Slider:GetMinMaxValues()
	local value = tonumber(self:GetText())

	-- trigger change if value is a valid number
	if value then
		-- use bounds when updating value
		value = math.min(math.max(value, min), max)

		parent.suppressSliderChange = true
		parent.Slider:SetValue(value)
		parent.suppressSliderChange = false
		parent.Slider:FormatValue(value)
		parent.setting.set(lib:GetActiveLayoutName(), value, false)
		refreshOwnerWidgets(parent)
	end

	self:ClearFocus()
end

local function onEditReset(self)
	local parent = self:GetParent()
	parent.Slider:Show()

	self:SetText('')
	self:ClearFocus()

	positionEditBoxNormally(self)
end

lib.internal:CreatePool(lib.SettingType.Slider, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'EditModeSettingSliderTemplate')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	Mixin(frame, sliderMixin)

	frame:SetHeight(32)
	frame.Slider.MinText:Hide()
	frame.Slider.MaxText:Hide()
	frame.Label:SetPoint('LEFT')

	local editBox = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
	editBox:SetAutoFocus(false)
	editBox:SetJustifyH('CENTER')
	editBox:SetScript('OnEditFocusGained', onEditFocus)
	editBox:SetScript('OnEnterPressed', onEditSubmit)
	editBox:SetScript('OnEscapePressed', onEditReset)
	editBox:SetScript('OnEditFocusLost', onEditReset)
	frame.EditBox = editBox
	positionEditBoxNormally(editBox)

	frame.Slider:ClearAllPoints()
	frame.Slider:SetPoint('LEFT', frame.Label, 'RIGHT', 5, 0)
	frame.Slider:SetPoint('RIGHT', editBox, 'LEFT', -5, 0)

	frame.Slider.RightText:ClearAllPoints()
	frame.Slider.RightText:SetPoint('CENTER', editBox)

	frame:OnLoad()
	return frame
end, function(_, frame)
	frame:Hide()
	frame.layoutIndex = nil
end)
