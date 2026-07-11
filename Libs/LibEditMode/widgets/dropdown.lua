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

local function getDialog()
	return lib.internal and lib.internal.dialog
end

local function onMenuOpen(dropdown)
	local dialog = getDialog()
	if dialog and dialog.OnDropdownMenuOpen then
		dialog:OnDropdownMenuOpen(dropdown)
	end
end

local function onMenuClose(dropdown)
	local dialog = getDialog()
	if dialog and dialog.OnDropdownMenuClose then
		dialog:OnDropdownMenuClose(dropdown)
	end
end

local function get(data)
	local value = data.get(lib:GetActiveLayoutName())
	if value then
		if data.multiple then
			assert(type(value) == 'table', "multiple choice dropdowns expects a table from 'get'")

			for _, v in next, value do
				if v == data.value then
					return true
				end
			end
		else
			return value == data.value
		end
	end
end

local function set(data)
	data.set(lib:GetActiveLayoutName(), data.value, false)

	if data.widget then
		refreshOwnerWidgets(data.widget)
	end
end

local function createGeneratedMenuDescription(rootDescription, data)
	if data.multiple then
		return rootDescription
	end

	local description = {}
	setmetatable(description, {
		__index = function(_, key)
			local value = rootDescription[key]

			if type(value) == 'function' then
				return function(_, ...)
					return value(rootDescription, ...)
				end
			end

			return value
		end,
	})

	function description:CreateCheckbox(text, isSelected, setSelected, value)
		return rootDescription:CreateRadio(text, isSelected, setSelected, value)
	end

	return description
end

local dropdownMixin = {}
function dropdownMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.name)
	self.Dropdown:ClearMenuState()
	self.Dropdown:SetDefaultText(data.defaultText or data.name)
	self:Refresh()

	if data.generator then
		self.Dropdown:SetupMenu(function(owner, rootDescription)
			pcall(data.generator, owner, createGeneratedMenuDescription(rootDescription, data), data)
		end)
	elseif data.values then
		self.Dropdown:SetupMenu(function(_, rootDescription)
			if data.height then
				rootDescription:SetScrollMode(data.height)
			end

			local values = data.values
			if type(values) == 'function' then
				values = values()
			end

			for _, value in next, values do
				if data.multiple then
					rootDescription:CreateCheckbox(value.text, get, set, {
						get = data.get,
						set = data.set,
						value = value.value or value.text,
						multiple = data.multiple,
						widget = self,
					})
				else
					rootDescription:CreateRadio(value.text, get, set, {
						get = data.get,
						set = data.set,
						value = value.value or value.text,
						multiple = data.multiple,
						widget = self,
					})
				end
			end
		end)
	end
end

function dropdownMixin:Refresh()
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

function dropdownMixin:SetEnabled(enabled)
	self.Dropdown:SetEnabled(enabled)
	self.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

lib.internal:CreatePool(lib.SettingType.Dropdown, function()
	local frame = CreateFrame('Frame', nil, UIParent, 'ResizeLayoutFrame')
	frame:SetScript('OnLeave', DefaultTooltipMixin.OnLeave)
	frame:SetScript('OnEnter', showTooltip)
	frame.fixedHeight = 32
	Mixin(frame, dropdownMixin)

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightMedium')
	label:SetPoint('LEFT')
	label:SetWidth(100)
	label:SetJustifyH('LEFT')
	frame.Label = label

	local dropdown = CreateFrame('DropdownButton', nil, frame, 'WowStyle1DropdownTemplate')
	dropdown:SetPoint('LEFT', label, 'RIGHT', 5, 0)
	dropdown:SetPoint('RIGHT', frame, 'RIGHT', -4, 0)
	dropdown:SetHeight(30)
	dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, onMenuOpen, dropdown)
	dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, onMenuClose, dropdown)
	frame.Dropdown = dropdown

	return frame
end, function(_, frame)
	frame.Dropdown:ClearMenuState()
	frame:Hide()
	frame.layoutIndex = nil
	frame.setting = nil
end)
