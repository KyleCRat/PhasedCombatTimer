local MINOR = 16
local lib, minor = LibStub('LibEditMode-RPGBossBar-1.0')
if minor > MINOR then
	return
end

lib.SettingType.Divider = 'divider'

local dividerMixin = {}
function dividerMixin:Setup(data)
	self.setting = data
	self.Label:SetText(data.hideLabel and '' or data.name)
	self.Toggle:SetNormalAtlas(
		data.collapsed and "common-button-dropdown-closed" or "common-button-dropdown-open",
		true
	)
	self.Toggle:SetPushedAtlas(
		data.collapsed and "common-button-dropdown-closedpressed" or "common-button-dropdown-openpressed",
		true
	)
	self.Toggle:SetShown(self.onToggle ~= nil)
	self:Refresh()
end

function dividerMixin:SetOnToggleHandler(handler)
	self.onToggle = handler
end

function dividerMixin:Refresh()
	local data = self.setting
	local hidden = data.hidden
	if type(hidden) == 'function' then
		hidden = hidden(lib:GetActiveLayoutName(), data)
	end

	self:SetShown(not hidden)
end

function dividerMixin:OnClick()
	if self.onToggle and self.setting then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self.onToggle(self.setting)
	end
end

lib.internal:CreatePool(lib.SettingType.Divider, function()
	local frame = Mixin(CreateFrame('Button', nil, UIParent), dividerMixin)
	frame:SetSize(330, 32)
	frame.topPadding = 8
	frame.bottomPadding = 4
	frame:SetScript('OnClick', frame.OnClick)

	local texture = frame:CreateTexture(nil, 'ARTWORK')
	texture:SetPoint('BOTTOMLEFT', 0, -2)
	texture:SetPoint('BOTTOMRIGHT', 0, -2)
	texture:SetHeight(16)
	texture:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])

	local toggle = CreateFrame('Button', nil, frame)
	toggle:SetPoint('LEFT')
	toggle:SetSize(20, 20)
	toggle:SetScript('OnClick', function()
		frame:OnClick()
	end)
	frame.Toggle = toggle

	local label = frame:CreateFontString(nil, nil, 'GameFontHighlightHuge')
	label:SetPoint('LEFT', toggle, 'RIGHT', 6, 0)
	label:SetPoint('RIGHT')
	label:SetJustifyH('LEFT')
	frame.Label = label

	return frame
end, function(_, frame)
	frame:Hide()
	frame.setting = nil
	frame.onToggle = nil
	frame.Toggle:Hide()
	frame.Label:SetText()
	frame.layoutIndex = nil
end)
