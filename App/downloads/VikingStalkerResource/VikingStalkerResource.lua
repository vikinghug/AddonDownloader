-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingStalkerResource
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Unit"

local VikingStalkerResource = {}

function VikingStalkerResource:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function VikingStalkerResource:Init()
  Apollo.RegisterAddon(self, nil, nil, {"VikingActionBarFrame"})
end

function VikingStalkerResource:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("VikingStalkerResource.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function VikingStalkerResource:OnDocumentReady()
  if  self.xmlDoc == nil then
    return
  end

  Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
  self:OnRequiredFlagsChanged()
end

function VikingStalkerResource:OnRequiredFlagsChanged()
  if g_wndActionBarResources then
    if GameLib.GetPlayerUnit() then
      self:OnCharacterCreated()
    else
      Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
    end
  end
end

function VikingStalkerResource:OnCharacterCreated()
  local unitPlayer = GameLib.GetPlayerUnit()
  if unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Stalker then
    return
  end

  Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

  self.wndResourceBar = Apollo.LoadForm(self.xmlDoc, "VikingStalkerResourceForm", g_wndActionBarResources, self)
  self.wndResourceBar:ToFront()

  self.xmlDoc = nil
end

function VikingStalkerResource:OnFrame(varName, cnt)
  if not self.wndResourceBar:IsValid() then
    return
  end

  local nLeft, nTop, nRight, nBottom = self.wndResourceBar:GetRect()
  Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop - 10, true)

  ----------Resource 3
  local unitPlayer = GameLib.GetPlayerUnit()
  local nResourceCurrent = unitPlayer:GetResource(3)
  local nResourceMax = unitPlayer:GetMaxResource(3)
  local bInCombat = unitPlayer:IsInCombat()

  self.wndResourceBar:FindChild("CenterMeter1"):SetStyleEx("EdgeGlow", nResourceCurrent < nResourceMax)
  self.wndResourceBar:FindChild("CenterMeter1"):SetMax(nResourceMax)
  self.wndResourceBar:FindChild("CenterMeter1"):SetProgress(nResourceCurrent)
  self.wndResourceBar:FindChild("CenterMeterText"):SetText(nResourceCurrent)
  self.wndResourceBar:FindChild("CenterMeterText"):Show(bInCombat or nResourceCurrent ~= nResourceMax)

  local wndBase = self.wndResourceBar:FindChild("Base")

  local wndCenterMeterTextContainer = self.wndResourceBar:FindChild("CenterMeterTextContainer")
  wndCenterMeterTextContainer:Show(bInCombat)


  --Toggle Visibility based on ui preference
  local unitPlayer = GameLib.GetPlayerUnit()
  local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

  if nVisibility == 2 then --always off
    self.wndResourceBar:Show(false)
  elseif nVisibility == 3 then --on in combat
    self.wndResourceBar:Show(bInCombat)
  elseif nVisibility == 4 then --on out of combat
    self.wndResourceBar:Show(not bInCombat)
  else
    self.wndResourceBar:Show(true)
  end
end

local VikingStalkerResourceInst = VikingStalkerResource:new()
VikingStalkerResourceInst:Init()
