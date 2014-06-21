require "Window"
require "GameLib"
require "Item"

-----------------------------------------------------------------------------------------------
-- ItemPreview Module Definition
-----------------------------------------------------------------------------------------------
local VikingItemPreview = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktVisibleSlots = 
{
	2,
	3,
	0,
	5,
	1,
	4,
	16
}

local knSaveVersion

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function VikingItemPreview:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function VikingItemPreview:Init()
    Apollo.RegisterAddon(self)
end

function VikingItemPreview:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc

	local tSaved =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion
	}
	
	return tSaved
end

function VikingItemPreview:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end


-----------------------------------------------------------------------------------------------
-- ItemPreview OnLoad
-----------------------------------------------------------------------------------------------
function VikingItemPreview:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingItemPreview.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function VikingItemPreview:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	Apollo.RegisterEventHandler("ShowItemInDressingRoom", "OnShowItemInDressingRoom", self)
	self.bSheathed = false
end


-----------------------------------------------------------------------------------------------
-- ItemPreview Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here
function VikingItemPreview:OnShowItemInDressingRoom(item)
	if self.wndMain ~= nil then
		self:OnWindowClosed()
	end

	if item == nil or not self:HelperValidateSlot(item) then
		return
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "VikingItemPreviewForm", "TooltipStratum", self)
	local nWndLeft, nWndTop, nWndRight, nWndBottom = self.wndMain:GetRect()
	local nWndWidth = nWndRight - nWndLeft
	local nWndHeight = nWndBottom - nWndTop

	self.wndMain:SetSizingMinimum(nWndWidth - 10, nWndHeight - 10)
	self.wndMain:FindChild("PreviewWindow"):SetCostume(GameLib.GetPlayerUnit())
	self.wndMain:FindChild("PreviewWindow"):SetItem(item)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end


	-- set item name;
	--local strLabel = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\" Align=\"Center\">%s</T>", Apollo.GetString("Inventory_ItemPreviewLabel"))
	local strItem = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloTitle\" Align=\"Center\">%s</T>", item:GetName())
	self.wndMain:FindChild("ItemLabel"):SetAML("<P Align=\"Center\">"..String_GetWeaselString(strItem).."</P>")

	-- set sheathed or not
	local eItemType = item:GetItemType()
	self.bSheathed = not self:HelperCheckForWeapon(eItemType)

	self.wndMain:FindChild("PreviewWindow"):SetSheathed(self.bSheathed)
	self:HelperFormatSheathButton(self.bSheathed)

	self.wndMain:Show(true)
end

function VikingItemPreview:HelperCheckForWeapon(eItemType)
	local bIsWeapon = false

	if eItemType >= Item.CodeEnumItemType.WeaponMHPistols and eItemType <= Item.CodeEnumItemType.WeaponMHSword then
		bIsWeapon = true
	end

	return bIsWeapon
end

function VikingItemPreview:HelperFormatSheathButton(bSheathed)
	if bSheathed == true then
		self.wndMain:FindChild("SheathButton"):SetText(Apollo.GetString("Inventory_DrawWeapons"))
	else
		self.wndMain:FindChild("SheathButton"):SetText(Apollo.GetString("Inventory_Sheathe"))
	end
end

function VikingItemPreview:HelperValidateSlot(item)
	local bVisibleSlot = false
	local bRightClassOrProf = false
	local tProficiency = item:GetProficiencyInfo()
	local arReqClass = item:GetRequiredClass()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bCanEquip = item:CanEquip()

    if #arReqClass > 0 then
		for idx,tClass in ipairs(arReqClass) do
			if tClass.idClassReq == unitPlayer:GetClassId() then
				bRightClassOrProf = true
			end
		end
	elseif tProficiency then
		bRightClassOrProf = tProficiency.bHasProficiency
	elseif bCanEquip then
		bRightClassOrProf = true
	end

	for idx, nSlot in pairs(ktVisibleSlots) do
		if item:GetSlot() and item:GetSlot() == nSlot then
			bVisibleSlot = bRightClassOrProf
			break
		end

	end

	return bVisibleSlot
end

-----------------------------------------------------------------------------------------------
-- ItemPreviewForm Functions
-----------------------------------------------------------------------------------------------
function VikingItemPreview:OnWindowClosed( wndHandler, wndControl )
	if self.wndMain ~= nil then
		--self.wndMain:Close()
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function VikingItemPreview:OnToggleSheathButton( wndHandler, wndControl, eMouseButton )
	local bWeapon = wndControl:IsChecked()
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(bWeapon)
end

function VikingItemPreview:OnCloseBtn( wndHandler, wndControl, eMouseButton )
	self:OnWindowClosed()
end

function VikingItemPreview:OnToggleSheathed( wndHandler, wndControl, eMouseButton )
	local bSheathed = not self.bSheathed
	self.wndMain:FindChild("PreviewWindow"):SetSheathed(bSheathed)
	self:HelperFormatSheathButton(bSheathed)

	self.bSheathed = bSheathed
end

function VikingItemPreview:OnRotateRight()
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(true)
end

function VikingItemPreview:OnRotateRightCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleLeftSpin(false)
end

function VikingItemPreview:OnRotateLeft()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(true)
end

function VikingItemPreview:OnRotateLeftCancel()
	self.wndMain:FindChild("PreviewWindow"):ToggleRightSpin(false)
end

-----------------------------------------------------------------------------------------------
-- VikingItemPreview Instance
-----------------------------------------------------------------------------------------------
local ItemPreviewInst = VikingItemPreview:new()
ItemPreviewInst:Init()
