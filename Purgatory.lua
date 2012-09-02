if(select(3, UnitClass('player')) ~= 6) then return end

local addonName = ...

local locked = true
local font = [=[Fonts\FRIZQT__.TTF]=]
local defaults = {
	point = 'CENTER',
	relative = 'CENTER',
	x = 0,
	y = 0,
	size = 50,
	announce = true,
	message = '<< Purgatory is up, heal me for %s or I die! >>',
	font = 14,
}

local Purgatory = CreateFrame('Frame', addonName, UIParent)
Purgatory:SetScript('OnEvent', function(self, event, ...) self[event](self, ...) end)

local function OnMoveDown(self)
	if(not locked) then
		self:StartMoving()
	end
end

local function OnMoveUp(self)
	if(not locked) then
		self:StopMovingOrSizing()

		local point, _, relative, x, y = self:GetPoint()
		PurgatoryDB.point = point
		PurgatoryDB.relative = relative
		PurgatoryDB.x = x
		PurgatoryDB.y = y
	end
end

local function OnResizeDown()
	Purgatory:StartSizing('BOTTOMRIGHT')
end

local function OnResizeUp()
	Purgatory:StopMovingOrSizing()

	PurgatoryDB.size = Purgatory:GetWidth()
end

local function OnResizeUpdate()
	Purgatory:SetHeight(Purgatory:GetWidth())
end

local function OnUpdate(self, elapsed)
	self.elapsed = self.elapsed - elapsed
	self.Expiration:SetFormattedText('%.1f', self.elapsed)
end

local function Abbreviate(value)
	if(value >= 1e4) then
		return string.format('%.fk', value / 1e3)
	else
		return value
	end
end

Purgatory:RegisterEvent('PLAYER_LOGIN')
function Purgatory:PLAYER_LOGIN()
	PurgatoryDB = PurgatoryDB or defaults

	self:SetMovable(true)
	self:SetClampedToScreen(true)
	self:SetResizable(true)
	self:SetMaxResize(200, 200)
	self:SetMinResize(20, 20)

	self:SetSize(PurgatoryDB.size, PurgatoryDB.size)
	self:SetPoint(PurgatoryDB.point, UIParent, PurgatoryDB.relative, PurgatoryDB.x, PurgatoryDB.y)
	self:SetScript('OnMouseUp', OnMoveUp)
	self:SetScript('OnMouseDown', OnMoveDown)

	local Texture = self:CreateTexture(nil, 'ARTWORK')
	Texture:SetAllPoints()
	Texture:SetTexture(select(3, GetSpellInfo(116888)))
	self.Texture = Texture

	local Expiration = self:CreateFontString(nil, 'OVERLAY')
	Expiration:SetPoint('CENTER')
	Expiration:SetFont(font, PurgatoryDB.font, 'THICKOUTLINE')
	self.Expiration = Expiration

	local Details = self:CreateFontString(nil, 'OVERLAY')
	Details:SetPoint('BOTTOM', 0, -20)
	Details:SetFont(font, PurgatoryDB.font, 'THICKOUTLINE')
	self.Details = Details

	local Scaler = CreateFrame('Button', nil, self)
	Scaler:SetPoint('BOTTOMRIGHT')
	Scaler:SetSize(20, 20)
	Scaler:SetNormalTexture([=[Interface\Buttons\UI-AutoCastableOverlay]=])
	Scaler:GetNormalTexture():SetTexCoord(0.619, 0.76, 0.612, 0.762)
	Scaler:SetScript('OnMouseDown', OnResizeDown)
	Scaler:SetScript('OnMouseUp', OnResizeUp)
	Scaler:SetScript('OnUpdate', OnResizeUpdate)
	Scaler:Hide()
	self.Scaler = Scaler

	self:PLAYER_TALENT_UPDATE()
	self:UNIT_AURA('player')
end

Purgatory:RegisterEvent('PLAYER_TALENT_UPDATE')
function Purgatory:PLAYER_TALENT_UPDATE()
	if(IsSpellKnown(114556)) then
		self:Show()
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
		self:RegisterEvent('PLAYER_REGEN_DISABLED')
		self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		self:RegisterEvent('UNIT_AURA')
	else
		self:Hide()
		self:UnregisterEvent('PLAYER_REGEN_ENABLED')
		self:UnregisterEvent('PLAYER_REGEN_DISABLED')
		self:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		self:UnregisterEvent('UNIT_AURA')
	end
end

local Perdition = GetSpellInfo(123981)
local Shroud = GetSpellInfo(116888)

function Purgatory:UNIT_AURA(unit)
	if(unit == 'player') then
		if(UnitDebuff('player', Perdition)) then
			self.Texture:SetDesaturated(true)
		else
			self.Texture:SetDesaturated(false)
		end

		local _, _, _, _, _, expiration = UnitDebuff('player', Shroud)
		if(expiration and not self.elapsed) then
			self.elapsed = expiration
			self:SetScript('OnUpdate', OnUpdate)
		elseif(not expiration) then
			if(locked) then
				self.Details:SetText('')
				self.Expiration:SetText('')
			end

			self:SetScript('OnUpdate', nil)
			self.elapsed = nil
		end
	end
end

local PlayerGUID

function Purgatory:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, event, _, source, _, _, _, _, _, _, _, spell, _, _, _, amount = ...
	if(event == 'SPELL_AURA_APPLIED') then
		if(not PlayerGUID) then
			PlayerGUID = UnitGUID('player')
		end

		if(source == PlayerGUID and spell == 116888) then
			self.Details:SetFormattedText('%s %s%%', Abbreviate(amount), math.floor(amount / UnitHealthMax('player') * 100 + 1/2))

			if(PurgatoryDB.announce and IsInRaid() and (UnitIsGroupAssistant('player') or UnitIsGroupLeader('player'))) then
				SendChatMessage(string.format(PurgatoryDB.message, Abbreviate(amount)), 'RAID_WARNING')
			end
		end
	end
end

function Purgatory:PLAYER_REGEN_ENABLED()
	self:Hide()
end

function Purgatory:PLAYER_REGEN_DISABLED()
	if(not locked) then
		SlashCmdList.Purgatory('lock')
	end

	self:Show()
end

SLASH_Purgatory1 = '/purgatory'
SlashCmdList.Purgatory = function(msg)
	if(not Purgatory:IsShown()) then return end

	if(msg == '') then
		print('|cff33ff99Purgatory|r: Toggle lock: /purgatory lock')
		print('|cff33ff99Purgatory|r: Toggle announce: /purgatory announce')
		print('|cff33ff99Purgatory|r: Change announce message: /purgatory HEAL ME FOR %s NOW!')
		print('|cff33ff99Purgatory|r: Change font size: /purgatory 18')
	elseif(msg == 'announce') then
		PurgatoryDB.announce = not PurgatoryDB.announce

		if(PurgatoryDB.announce) then
			print('|cff33ff99Purgatory|r: Announcing enabled')
		else
			print('|cff33ff99Purgatory|r: Announcing disabled')
		end
	elseif(msg == 'lock') then
		if(locked) then
			locked = false

			Purgatory:Show()
			Purgatory:EnableMouse(true)
			Purgatory.Scaler:Show()
			Purgatory.Details:SetText('123k 15%')
			Purgatory.Expiration:SetText('2.7')
			Purgatory.Texture:SetDesaturated(false)

			print('|cff33ff99Purgatory|r: Frame is unlocked')
		else
			locked = true

			Purgatory:Hide()
			Purgatory:EnableMouse(false)
			Purgatory.Scaler:Hide()
			Purgatory.Details:SetText('')
			Purgatory.Expiration:SetText('')

			if(UnitDebuff('player', Perdition)) then
				Purgatory.Texture:SetDesaturated(true)
			end

			print('|cff33ff99Purgatory|r: Frame is locked')
		end
	elseif(tonumber(msg)) then
		local size = tonumber(msg)

		if(size < 8 or size > 32) then
			print('|cff33ff99Purgatory|r: You need to set a size between 8 or 32')
		else
			PurgatoryDB.font = size

			Purgatory.Details:SetFont(font, size, 'THICKOUTLINE')
			Purgatory.Expiration:SetFont(font, size, 'THICKOUTLINE')

			print('|cff33ff99Purgatory|r: Font size set to', msg)
		end
	else
		if(not string.find(msg, '%s')) then
			print('|cff33ff99Purgatory|r: You need to have %s somewhere in the message to represent the value you need to be healed for!')
		else
			PurgatoryDB.message = msg

			print('|cff33ff99Purgatory|r: Message is now set to: "' .. msg .. '"')
		end
	end
end
