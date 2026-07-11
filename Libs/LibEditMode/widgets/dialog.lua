local MINOR = 16
local lib, minor = LibStub('LibEditMode-RPGBossBar-1.0')
if minor > MINOR then
	return
end

local CENTER = {
	point = 'CENTER',
	x = 0,
	y = 0,
}

local internal = lib.internal
local MAX_SETTINGS_HEIGHT = 560
local MIN_SETTINGS_HEIGHT = 220
local DIALOG_PADDING = 10
local DIALOG_WIDTH = 370
local PANEL_BACKGROUND_LEFT = 6
local PANEL_BACKGROUND_RIGHT = 2
local PANEL_BACKGROUND_TOP = 20
local PANEL_BACKGROUND_BOTTOM = 2
local SETTINGS_CONTAINER_WIDTH = DIALOG_WIDTH
	- PANEL_BACKGROUND_LEFT
	- PANEL_BACKGROUND_RIGHT
	- DIALOG_PADDING * 2
local SETTINGS_CONTENT_WIDTH = SETTINGS_CONTAINER_WIDTH - 22
local DIALOG_CONTENT_TOP = PANEL_BACKGROUND_TOP + DIALOG_PADDING
local FOOTER_DIVIDER_HEIGHT = 16
local FOOTER_DIVIDER_GAP = 2
local DIALOG_BOTTOM_PADDING = PANEL_BACKGROUND_BOTTOM + DIALOG_PADDING

-- replica of EditModeSystemSettingsDialog
local dialogMixin = {}
function dialogMixin:Update(selection)
	self.selection = selection

	self:SetTitle(selection.system:GetSystemName())
	self:UpdateSettings()
	self:UpdateButtons()
	self:Show()
	self:UpdateSettingsViewport()
end

function dialogMixin:ToggleSection(section)
	section.collapsed = not section.collapsed
	self:Update(self.selection)
end

function dialogMixin:RefreshWidgets()
	for _, widget in next, self.Settings.widgets do
		if widget.Refresh then
			widget:Refresh()
		end
	end

	if self:IsShown() then
		self:UpdateSettingsViewport()
	end
end

function dialogMixin:IsDropdownMenuOpen()
	return (self.openDropdownMenuCount or 0) > 0
end

function dialogMixin:DeferRefresh(selection)
	self.deferredRefreshSelection = selection
end

function dialogMixin:FlushDeferredRefresh()
	local selection = self.deferredRefreshSelection
	self.deferredRefreshSelection = nil

	if selection and self.selection == selection and self:IsVisible() then
		self:Update(selection)
	end
end

function dialogMixin:OnDropdownMenuOpen(dropdown)
	self.openDropdownMenus = self.openDropdownMenus or {}

	if not self.openDropdownMenus[dropdown] then
		self.openDropdownMenus[dropdown] = true
		self.openDropdownMenuCount = (self.openDropdownMenuCount or 0) + 1
	end
end

function dialogMixin:OnDropdownMenuClose(dropdown)
	if self.openDropdownMenus and self.openDropdownMenus[dropdown] then
		self.openDropdownMenus[dropdown] = nil
		self.openDropdownMenuCount = math.max((self.openDropdownMenuCount or 1) - 1, 0)
	end

	if not self:IsDropdownMenuOpen() then
		self:FlushDeferredRefresh()
	end
end

function dialogMixin:UpdateSettings()
	internal.ReleaseAllPools()

	self.Settings.widgets = table.wipe(self.Settings.widgets or {})

	local settings, num = internal:GetFrameSettings(self.selection.parent)
	local sectionCollapsed = false
	local visibleIndex = 0
	if num > 0 then
		for _, data in ipairs(settings) do
			if data.kind == lib.SettingType.Divider then
				sectionCollapsed = not not data.collapsed
			end

			local pool = internal:GetPool(data.kind)
			if pool and (data.kind == lib.SettingType.Divider or not sectionCollapsed) then
				local setting = pool:Acquire(self.Settings)
				visibleIndex = visibleIndex + 1
				setting.layoutIndex = visibleIndex
				setting:SetWidth(SETTINGS_CONTENT_WIDTH)
				if setting.SetFixedWidth then
					setting:SetFixedWidth(SETTINGS_CONTENT_WIDTH)
				end
				if data.kind == lib.SettingType.Divider then
					setting:SetOnToggleHandler(GenerateClosure(self.ToggleSection, self))
				end
				setting:Setup(data)

				table.insert(self.Settings.widgets, setting)
			end
		end
	end

	local hideResetButton = self.selection.parent.hideDefaultSettingsResetButton
	self.Settings.ResetButton.layoutIndex = visibleIndex + 1
	self.Settings.ResetButton.ignoreInLayout = hideResetButton
	self.Settings.ResetButton:SetShown(not hideResetButton)
	self.Settings.ResetButton:SetEnabled(num > 0 and not hideResetButton)
end

function dialogMixin:UpdateSettingsViewport()
	self.Settings:Layout()

	local contentHeight = self.Settings:GetHeight()
	local availableHeight = math.max(
		MIN_SETTINGS_HEIGHT,
		math.min(MAX_SETTINGS_HEIGHT, UIParent:GetHeight() - 250)
	)
	local viewportHeight = math.min(contentHeight, availableHeight)
	local scrollRange = math.max(0, contentHeight - viewportHeight)
	local scrollValue = math.min(self.SettingsScroll:GetVerticalScroll(), scrollRange)

	self.SettingsScroll:SetHeight(viewportHeight)
	self.SettingsScroll:SetVerticalScroll(scrollValue)

	local scrollBar = self.SettingsScroll.ScrollBar
	scrollBar:SetMinMaxValues(0, scrollRange)
	scrollBar:SetValue(scrollValue)
	scrollBar:SetShown(scrollRange > 0)

	self.Buttons:Layout()
	self:SetSize(
		DIALOG_WIDTH,
		DIALOG_CONTENT_TOP
			+ viewportHeight
			+ FOOTER_DIVIDER_GAP
			+ FOOTER_DIVIDER_HEIGHT
			+ FOOTER_DIVIDER_GAP
			+ self.Buttons:GetHeight()
			+ DIALOG_BOTTOM_PADDING
	)
end

function dialogMixin:Reset()
	self.selection = nil
	self.deferredRefreshSelection = nil
	self.openDropdownMenus = nil
	self.openDropdownMenuCount = 0
	self:ClearAllPoints()
	self:SetPoint('BOTTOMRIGHT', UIParent, -250, 250)
end

local function closeEnough(a, b)
	return math.abs(a - b) < 0.01
end

local function isDefaultPosition(parent)
	local point, _, _, x, y = parent:GetPoint()
	local default = lib:GetFrameDefaultPosition(parent)
	if not default then
		default = CopyTable(CENTER)
	end

	return point == default.point and closeEnough(x, default.x) and closeEnough(y, default.y)
end

function dialogMixin:UpdateButtons()
	local parent = self.selection.parent
	local buttons, num = internal:GetFrameButtons(parent)
	if num > 0 then
		for index, data in ipairs(buttons) do
			local kind = data.kind or lib.SettingType.Button
			local pool = internal:GetPool(kind)
			if pool then
				local control = pool:Acquire(self.Buttons)
				control.layoutIndex = index
				control:SetWidth(SETTINGS_CONTAINER_WIDTH)
				if control.SetFixedWidth then
					control:SetFixedWidth(SETTINGS_CONTAINER_WIDTH)
				end
				control:Setup(data)
			end
		end
	end

	local resetPosition = internal:GetPool(lib.SettingType.Button):Acquire(self.Buttons)
	resetPosition.layoutIndex = num + 1
	resetPosition:SetWidth(SETTINGS_CONTAINER_WIDTH)
	resetPosition:Setup({
		text = HUD_EDIT_MODE_RESET_POSITION,
		click = GenerateClosure(self.ResetPosition, self),
		disabled = isDefaultPosition(parent),
	})
	self.Buttons.ResetPositionButton = resetPosition
end

function dialogMixin:ResetSettings()
	local settings, num = internal:GetFrameSettings(self.selection.parent)
	if num > 0 then
		for _, data in next, settings do
			if data.set then
				data.set(lib:GetActiveLayoutName(), data.default, true)
			end
		end

		self:Update(self.selection)
	end
end

function dialogMixin:ResetPosition()
	if InCombatLockdown() then
		-- TODO: maybe add a warning?
		return
	end

	local parent = self.selection.parent
	local pos = lib:GetFrameDefaultPosition(parent)
	if not pos then
		pos = CopyTable(CENTER)
	end

	parent:ClearAllPoints()
	parent:SetPoint(pos.point, pos.x, pos.y)
	self.Buttons.ResetPositionButton:SetEnabled(false)

	internal:TriggerCallback(parent, pos.point, pos.x, pos.y)
end

local BIG_STEP = 10
local SMALL_STEP = 1

local function ScrollMenuToDescription(menu, description)
	local scrollBox = menu and menu.ScrollBox
	if not scrollBox or not scrollBox.ScrollToElementDataByPredicate then
		return
	end

	if scrollBox.HasDataProvider and not scrollBox:HasDataProvider() then
		return
	end

	local alignNearest = ScrollBoxConstants and ScrollBoxConstants.AlignNearest
	scrollBox:ScrollToElementDataByPredicate(function(frame)
		return frame.GetElementDescription and frame:GetElementDescription() == description
	end, alignNearest)
end

local function PickDropdownRadio(menu, owner, description)
	if not description or not owner.Pick then
		return
	end

	if description.SetResponse and MenuResponse and MenuResponse.Refresh then
		local previousResponse = description.defaultResponse
		description:SetResponse(MenuResponse.Refresh)
		owner:Pick(description, MenuInputContext.MouseWheel)
		description:SetResponse(previousResponse)
	else
		owner:Pick(description, MenuInputContext.MouseWheel)
	end

	owner.libEditModeSelectedDescription = description
	ScrollMenuToDescription(menu, description)
end

local function GetDropdownStepDescription(owner, key)
	if not MenuUtil or not MenuUtil.TraverseMenu or not owner.GetMenuDescription then
		return nil
	end

	local menuDescription = owner:GetMenuDescription()
	if not menuDescription then
		return nil
	end

	local radioDescriptions = {}
	local selectedIndex
	local keyboardSelectedIndex

	MenuUtil.TraverseMenu(menuDescription, function(description)
		local isUsableRadio = description.IsRadio
			and description:IsRadio()
			and description.CanSelect
			and description:CanSelect()

		if isUsableRadio then
			local index = #radioDescriptions + 1
			radioDescriptions[index] = description

			if description.IsSelected and description:IsSelected() then
				selectedIndex = index

				if description == owner.libEditModeSelectedDescription then
					keyboardSelectedIndex = index
				end
			end
		end
	end)

	local numDescriptions = #radioDescriptions
	if numDescriptions == 0 then
		return nil
	end

	selectedIndex = keyboardSelectedIndex or selectedIndex
	if not selectedIndex then
		if key == 'DOWN' then
			return radioDescriptions[1]
		end

		return radioDescriptions[numDescriptions]
	end

	local nextIndex = selectedIndex
	if key == 'DOWN' then
		nextIndex = math.min(selectedIndex + 1, numDescriptions)
	else
		nextIndex = math.max(selectedIndex - 1, 1)
	end

	if nextIndex == selectedIndex then
		return nil
	end

	return radioDescriptions[nextIndex]
end

local function StepOpenDropdown(key)
	if key ~= 'UP' and key ~= 'DOWN' and key ~= 'LEFT' and key ~= 'RIGHT' then
		return false
	end

	if not Menu or not Menu.GetManager then
		return false
	end

	local manager = Menu.GetManager()
	if not manager or not manager:IsAnyMenuOpen() then
		return false
	end

	if key ~= 'UP' and key ~= 'DOWN' then
		return true
	end

	local menu = manager:GetOpenMenu()
	if not menu then
		return true
	end

	local owner = menu.GetOwnerRegion and menu:GetOwnerRegion()
	if owner then
		PickDropdownRadio(menu, owner, GetDropdownStepDescription(owner, key))
	end

	return true
end

function dialogMixin:OnKeyDown(key)
	if InCombatLockdown() then
		return
	end

	if StepOpenDropdown(key) then
		self:SetPropagateKeyboardInput(false) -- protected
		return
	end

	if self.selection then
		self:SetPropagateKeyboardInput(false) -- protected

		if key == 'LEFT' then
			internal:MoveParent(self.selection, IsShiftKeyDown() and -BIG_STEP or -SMALL_STEP)
		elseif key == 'RIGHT' then
			internal:MoveParent(self.selection, IsShiftKeyDown() and BIG_STEP or SMALL_STEP)
		elseif key == 'UP' then
			internal:MoveParent(self.selection, 0, IsShiftKeyDown() and BIG_STEP or SMALL_STEP)
		elseif key == 'DOWN' then
			internal:MoveParent(self.selection, 0, IsShiftKeyDown() and -BIG_STEP or -SMALL_STEP)
		else
			self:SetPropagateKeyboardInput(true) -- protected
		end
	else
		self:SetPropagateKeyboardInput(true) -- protected
	end
end

function internal:CreateDialog()
	local dialog = Mixin(CreateFrame('Frame', nil, UIParent, 'DefaultPanelFlatTemplate'), dialogMixin)
	dialog:SetSize(DIALOG_WIDTH, 350)
	dialog:SetFrameStrata('DIALOG')
	dialog:SetFrameLevel(200)
	dialog:Hide()

	dialog:Reset()

	-- make draggable
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:SetDontSavePosition(true)
	dialog:RegisterForDrag('LeftButton')
	dialog:SetScript('OnDragStart', dialog.StartMoving)
	dialog:SetScript('OnDragStop', dialog.StopMovingOrSizing)
	dialog:SetScript('OnKeyDown', dialog.OnKeyDown)

	local dialogClose = CreateFrame('Button', nil, dialog, 'UIPanelCloseButtonDefaultAnchors')
	dialogClose:SetFrameLevel(dialog.TitleContainer:GetFrameLevel() + 1)
	dialogClose:HookScript('OnClick', function()
		dialog:Reset()
	end)
	dialog.Close = dialogClose

	local settingsScroll = CreateFrame('ScrollFrame', nil, dialog, 'UIPanelScrollFrameTemplate')
	settingsScroll:SetPoint('TOPLEFT', dialog.Bg, 'TOPLEFT', DIALOG_PADDING, -DIALOG_PADDING)
	settingsScroll:SetWidth(SETTINGS_CONTENT_WIDTH)
	settingsScroll:EnableMouseWheel(true)
	settingsScroll.scrollBarHideable = true
	settingsScroll.ScrollBar.scrollStep = 32
	settingsScroll.ScrollBar:Hide()
	dialog.SettingsScroll = settingsScroll

	local dialogSettings = CreateFrame('Frame', nil, settingsScroll, 'VerticalLayoutFrame')
	dialogSettings:SetFixedWidth(SETTINGS_CONTENT_WIDTH)
	dialogSettings.spacing = 2
	settingsScroll:SetScrollChild(dialogSettings)
	dialog.Settings = dialogSettings

	local resetSettingsButton = CreateFrame('Button', nil, dialogSettings, 'EditModeSystemSettingsDialogButtonTemplate')
	resetSettingsButton:SetWidth(SETTINGS_CONTENT_WIDTH)
	resetSettingsButton:SetText(RESET_TO_DEFAULT)
	resetSettingsButton:SetOnClickHandler(GenerateClosure(dialog.ResetSettings, dialog))
	dialogSettings.ResetButton = resetSettingsButton

	local footerDivider = dialog:CreateTexture(nil, 'ARTWORK')
	footerDivider:SetPoint('TOPLEFT', settingsScroll, 'BOTTOMLEFT', 0, -FOOTER_DIVIDER_GAP)
	footerDivider:SetSize(SETTINGS_CONTAINER_WIDTH, FOOTER_DIVIDER_HEIGHT)
	footerDivider:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
	dialog.FooterDivider = footerDivider

	local dialogButtons = CreateFrame('Frame', nil, dialog, 'VerticalLayoutFrame')
	dialogButtons:SetPoint(
		'TOPLEFT',
		footerDivider,
		'BOTTOMLEFT',
		0,
		-FOOTER_DIVIDER_GAP
	)
	dialogButtons:SetFixedWidth(SETTINGS_CONTAINER_WIDTH)
	dialogButtons.spacing = 2
	dialog.Buttons = dialogButtons

	return dialog
end
