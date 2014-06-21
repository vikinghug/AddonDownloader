-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingWarriorResource
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Unit"

local VikingWarriorResource = {}

function VikingWarriorResource:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function VikingWarriorResource:Init()
	Apollo.RegisterAddon(self, nil, nil, {"VikingActionBarFrame"})
end

function VikingWarriorResource:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingWarriorResource.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
end

function VikingWarriorResource:OnDocumentReady()
	self.bDocLoaded = true
	self:OnRequiredFlagsChanged()
end

function VikingWarriorResource:OnRequiredFlagsChanged()
	if g_wndActionBarResources and self.bDocLoaded then
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreate()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreate", self)
		end
	end
end

function VikingWarriorResource:OnCharacterCreate()
	local unitPlayer = GameLib:GetPlayerUnit()
	if unitPlayer:GetClassId() == GameLib.CodeEnumClass.Warrior then
		Apollo.RegisterTimerHandler("VikingWarriorResource_ChargeBarOverdriveTick", "OnVikingWarriorResource_ChargeBarOverdriveTick", self)
		Apollo.RegisterTimerHandler("VikingWarriorResource_ChargeBarOverdriveDone", "OnVikingWarriorResource_ChargeBarOverdriveDone", self)
		Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

		self.wndResourceBar = Apollo.LoadForm(self.xmlDoc, "VikingWarriorResourceForm", g_wndActionBarResources, self)
		self.wndResourceBar:FindChild("ChargeBarOverdriven"):SetMax(100)
		self.wndResourceBar:ToFront()

		self.nOverdriveTick = 0

		self.xmlDoc = nil
	end
end

function VikingWarriorResource:OnFrame(strName, nCnt)
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	elseif unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Warrior then
		if self.wndResourceBar then
			self.wndResourceBar:Show(false)
			self.wndResourceBar:Destroy()
		end
		return
	end

	if not self.wndResourceBar:IsValid() then
		return
	end

	local nLeft0, nTop0, nRight0, nBottom0 = self.wndResourceBar:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop0 - 15, true)

	local bOverdrive = GameLib.IsOverdriveActive()
	local nResourceCurr = unitPlayer:GetResource(1)
	local nResourceMax = unitPlayer:GetMaxResource(1)

	self.wndResourceBar:FindChild("ChargeBar"):SetMax(nResourceMax)
	self.wndResourceBar:FindChild("ChargeBar"):SetProgress(nResourceCurr)

	if bOverdrive and not self.bOverDriveActive then
		self.bOverDriveActive = true
		self.wndResourceBar:FindChild("ChargeBarOverdriven"):SetProgress(100)
		Apollo.CreateTimer("VikingWarriorResource_ChargeBarOverdriveTick", 0.01, false)
		Apollo.CreateTimer("VikingWarriorResource_ChargeBarOverdriveDone", 10, false)
	end

	local wndBase = self.wndResourceBar:FindChild("Base")
	local wndSkulls = self.wndResourceBar:FindChild("Skulls")
	local wndSplit = self.wndResourceBar:FindChild("InsetFrameDivider")
	self.wndResourceBar:FindChild("ChargeBarOverdriven"):Show(bOverdrive)
	self.wndResourceBar:FindChild("ChargeBar"):Show(not bOverdrive)
	self.wndResourceBar:FindChild("InsetFrameDivider"):Show(not bOverdrive)
	self.wndResourceBar:FindChild("Bar"):SetSprite(bOverdrive and "spr_CM_Warrior_Innate" or "spr_CM_Warrior_Bar")

	local strBaseSprite = ""
	local strSkullIndex = ""
	local strSplitSprite = ""
	local strSkullSprite = ""

	if bOverdrive then
		self.wndResourceBar:FindChild("Bar"):Show(true)
		self.wndResourceBar:FindChild("ResourceCount"):SetText(Apollo.GetString("VikingWarriorResource_OverdriveCaps"))
		self.wndResourceBar:FindChild("ResourceCount"):SetTextColor(ApolloColor.new("xkcdAmber"))

		strBaseSprite = "spr_CM_Warrior_Base_Innate"
		strSkullSprite = "Skull0"
	else
		local bInCombat = unitPlayer:IsInCombat()

		self.wndResourceBar:FindChild("InsetFrameDivider"):Show(nResourceCurr > 0 or bInCombat)
		self.wndResourceBar:FindChild("ResourceCount"):SetText(nResourceCurr == 0 and "" or nResourceCurr)
		self.wndResourceBar:FindChild("ResourceCount"):SetTextColor(ApolloColor.new("xkcdOrangeish"))
		self.wndResourceBar:FindChild("Bar"):Show(nResourceCurr > 0 or bInCombat)

		strBaseSprite = bInCombat and "spr_CM_Warrior_Base_InCombat" or "spr_CM_Warrior_Base_OutOfCombatFade"
		strSkullIndex = not bInCombat and "" or nResourceCurr > 750 and "4" or nResourceCurr > 500 and "3" or nResourceCurr > 250 and "2" or nResourceCurr > 0 and "1" or bInCombat and "1" or ""
		strSkullSprite = "Skull"..strSkullIndex
		strSplitSprite = nResourceMax > 1000 and "spr_CM_Warrior_Split4" or "spr_CM_Warrior_Split3"
	end

	if wndBase:GetData() ~= strBaseSprite then
		wndBase:SetSprite(strBaseSprite)
		wndBase:SetData(strBaseSprite)
	end

	if wndSkulls:GetData() ~= strSkullSprite then
		wndSkulls:SetSprite(strSkullSprite)
		wndSkulls:SetData(strSkullSprite)

		self.wndResourceBar:FindChild("Skull"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild("Skull0"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild("Skull1"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild("Skull2"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild("Skull3"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild("Skull4"):Show(false, false, 0.05)
		self.wndResourceBar:FindChild(strSkullSprite):Show(true, false, 0.05)
	end

	if wndSplit:GetData() ~= strSplitSprite then
		wndSplit:SetSprite(strSplitSprite)
		wndSplit:SetData(strSplitSprite)
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

	if nVisibility == 2 then --always off
		self.wndResourceBar:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndResourceBar:Show(unitPlayer:IsInCombat())
	elseif nVisibility == 4 then --on out of combat
		self.wndResourceBar:Show(not unitPlayer:IsInCombat())
	else
		self.wndResourceBar:Show(true)
	end
end

function VikingWarriorResource:OnVikingWarriorResource_ChargeBarOverdriveTick()
	Apollo.StopTimer("VikingWarriorResource_ChargeBarOverdriveTick")
	self.wndResourceBar:FindChild("ChargeBarOverdriven"):SetProgress(0, 10)
end

function VikingWarriorResource:OnVikingWarriorResource_ChargeBarOverdriveDone()
	Apollo.StopTimer("VikingWarriorResource_ChargeBarOverdriveDone")
	self.bOverDriveActive = false
end

local VikingWarriorResourceInst = VikingWarriorResource:new()
VikingWarriorResourceInst:Init()
