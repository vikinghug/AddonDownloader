require "Apollo"
require "GameLib"
require "Item"
require "Window"
require "Money"

local VikingInventoryBag = {}
local knSmallIconOption = 42
local knLargeIconOption = 48
local knMaxBags = 4 -- how many bags can the player have
local knSaveVersion = 3

local karCurrency =  	-- Alt currency table; re-indexing the enums so they don't have to be in sequence code-side (and removing cash)
{						-- To add a new currency just add an entry to the table; the UI will do the rest. Idx == 1 will be the default one shown
	{eType = Money.CodeEnumCurrencyType.Renown, 			strTitle = Apollo.GetString("CRB_Renown"), 				strDescription = Apollo.GetString("CRB_Renown_Desc")},
	{eType = Money.CodeEnumCurrencyType.ElderGems, 			strTitle = Apollo.GetString("CRB_Elder_Gems"), 			strDescription = Apollo.GetString("CRB_Elder_Gems_Desc")},
	{eType = Money.CodeEnumCurrencyType.Prestige, 			strTitle = Apollo.GetString("CRB_Prestige"), 			strDescription = Apollo.GetString("CRB_Prestige_Desc")},
	{eType = Money.CodeEnumCurrencyType.CraftingVouchers, 	strTitle = Apollo.GetString("CRB_Crafting_Vouchers"), 	strDescription = Apollo.GetString("CRB_Crafting_Voucher_Desc")}
}

function VikingInventoryBag:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	o.bShouldSortItems = false
	o.nSortItemType = 1
	
	return o
end

function VikingInventoryBag:Init()
    Apollo.RegisterAddon(self)
end

function VikingInventoryBag:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		return {
			nSaveVersion = knSaveVersion,
			bShouldSortItems = self.bShouldSortItems,
			nSortItemType = self.nSortItemType,
		}
	end
	
	return nil
end

function VikingInventoryBag:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Account then
		self.tSavedData = tSavedData
		
		if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
			return
		end
	elseif eType == GameLib.CodeEnumAddonSaveLevel.Character  then
		if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
			return
		end
	
		self.bShouldSortItems = tSavedData.bShouldSortItems or false
		self.nSortItemType = tSavedData.nSortItemType or 1
		
		if self.wndMain then
			self.wndMainBagWindow:SetSort(self.bShouldSortItems)
			self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortOff"):SetCheck(not self.bShouldSortItems)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortAlpha"):SetCheck(self.bShouldSortItems and self.nSortItemType == 1)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortCategory"):SetCheck(self.bShouldSortItems and self.nSortItemType == 2)
			self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:ItemSortPrompt:IconBtnSortQuality"):SetCheck(self.bShouldSortItems and self.nSortItemType == 3)
		end
	end
end


function VikingInventoryBag:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingInventoryBag.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

local fnSortItemsByName = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end
	
	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end
	
	return 0
end

local fnSortItemsByCategory = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end
	
	local strLeftName = itemLeft:GetItemCategoryName()
	local strRightName = itemRight:GetItemCategoryName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end
	
	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end
	
	return 0
end

local fnSortItemsByQuality = function(itemLeft, itemRight)
	if itemLeft == itemRight then
		return 0
	end
	if itemLeft and itemRight == nil then
		return -1
	end
	if itemLeft == nil and itemRight then
		return 1
	end
	
	local eLeftQuality = itemLeft:GetItemQuality()
	local eRightQuality = itemRight:GetItemQuality()
	if eLeftQuality > eRightQuality then
		return -1
	end
	if eLeftQuality < eRightQuality then
		return 1
	end
	
	local strLeftName = itemLeft:GetName()
	local strRightName = itemRight:GetName()
	if strLeftName < strRightName then
		return -1
	end
	if strLeftName > strRightName then
		return 1
	end
	
	return 0
end

local ktSortFunctions = {fnSortItemsByName, fnSortItemsByCategory, fnSortItemsByQuality}

-- TODO: Mark items as viewed
function VikingInventoryBag:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 				"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 					"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("InterfaceMenu_ToggleInventory", 			"OnToggleVisibility", self) -- TODO: The datachron attachment needs to be brought over
	Apollo.RegisterEventHandler("GuildBank_ShowPersonalInventory", 			"OnToggleVisibilityAlways", self)

	Apollo.RegisterEventHandler("PersonaUpdateCharacterStats", 				"UpdateBagSlotItems", self) -- using this for bag changes
	Apollo.RegisterEventHandler("PlayerPathMissionUpdate", 					"OnQuestObjectiveUpdated", self) -- route to same event
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 					"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("PlayerPathRefresh", 						"OnQuestObjectiveUpdated", self) -- route to same event
	Apollo.RegisterEventHandler("QuestStateChanged", 						"OnQuestObjectiveUpdated", self)
	Apollo.RegisterEventHandler("ToggleInventory", 							"OnToggleVisibility", self) -- todo: figure out if show inventory is needed
	Apollo.RegisterEventHandler("ShowInventory", 							"OnToggleVisibility", self)
	Apollo.RegisterEventHandler("SplitItemStack", 							"OnSplitItemStack", self)
	Apollo.RegisterEventHandler("ChallengeUpdated", 						"OnChallengeUpdated", self)
	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)

	Apollo.RegisterEventHandler("PlayerCurrencyChanged",					"OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("PlayerTitleChange", 						"UpdateTitle", self)
	
	Apollo.RegisterEventHandler("LevelUpUnlock_Inventory_Salvage", "OnLevelUpUnlock_Inventory_Salvage", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Path_Item", "OnLevelUpUnlock_Path_Item", self)

	--Apollo.RegisterTimerHandler("InventoryUpdateTimer", 					"OnUpdateTimer", self)
	--Apollo.CreateTimer("InventoryUpdateTimer", 1.0, true)
	--Apollo.StopTimer("InventoryUpdateTimer")

	-- TODO Refactor: Investigate these two, we may not need them if we can detect the origin window of a drag
	Apollo.RegisterEventHandler("DragDropSysBegin", "OnSystemBeginDragDrop", self)
	Apollo.RegisterEventHandler("DragDropSysEnd", 	"OnSystemEndDragDrop", self)

	self.wndDeleteConfirm 	= Apollo.LoadForm(self.xmlDoc, "InventoryDeleteNotice", nil, self)
	self.wndSalvageConfirm 	= Apollo.LoadForm(self.xmlDoc, "InventorySalvageNotice", nil, self)
	self.wndMain 			= Apollo.LoadForm(self.xmlDoc, "VikingInventoryBag", nil, self)
	self.wndMain:FindChild("VirtualInvToggleBtn"):AttachWindow(self.wndMain:FindChild("VirtualInvContainer"))
	self.wndMain:Show(false, true)
	self.wndSalvageConfirm:Show(false, true)
	self.wndDeleteConfirm:Show(false, true)

	-- Variables
	self.nBoxSize = knLargeIconOption
	self.bFirstLoad = true
	self.nLastBagMaxSize = 0
	self.nLastWndMainWidth = self.wndMain:GetWidth()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.nFirstEverWidth = nRight - nLeft
	self.wndMain:SetSizingMinimum(238, 270)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("MainGridContainer"):GetAnchorOffsets()
	self.nFirstEverMainGridHeight = nBottom - nTop

	self.tBagSlots = {}
	self.tBagCounts = {}
	for idx = 1, knMaxBags do
		self.tBagSlots[idx] = self.wndMain:FindChild("BagBtn" .. idx)
		self.tBagCounts[idx] = self.wndMain:FindChild("BagCount" .. idx)
	end

	self.nEquippedBagCount = 0 -- used to identify bag updates

	self:UpdateSquareSize()

	--Alt Curency Display
	for idx = 1, #karCurrency do
		local tData = karCurrency[idx]
		local wnd = Apollo.LoadForm(self.xmlDoc, "PickerEntry", self.wndMain:FindChild("OptionsConfigureCurrencyList"), self)
		wnd:FindChild("EntryCash"):SetMoneySystem(tData.eType) -- We'll fill in the amount during the timer
		wnd:FindChild("PickerEntryBtn"):SetData(idx)
		wnd:FindChild("PickerEntryBtn"):SetCheck(idx == 1)
		wnd:FindChild("PickerEntryBtnText"):SetText(tData.strTitle)
		wnd:FindChild("PickerEntryBtn"):SetTooltip(tData.strDescription)
		tData.wnd = wnd
	end
	self.wndMain:FindChild("OptionsConfigureCurrencyList"):ArrangeChildrenVert(0)

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.wndMainBagWindow = self.wndMain:FindChild("MainBagWindow")
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortOff"):SetCheck(not self.bShouldSortItems)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortAlpha"):SetCheck(self.bShouldSortItems and self.nSortItemType == 1)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortCategory"):SetCheck(self.bShouldSortItems and self.nSortItemType == 2)
	self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown:ItemSortPrompt:IconBtnSortQuality"):SetCheck(self.bShouldSortItems and self.nSortItemType == 3)
	
	self.wndIconBtnSortDropDown = self.wndMain:FindChild("OptionsContainer:OptionsContainerFrame:OptionsConfigureSort:IconBtnSortDropDown")
	self.wndIconBtnSortDropDown:AttachWindow(self.wndIconBtnSortDropDown:FindChild("ItemSortPrompt"))
end

function VikingInventoryBag:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Inventory"), {"InterfaceMenu_ToggleInventory", "Inventory", "Icon_Windows32_UI_CRB_InterfaceMenu_Inventory"})
end

function VikingInventoryBag:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_Inventory")})
end
	
function VikingInventoryBag:OnCharacterCreated()
	self:OnPlayerCurrencyChanged()
	self:UpdateTitle()
end

function VikingInventoryBag:OnToggleVisibility()
	if self.wndMain:IsShown() then
		self.wndMain:Close()
		Sound.Play(Sound.PlayUIBagClose)
		Apollo.StopTimer("InventoryUpdateTimer")
	else
		self.wndMain:Show(true)
		self.wndMain:ToFront()
		Sound.Play(Sound.PlayUIBagOpen)
		Apollo.StartTimer("InventoryUpdateTimer")
	end
	self.wndMain:ToFront()

	if self.bFirstLoad then
		self.bFirstLoad = false
	end

	if self.wndMain:IsShown() then
		self:UpdateSquareSize()
		self:UpdateBagSlotItems()
		self:OnQuestObjectiveUpdated() -- Populate Virtual Inventory Btn from reloadui/load
	end
end

function VikingInventoryBag:OnToggleVisibilityAlways()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	Apollo.StartTimer("InventoryUpdateTimer")
	self.wndMain:ToFront()

	if self.bFirstLoad then
		self.bFirstLoad = false
	end

	if self.wndMain:IsShown() then
		self:UpdateSquareSize()
		self:UpdateBagSlotItems()
		self:OnQuestObjectiveUpdated() -- Populate Virtual Inventory Btn from reloadui/load
	end
end

function VikingInventoryBag:OnLevelUpUnlock_Inventory_Salvage()
	self:OnToggleVisibilityAlways()
end

function VikingInventoryBag:OnLevelUpUnlock_Path_Item(itemFromPath)
	self:OnToggleVisibilityAlways()
end

-----------------------------------------------------------------------------------------------
-- Main Update Timer
-----------------------------------------------------------------------------------------------
function VikingInventoryBag:OnInventoryClosed( wndHandler, wndControl )
	self.wndMain:FindChild("MainBagWindow"):MarkAllItemsAsSeen()
end

function VikingInventoryBag:OnPlayerCurrencyChanged()
	self.wndMain:FindChild("MainCashWindow"):SetAmount(GameLib.GetPlayerCurrency(), true)
		--Alt Currency stuff
	for key, wndCurr in pairs(self.wndMain:FindChild("OptionsConfigureCurrencyList"):GetChildren()) do
		self:UpdateAltCash(wndCurr)
	end
end

function VikingInventoryBag:UpdateTitle()
	self.wndMain:FindChild("InventoryTitleText"):SetText(String_GetWeaselString(Apollo.GetString("Inventory_TitleText"), GameLib.GetPlayerUnit()))
end

function VikingInventoryBag:UpdateBagSlotItems() -- update our bag display
	local strEmptyBag = Apollo.GetString("Inventory_EmptySlot")
	local nOldBagCount = self.nEquippedBagCount -- record the old count

	self.nEquippedBagCount = 0	-- reset

	for idx = 1, knMaxBags do
		local itemBag = self.wndMain:FindChild("MainBagWindow"):GetBagItem(idx)
		local wndCtrl = self.wndMain:FindChild("BagBtn"..idx)
		if itemBag then
			self.tBagCounts[idx]:SetText("+" .. itemBag:GetBagSlots())
			wndCtrl:FindChild("RemoveBagIcon"):Show(true)
			wndCtrl:FindChild("RemoveBagIcon"):SetData(itemBag)
			self.nEquippedBagCount = self.nEquippedBagCount + 1
			Tooltip.GetItemTooltipForm(self, self.wndMain:FindChild("BagBtn"..idx), itemBag, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		else
			self.tBagCounts[idx]:SetText("")
			wndCtrl:SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"white\">%s</T>", strEmptyBag))
			wndCtrl:FindChild("RemoveBagIcon"):Show(false)
		end
	end

	if self.nEquippedBagCount ~= nOldBagCount then --flash the config icon
		self.wndMain:FindChild("OptionsBtnFlash"):SetSprite("CRB_Basekit:kitAccent_Glow_BlueFlash")
	end
end

function VikingInventoryBag:OnBagBtnMouseEnter(wndHandler, wndControl)	
end

function VikingInventoryBag:OnBagBtnMouseExit(wndHandler, wndControl)
end

-----------------------------------------------------------------------------------------------
-- Drawing Bag Slots
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnMainWindowMouseResized()
	self:UpdateSquareSize()
	self.wndMain:FindChild("VirtualInvItems"):ArrangeChildrenHorz(1)
end

function VikingInventoryBag:UpdateSquareSize()
	if not self.wndMain then
		return
	end

	local wndBag = self.wndMain:FindChild("MainBagWindow")
	wndBag:SetSquareSize(self.nBoxSize, self.nBoxSize)

end

-----------------------------------------------------------------------------------------------
-- Options
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnBGBottomCashBtnToggle(wndHandler, wndControl)
	self.wndMain:FindChild("OptionsBtn"):SetCheck(wndHandler:IsChecked())
	self:OnOptionsMenuToggle()
end

function VikingInventoryBag:OnOptionsMenuToggle(wndHandler, wndControl) -- OptionsBtn
	self.wndMain:FindChild("BGBottomCashBtn"):SetCheck(self.wndMain:FindChild("OptionsBtn"):IsChecked())
	self.wndMain:FindChild("OptionsContainer"):Show(self.wndMain:FindChild("OptionsBtn"):IsChecked())

	for idx = 1,4 do
		self.wndMain:FindChild("BagBtn" .. idx):FindChild("RemoveBagIcon"):Show(false)
	end

	self.wndMain:FindChild("IconBtnLarge"):SetCheck(self.nBoxSize == kLargeIconOption)
	self.wndMain:FindChild("IconBtnSmall"):SetCheck(self.nBoxSize == kSmallIconOption)
	
	for key, wndCurr in pairs(self.wndMain:FindChild("OptionsConfigureCurrencyList"):GetChildren()) do
		self:UpdateAltCash(wndCurr)
	end
end

function VikingInventoryBag:OnOptionsCloseClick()
	self.wndMain:FindChild("BGBottomCashBtn"):SetCheck(false)
	self.wndMain:FindChild("OptionsBtn"):SetCheck(false)
	self:OnOptionsMenuToggle()
end

function VikingInventoryBag:OnOptionsAddSizeRows()
	if self.nBoxSize == knSmallIconOption then
		self.nBoxSize = knLargeIconOption
		self:OnMainWindowMouseResized()
		self:UpdateSquareSize()
	end
end

function VikingInventoryBag:OnOptionsRemoveSizeRows()
	if self.nBoxSize == knLargeIconOption then
		self.nBoxSize = knSmallIconOption
		self:OnMainWindowMouseResized()
		self:UpdateSquareSize()
	end
end

-----------------------------------------------------------------------------------------------
-- Alt Currency Window Functions
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:UpdateAltCash(wndHandler, wndControl) -- Also from PickerEntryBtn
	local tData = karCurrency[wndHandler:FindChild("PickerEntryBtn"):GetData()]

	if wndHandler:FindChild("PickerEntryBtn"):IsChecked() then
		self.wndMain:FindChild("AltCashWindow"):SetMoneySystem(tData.eType)
		self.wndMain:FindChild("AltCashWindow"):SetAmount(GameLib.GetPlayerCurrency(tData.eType):GetAmount(), true)
		self.wndMain:FindChild("AltCashWindow"):SetTooltip(String_GetWeaselString(Apollo.GetString("Inventory_MoneyTooltip"), tData.strDescription))
		self.wndMain:FindChild("MainCashWindow"):SetTooltip(String_GetWeaselString(Apollo.GetString("Inventory_MoneyTooltip"), tData.strDescription))
	end

	if self.wndMain:FindChild("OptionsBtn"):IsChecked() then
		tData.wnd:FindChild("EntryCash"):SetAmount(GameLib.GetPlayerCurrency(tData.eType):GetAmount(), true)
	end
end

-----------------------------------------------------------------------------------------------
-- Supply Satchel
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnToggleSupplySatchel(wndHandler, wndControl)
	--ToggleTradeSkillsInventory()
	local tAnchors = {}
	tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom = self.wndMain:GetAnchorOffsets()
	Event_FireGenericEvent("ToggleTradeskillInventoryFromBag", tAnchors)
end

-----------------------------------------------------------------------------------------------
-- Salvage All
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnSalvageAllBtn(wndHandler, wndControl)
	Event_FireGenericEvent("RequestSalvageAll", tAnchors)
end

function VikingInventoryBag:OnDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageAllBtn"):GetData() then
		self:InvokeSalvageConfirmWindow(iData)
	end
	return false
end

function VikingInventoryBag:OnQueryDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageAllBtn"):GetData() then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function VikingInventoryBag:OnDragDropNotifySalvage(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe and self.wndMain:FindChild("SalvageIcon"):GetData() then
		--self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageToggleFlyby")
		--self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(true)
	elseif self.wndMain:FindChild("SalvageIcon"):GetData() then
		--self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageTogglePressed")
		--self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	end
end

-----------------------------------------------------------------------------------------------
-- Virtual Inventory
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnQuestObjectiveUpdated()
	self:UpdateVirtualItemInventory()
end

function VikingInventoryBag:OnChallengeUpdated()
	self:UpdateVirtualItemInventory()
end

function VikingInventoryBag:UpdateVirtualItemInventory()
	local tVirtualItems = Item.GetVirtualItems()
	local bThereAreItems = #tVirtualItems > 0

	self.wndMain:FindChild("VirtualInvToggleBtn"):Show(bThereAreItems)
	self.wndMain:FindChild("VirtualInvContainer"):SetData(#tVirtualItems)
	self.wndMain:FindChild("VirtualInvContainer"):Show(self.wndMain:FindChild("VirtualInvToggleBtn"):IsChecked())

	if not bThereAreItems then
		self.wndMain:FindChild("VirtualInvToggleBtn"):SetCheck(false)
		self.wndMain:FindChild("VirtualInvContainer"):Show(false)
	elseif self.wndMain:FindChild("VirtualInvContainer"):GetData() == 0 then
		self.wndMain:FindChild("VirtualInvToggleBtn"):SetCheck(true)
		self.wndMain:FindChild("VirtualInvContainer"):Show(true)
	end

	-- Draw items
	self.wndMain:FindChild("VirtualInvItems"):DestroyChildren()
	local nOnGoingCount = 0
	for key, tCurrItem in pairs(tVirtualItems) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "VirtualItem", self.wndMain:FindChild("VirtualInvItems"), self)
		if tCurrItem.nCount > 1 then
			wndCurr:FindChild("VirtualItemCount"):SetText(tCurrItem.nCount)
		end
		nOnGoingCount = nOnGoingCount + tCurrItem.nCount
		wndCurr:FindChild("VirtualItemDisplay"):SetSprite(tCurrItem.strIcon)
		wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\">%s</P><P Font=\"CRB_InterfaceSmall\" TextColor=\"aaaaaaaa\">%s</P>", tCurrItem.strName, tCurrItem.strFlavor))
	end
	self.wndMain:FindChild("VirtualInvToggleBtn"):SetText(String_GetWeaselString(Apollo.GetString("Inventory_VirtualInvBtn"), nOnGoingCount))
	self.wndMain:FindChild("VirtualInvItems"):ArrangeChildrenHorz(1)

	-- Adjust heights
	local bShowQuestItems = self.wndMain:FindChild("VirtualInvToggleBtn"):IsChecked()
	if not self.nVirtualButtonHeight then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("VirtualInvToggleBtn"):GetAnchorOffsets()
		self.nVirtualButtonHeight = nBottom - nTop
	end
	if not self.nQuestItemContainerHeight then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("VirtualInvContainer"):GetAnchorOffsets()
		self.nQuestItemContainerHeight = nBottom - nTop
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("BGVirtual"):GetAnchorOffsets()
	nTop = nBottom 
	if bThereAreItems then
		nTop = nBottom - self.nVirtualButtonHeight
		if bShowQuestItems then
			nTop = nTop - self.nQuestItemContainerHeight
		end
	end
	self.wndMain:FindChild("BGVirtual"):SetAnchorOffsets(nLeft, nTop, nRight, nBottom)

	local nBagLeft, nBagTop, nBagRight, nBagBottom = self.wndMain:FindChild("BGGridArt"):GetAnchorOffsets()
	self.wndMain:FindChild("BGGridArt"):SetAnchorOffsets(nBagLeft, nBagTop, nBagRight, nTop)
end

-----------------------------------------------------------------------------------------------
-- Drag and Drop
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnBagDragDropCancel(wndHandler, wndControl, strType, iData, eReason)
	if strType ~= "DDBagItem" or eReason == Apollo.DragDropCancelReason.EscapeKey or eReason == Apollo.DragDropCancelReason.ClickedOnNothing then
		return false
	end

	if eReason == Apollo.DragDropCancelReason.ClickedOnWorld or eReason == Apollo.DragDropCancelReason.DroppedOnNothing then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end

-- Trash Icon
function VikingInventoryBag:OnDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" then
		self:InvokeDeleteConfirmWindow(iData)
	end
	return false
end

function VikingInventoryBag:OnQueryDragDropTrash(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function VikingInventoryBag:OnDragDropNotifyTrash(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe then
		self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashToggleFlyby")
		self.wndMain:FindChild("TextActionPrompt_Trash"):Show(true)
	else
		self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashTogglePressed")
		self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	end
end
-- End Trash Icon

-- Salvage Icon
function VikingInventoryBag:OnDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageIcon"):GetData() then
		self:InvokeSalvageConfirmWindow(iData)
	end
	return false
end

function VikingInventoryBag:OnQueryDragDropSalvage(wndHandler, wndControl, nX, nY, wndSource, strType, iData)
	if strType == "DDBagItem" and self.wndMain:FindChild("SalvageIcon"):GetData() then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Ignore
end

function VikingInventoryBag:OnDragDropNotifySalvage(wndHandler, wndControl, bMe) -- TODO: We can probably replace this with a button mouse over state
	if bMe and self.wndMain:FindChild("SalvageIcon"):GetData() then
		self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageToggleFlyby")
		self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(true)
	elseif self.wndMain:FindChild("SalvageIcon"):GetData() then
		self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageTogglePressed")
		self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	end
end
-- End Salvage Icon

function VikingInventoryBag:OnSystemBeginDragDrop(wndSource, strType, iData)
	if strType ~= "DDBagItem" then return end
	self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)

	self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashTogglePressed")

	local item = self.wndMain:FindChild("MainBagWindow"):GetItem(iData)
	if item and item:CanSalvage() then
		self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageTogglePressed")
		self.wndMain:FindChild("SalvageIcon"):SetData(true)
	else
		self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageToggleDisabled")
	end

	Sound.Play(Sound.PlayUI45LiftVirtual)
end

function VikingInventoryBag:OnSystemEndDragDrop(strType, iData)
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:FindChild("TrashIcon") or strType == "DDGuildBankItem" or strType == "DDWarPartyBankItem" or strType == "DDGuildBankItemSplitStack" then
		return -- TODO Investigate if there are other types
	end

	self.wndMain:FindChild("TrashIcon"):SetSprite("CRB_Inventory:InvBtn_TrashToggleNormal")
	self.wndMain:FindChild("SalvageIcon"):SetSprite("CRB_Inventory:InvBtn_SalvageToggleNormal")
	self.wndMain:FindChild("SalvageIcon"):SetData(false)
	self.wndMain:FindChild("TextActionPrompt_Trash"):Show(false)
	self.wndMain:FindChild("TextActionPrompt_Salvage"):Show(false)
	self:UpdateSquareSize()
	Sound.Play(Sound.PlayUI46PlaceVirtual)
end

-----------------------------------------------------------------------------------------------
-- Item Sorting
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnOptionsSortItemsOff(wndHandler, wndControl)
	self.bShouldSortItems = false
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function VikingInventoryBag:OnOptionsSortItemsName(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 1
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function VikingInventoryBag:OnOptionsSortItemsByCategory(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 2
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

function VikingInventoryBag:OnOptionsSortItemsByQuality(wndHandler, wndControl)
	self.bShouldSortItems = true
	self.nSortItemType = 3
	self.wndMainBagWindow:SetSort(self.bShouldSortItems)
	self.wndMainBagWindow:SetItemSortComparer(ktSortFunctions[self.nSortItemType])
	self.wndIconBtnSortDropDown:SetCheck(false)
end

-----------------------------------------------------------------------------------------------
-- Delete/Salvage Screen
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:InvokeDeleteConfirmWindow(iData) 
	local itemData = Item.GetItemFromInventoryLoc(iData)
	if itemData and not itemData:CanDelete() then
		return
	end
	self.wndDeleteConfirm:SetData(iData)
	self.wndDeleteConfirm:Show(true)
	self.wndDeleteConfirm:ToFront()
	self.wndDeleteConfirm:FindChild("DeleteBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.DeleteItem, iData)
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(true)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

function VikingInventoryBag:InvokeSalvageConfirmWindow(iData)
	self.wndSalvageConfirm:SetData(iData)
	self.wndSalvageConfirm:Show(true)
	self.wndSalvageConfirm:ToFront()
	self.wndSalvageConfirm:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, iData)
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(true)
	Sound.Play(Sound.PlayUI55ErrorVirtual)
end

-- TODO SECURITY: These confirmations are entirely a UI concept. Code should have a allow/disallow.
function VikingInventoryBag:OnDeleteCancel()
	self.wndDeleteConfirm:SetData(nil)
	self.wndDeleteConfirm:Close()
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(false)
end

function VikingInventoryBag:OnSalvageCancel()
	self.wndSalvageConfirm:SetData(nil)
	self.wndSalvageConfirm:Close()
	self.wndMain:FindChild("DragDropMouseBlocker"):Show(false)
end

function VikingInventoryBag:OnDeleteConfirm()
	self:OnDeleteCancel()
end

function VikingInventoryBag:OnSalvageConfirm()
	self:OnSalvageCancel()
end

-----------------------------------------------------------------------------------------------
-- Stack Splitting
-----------------------------------------------------------------------------------------------

function VikingInventoryBag:OnSplitItemStack(item)
	if not item then return end
	local wndSplit = self.wndMain:FindChild("SplitStackContainer")
	local nStackCount = item:GetStackCount()
	if nStackCount < 2 then
		wndSplit:Show(false)
		return
	end
	wndSplit:SetData(item)
	wndSplit:FindChild("SplitValue"):SetValue(1)
	wndSplit:FindChild("SplitValue"):SetMinMax(1, nStackCount - 1)
	wndSplit:Show(true)
end

function VikingInventoryBag:OnSplitStackCloseClick()
	self.wndMain:FindChild("SplitStackContainer"):Show(false)
end

function VikingInventoryBag:OnSplitStackConfirm(wndHandler, wndCtrl)
	local wndSplit = self.wndMain:FindChild("SplitStackContainer")
	local tItem = wndSplit:GetData()
	wndSplit:Show(false)
	self.wndMain:FindChild("MainBagWindow"):StartSplitStack(tItem, wndSplit:FindChild("SplitValue"):GetValue())
end

function VikingInventoryBag:OnGenerateTooltip(wndControl, wndHandler, tType, item)
	if wndControl ~= wndHandler then return end
	wndControl:SetTooltipDoc(nil)
	if item ~= nil then
		local itemEquipped = item:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, item, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		-- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
	end
end

local InventoryBagInst = VikingInventoryBag:new()
InventoryBagInst:Init()
