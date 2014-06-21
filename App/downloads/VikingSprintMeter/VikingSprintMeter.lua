-----------------------------------------------------------------------------------------------
-- Client Lua Script for VikingSprintMeter
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "GameLib"
require "Apollo"

local VikingSprintMeter = {}

function VikingSprintMeter:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function VikingSprintMeter:Init()
	Apollo.RegisterAddon(self)
end

function VikingSprintMeter:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("VikingSprintMeter.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function VikingSprintMeter:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterTimerHandler("SprintMeterGracePeriod", "OnSprintMeterGracePeriod", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 	"OnTutorial_RequestUIAnchor", self)	

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "SprintMeterFormVert", "InWorldHudStratum", self)
	self.wndMain:Show(false, true)
	self.xmlDoc = nil
	--self.wndMain:SetUnit(GameLib.GetPlayerUnit(), 40) -- 1 or 9 are also good

	self.bJustFilled = false
	self.nLastSprintValue = 0
end

function VikingSprintMeter:OnFrame()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local bWndVisible = self.wndMain:IsVisible()
	local nRunCurr = unitPlayer:GetResource(0)
	local nRunMax = unitPlayer:GetMaxResource(0)
	local bAtMax = nRunCurr == nRunMax or unitPlayer:IsDead()

	self.wndMain:FindChild("ProgBar"):SetMax(nRunMax)
	self.wndMain:FindChild("ProgBar"):SetProgress(nRunCurr, bWndVisible and nRunMax or 0)

	if self.nLastSprintValue ~= nRunCurr then
		self.wndMain:FindChild("SprintIcon"):SetSprite(self.nLastSprintValue < nRunCurr and "sprResourceBar_Sprint_RunIconSilver" or "sprResourceBar_Sprint_RunIconSilver")
		self.nLastSprintValue = nRunCurr
	end

	if bWndVisible and bAtMax and not self.bJustFilled then
		self.bJustFilled = true
		Apollo.StopTimer("SprintMeterGracePeriod")
		Apollo.CreateTimer("SprintMeterGracePeriod", 0.4, false)
		--self.wndMain:FindChild("ProgFlash"):SetSprite("sprResourceBar_Sprint_ProgFlash")
	end

	if not bAtMax then
		self.bJustFilled = false
		Apollo.StopTimer("SprintMeterGracePeriod")
	end

	self.wndMain:Show(not bAtMax or self.bJustFilled, not bAtMax)
end

function VikingSprintMeter:OnSprintMeterGracePeriod()
	Apollo.StopTimer("SprintMeterGracePeriod")
	self.bJustFilled = false
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Show(false)
	end
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------
function VikingSprintMeter:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.VikingSprintMeter then

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end


local VikingSprintMeterInst = VikingSprintMeter:new()
VikingSprintMeterInst:Init()
