local MINOR = 16
local lib, minor = LibStub('LibEditMode-RPGBossBar-1.0')
if minor > MINOR then
	return
end

lib.SettingType.Expander = 'expander'

local ARROW_UP = ' |A:editmode-up-arrow:16:11:0:3|a'
local ARROW_DOWN = ' |A:editmode-down-arrow:16:11:0:-4|a'

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

local expanderMixin = {}
function expanderMixin:Setup(data)
	self.setting = data
	self:Refresh()

	local value = data.get(lib:GetActiveLayoutName())
	if value == nil then
		value = data.default
	end

	self:SetExpandedState(not not value) -- force boolean
end

function expanderMixin:Refresh()
	local data = self.setting
	local hidden = data.hidden
	if type(hidden) == 'function' then
		hidden = hidden(lib:GetActiveLayoutName(), data)
	end

	self:SetShown(not hidden)
end

function expanderMixin:SetExpandedState(expanded)
	local data = self.setting

	self.expanded = expanded
	data.set(lib:GetActiveLayoutName(), expanded, false)

	local text = data.name
	if data.expandedLabel and data.collapsedLabel then
		text = expanded and data.expandedLabel or data.collapsedLabel
	end

	if not data.hideArrow then
		text = text .. (expanded and ARROW_UP or ARROW_DOWN)
	end

	self.Label:SetText(text)
	self.Divider:SetShown(not expanded)

	refreshOwnerWidgets(self)
end

function expanderMixin:OnMouseUp()
	self:SetExpandedState(not self.expanded)
end

lib.internal:CreatePool(lib.SettingType.Expander, function()
	local frame = Mixin(CreateFrame('Frame', nil, UIParent), expanderMixin)
	frame:SetScript('OnMouseUp', frame.OnMouseUp)
	frame:SetSize(330, 34)
	frame.align = 'center'

	local texture = frame:CreateTexture(nil, 'ARTWORK')
	texture:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	texture:SetSize(330, 16)
	texture:SetPoint('TOP', 0, 0)
	frame.Divider = texture

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightMedium')
	label:SetJustifyH('CENTER')
	label:SetJustifyV('MIDDLE')
	label:SetPoint('TOP', 0, -11)
	frame.Label = label

	return frame
end, function(_, frame)
	frame:Hide()
	frame.Label:SetText()
	frame.layoutIndex = nil
end)
