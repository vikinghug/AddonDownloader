require "Window"
require "Apollo"
require "ApolloCursor"
require "GameLib"
require "Item"

local VikingImprovedSalvage = {}

local kidBackpack = 0

function VikingImprovedSalvage:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function VikingImprovedSalvage:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingImprovedSalvage.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function VikingImprovedSalvage:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("RequestSalvageAll", "OnSalvageAll", self) -- using this for bag changes
	Apollo.RegisterSlashCommand("salvageall", "OnSalvageAll", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingImprovedSalvageForm", nil, self)
	self.xmlDoc = nil
	self.wndItemDisplay = self.wndMain:FindChild("ItemDisplayWindow")
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.tContents = self.wndMain:FindChild("HiddenBagWindow")
	self.arItemList = nil
	self.nItemIndex = nil

	self.wndMain:Show(false, true)
end

function VikingImprovedSalvage:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("CRB_Salvage")})
end

--------------------//-----------------------------
function VikingImprovedSalvage:OnSalvageAll()
	self.arItemList = {}
	self.nItemIndex = 1
	
	local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
	for idx, tItem in ipairs(tInvItems) do
		if tItem and tItem.itemInBag and tItem.itemInBag:CanSalvage() then
			table.insert(self.arItemList, tItem.itemInBag)
		end
	end

	self:RedrawAll()
end

function VikingImprovedSalvage:RedrawAll()
	local itemCurr = self.arItemList[self.nItemIndex]
	
	if itemCurr ~= nil then
		self:HelperBuildResultDisplay(self, self.wndItemDisplay, itemCurr )
		self.wndMain:SetData(itemCurr)
		self.wndMain:FindChild("SalvageBtn"):SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, itemCurr:GetInventoryId())
		self.wndMain:Show(true)
		self.wndMain:ToFront()
	else
		self.wndMain:Show(false)
	end
	
end

function VikingImprovedSalvage:HelperBuildResultDisplay(wndOwner, wndParent, itemCurr, itemModData )
	--local nVScrollPos = self.wndMain:FindChild("MainScroll"):GetVScrollPos()
	wndParent:DestroyChildren()
	
	local tResult = Tooltip.GetItemTooltipForm(wndOwner, wndParent, itemCurr, { bPermanent = true, wndParent = wndParent, bNotEquipped = true, bPrimary = true })
	local wndTooltip = nil
	if tResult ~= nil then
		if type(tResult) == 'table' then
			wndTooltip = tResult[0]
		elseif type(tResult) == 'userdata' then
			wndTooltip = tResult
		end
	end 
	if wndTooltip ~= nil then
		local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
		wndParent:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndTooltip:GetHeight())
		self.wndMain:FindChild("MainScroll"):SetVScrollPos(0)
		self.wndMain:FindChild("MainScroll"):RecalculateContentExtents()
	end
	
	--self.wndMain:FindChild("MainScroll"):SetVScrollPos(nVScrollPos)
	--self.wndMain:FindChild("MainScroll"):RecalculateContentExtents()
end


function VikingImprovedSalvage:OnSalvageNext()
	self.nItemIndex = self.nItemIndex + 1
	self:RedrawAll()
end

function VikingImprovedSalvage:OnSalvageCurr()
	self.nItemIndex = self.nItemIndex + 1
	self:RedrawAll()
end

function VikingImprovedSalvage:OnCloseBtn()
	self.arItemList = {}
	self.wndMain:SetData(nil)
	self.wndMain:Show(false)
end

----------------globals----------------------------

local VikingImprovedSalvage_Singleton = VikingImprovedSalvage:new()
Apollo.RegisterAddon(VikingImprovedSalvage_Singleton)
