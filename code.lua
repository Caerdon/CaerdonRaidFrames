local DEBUG_ENABLED = false
local ADDON_NAME, NS = ...
local eventFrame

local dispelColors = {
	Magic =   { r = 1.0, g = 0.0, b = 1.0 },
	Curse =   { r = 0.0, g = 0.0, b = 1.0 },
	Poison =  { r = 0.2, g = 0.7, b = 0.3 },
	Disease = { r = 0.8, g = 0.9, b = 0.4 }
}

local spellOverrides = {
	Magic = {
		{
			id = 205604,
			book = BOOKTYPE_SPELL
		}
	}
}

local dispellableDebuffTypes = { Magic = true, Curse = true, Poison = true, Disease = true }

local function FrameKnowsDispel(debuffType, frame)
	return debuffType and frame["hasDispel"..debuffType] ~= nil
end

local function AlternateDispelCheck(debuffType)
	local canDispel = false

	local spells = spellOverrides[debuffType]
	if spells then 
		for i = 1, #spells do
			local spell = spells[i]
			local isKnown = IsSpellKnown(spell.id, spell.book == BOOKTYPE_PET)
			if isKnown then
				local usable, noMana = IsUsableSpell(spell.id) -- Attempting to specify BOOKTYPE_PET here causes ID lookup not to work
				canDispel = usable or noMana
			end
		end
	end

	return canDispel
end

local function CanDispel(debuffType, frame)
	local canDispel = false
	if FrameKnowsDispel(debuffType, frame) or AlternateDispelCheck(debuffType) then
		canDispel = true
	end

	return canDispel
end

local inProcess = {}
local function ShouldProcess(debuffType, frame)
	local unitName = GetUnitName(frame.unit, true)
	local shouldProcess = true
	local activeToon = inProcess[unitName]
	if not activeToon then
		activeToon = {} 
		inProcess[unitName] = activeToon
		activeToon[debuffType] = true
	elseif not activeToon[debuffType] then
		activeToon[debuffType] = true
	else
		shouldProcess = false
	end

	return shouldProcess
end

local function GetColors(debuffType, frame)
	local isCached = false
	local colors = dispelColors[debuffType]
	local r, g, b = colors.r, colors.g, colors.b		
	if not ShouldProcess(debuffType, frame) then
		isCached = true
	else
		local unitName = GetUnitName(frame.unit, true)
		inProcess[unitName] = inProcess[unitName] or {}
		inProcess[unitName][debuffType] = true
	end

	return r, g, b, isCached
end

local function ClearDebuff(debuffType, frame)
	local unitName = GetUnitName(frame.unit, true)
	if inProcess[unitName] and inProcess[unitName][debuffType] then
		inProcess[unitName][debuffType] = false
	end
end

local function UpdateHealthColor(frame)
	local r, g, b = frame.healthBar.r, frame.healthBar.g, frame.healthBar.b
	local foundDispellable = {}
	if ( frame.unit and UnitIsConnected(frame.unit) ) then

		for i = 1, 40 do
			local name, texture, count, debuffType, duration, expirationTime, caster, canStealOrPurge, nameplateShowPersonal, spellId, _, _, _, nameplateShowAll = UnitAura(frame.unit, i, "HARMFUL")
			if CanDispel(debuffType, frame) then
				foundDispellable[debuffType] = true
			end		
		end

		local shouldPlay = false
		local isFound = false

		for debuffType, display in pairs(dispellableDebuffTypes) do
			-- TODO: can only color the first one found (which is hopefully priority...eventually)
			-- Need to account for boss type debuffs
			if UnitIsEnemy("player", frame.unit) then
				ClearDebuff(debuffType, frame)
				r, g, b = 1.0, 0.0, 0.0
			else
				if foundDispellable[debuffType] then
					if not isFound then
						isFound = true

						r, g, b, isCached = GetColors(debuffType, frame)
						if not isCached then		
							shouldPlay = true
						end
					end
				else
					ClearDebuff(debuffType, frame)
				end
			end
		end

		if shouldPlay then
			PlaySoundFile("Interface\\AddOns\\Decursive\\Sounds\\G_NecropolisWound-fast.ogg", "MASTER")
		end
	end

	frame.healthBar:SetStatusBarColor(r, g, b);

	if (frame.optionTable.colorHealthWithExtendedColors) then
		frame.selectionHighlight:SetVertexColor(r, g, b);
	else
		frame.selectionHighlight:SetVertexColor(1, 1, 1);
	end
end

local function UpdateFrames()
	for frameIndex = 1, GetNumGroupMembers() do
		local frame = _G["CompactRaidFrame"..frameIndex]
		if frame then
			UpdateHealthColor(frame)
		end
	end
end

local ignoreEvents = {
-- 	-- ["APPEARANCE_SEARCH_UPDATED"] = {},
	["ACTIONBAR_SLOT_CHANGED"] = {},
	["ACTIONBAR_UPDATE_COOLDOWN"] = {},
	["BAG_NEW_ITEMS_UPDATED"] = {},
	["BAG_UPDATE"] = {},
	["BAG_UPDATE_DELAYED"] = {},
-- 	-- ["BAG_UPDATE_COOLDOWN"] = {},
	["BN_FRIEND_INFO_CHANGED"] = {},
	["CALENDAR_UPDATE_EVENT_LIST"] = {},
	["CHAT_MSG_ADDON"] = {},
	["CHAT_MSG_BN_WHISPER"] = {},
	["CHAT_MSG_BN_WHISPER_INFORM"] = {},
	["CHAT_MSG_CHANNEL"] = {},
	["CHAT_MSG_LOOT"] = {},
	["CHAT_MSG_SYSTEM"] = {},
	["CHAT_MSG_TRADESKILLS"] = {},
	["CLOSE_INBOX_ITEM"] = {},
	["COMBAT_LOG_EVENT_UNFILTERED"] = {},
	["COMPANION_UPDATE"] = {},
	["CRITERIA_UPDATE"] = {},
	["CURSOR_UPDATE"] = {},
	["GET_ITEM_INFO_RECEIVED"] = {},
	["GARRISON_BUILDING_LIST_UPDATE"] = {},
	["GARRISON_BUILDING_PLACED"] = {},
	["GARRISON_MISSION_LIST_UPDATE"] = {},
-- 	-- ["GUILDBANKBAGSLOTS_CHANGED"] = {},
	["GUILD_RANKS_UPDATE"] = {},
	["GUILD_ROSTER_UPDATE"] = {},
	["GUILD_TRADESKILL_UPDATE"] = {},
-- 	-- ["ITEM_LOCK_CHANGED"] = {},
-- 	-- ["ITEM_LOCKED"] = {},
	["ITEM_PUSH"] = {},
-- 	-- ["ITEM_UNLOCKED"] = {},
	["MAIL_INBOX_UPDATE"] = {},
	["MAIL_SUCCESS"] = {},
	["MODIFIER_STATE_CHANGED"] = {},
-- 	-- ["NAME_PLATE_UNIT_REMOVED"] = {},
	["PLAYER_STARTED_MOVING"] = {},
	["PLAYER_STOPPED_MOVING"] = {},
	["QUEST_LOG_UPDATE"] = {},
	["QUESTLINE_UPDATE"] = {},
	["RECEIVED_ACHIEVEMENT_LIST"] = {},
-- 	-- ["SPELL_UPDATE_COOLDOWN"] = {},
-- 	-- ["SPELL_UPDATE_USABLE"] = {},
	["UNIT_ABSORB_AMOUNT_CHANGED"] = {},
	["UNIT_AURA"] = {},
	["UNIT_COMBAT"] = {},
	["UNIT_FACTION"] = {},
	["UNIT_HEALTH"] = {},
	["UNIT_HEALTH_FREQUENT"] = {},
	["UNIT_INVENTORY_CHANGED"] = {},
	["UNIT_PORTRAIT_UPDATE"] = {},
	["UNIT_POWER"] = {},
	["UNIT_POWER_FREQUENT"] = {},
	["UNIT_SPELLCAST_SUCCEEDED"] = {},
-- 	-- ["UPDATE_INVENTORY_DURABILITY"] = {},
	["UPDATE_MOUSEOVER_UNIT"] = {},
-- 	-- ["UPDATE_PENDING_MAIL"] = {},
	["UPDATE_WORLD_STATES"] = {},
	["WORLD_MAP_UPDATE"] = {}
}

local function OnEvent(self, event, ...)
	if DEBUG_ENABLED then
		if not ignoreEvents[event] then
			local arg1, arg2 = ...
			print(event .. ": " .. tostring(arg1) .. ", " .. tostring(arg2))
		end
	end

	local handler = self[event]
	if(handler) then
		handler(self, ...)
	end
end

-- function Caerdon_OnCompactUnitFrame_UpdateAuras(frame)
-- 		UpdateHealthColor(frame)
-- end

-- function Caerdon_OnCompactUnitFrame_SetUpClicks(frame)
-- 	-- Experimenting with mousewheel, but this doesn't work at all.
-- 	frame:EnableMouseWheel(1)
-- 	frame:SetScript("OnMouseWheel",
-- 		function(self, delta)
-- 			if frame["hasDispelDisease"] then
-- 				print("Dispel disease here")
-- 			elseif frame["hasDispelMagic"] then
-- 				CastSpellByID(527, frame.unit)
-- 				print("Dispel magic here")
-- 			elseif frame["hasDispelPoison"] then
-- 				print("Dispel poison here")
-- 			elseif frame["hasDispelCurse"] then
-- 				print("Dispel curse here")
-- 			end

-- 			print(self:GetName() .. " clicked with " .. delta)
-- 		 end
-- 	)


-- end

local function UpdateOptionsFlowContainer(self)
	if IsInGroup() then return end

	local container = self.displayFrame.optionsFlowContainer;
	
	FlowContainer_RemoveAllObjects(container);
	FlowContainer_PauseUpdates(container);
	
	FlowContainer_AddObject(container, self.displayFrame.profileSelector);
	self.displayFrame.profileSelector:Show();
	-- self.displayFrame.profileSelector:Hide();
	self.displayFrame.filterOptions:Hide();

	FlowContainer_AddObject(container, self.displayFrame.raidMarkers);
	self.displayFrame.raidMarkers:Show();
	self.displayFrame.leaderOptions:Hide();

	self.displayFrame.convertToRaid:Hide();

	FlowContainer_AddLineBreak(container);
	FlowContainer_AddSpacer(container, 20);
	FlowContainer_AddObject(container, self.displayFrame.lockedModeToggle);
	FlowContainer_AddObject(container, self.displayFrame.hiddenModeToggle);
	self.displayFrame.lockedModeToggle:Show();
	self.displayFrame.hiddenModeToggle:Show();
	
	FlowContainer_ResumeUpdates(container);
	
	local usedX, usedY = FlowContainer_GetUsedBounds(container);
	self:SetHeight(usedY + 40);
end

local function UpdateContainerVisibility()
	if IsInGroup() then return end

	local manager = CompactRaidFrameManager;
	if ( manager.container.enabled ) then
		manager.container:Show();
	else
		manager.container:Hide();
	end
end

local function UpdateShown(self)
	if IsInGroup() then return end

	self:Show();

	UpdateOptionsFlowContainer(self);
	UpdateContainerVisibility(self);
end

local function UpdateContainerLockVisibility(self)
	if IsInGroup() then return end

	if ( not CompactRaidFrameManagerDisplayFrameLockedModeToggle.lockMode ) then
		CompactRaidFrameManager_LockContainer(self);
	else
		CompactRaidFrameManager_UnlockContainer(self);
	end
end

local lastActivationType, lastNumPlayers, lastSpec, lastEnemyType
local function SetLastActivationType(activationType, numPlayers, spec, enemyType)
	lastActivationType = activationType;
	lastNumPlayers = numPlayers;
	lastSpec = spec;
	lastEnemyType = enemyType;
end

local function GetLastActivationType()
	return lastActivationType, lastNumPlayers, 
		lastSpec, lastEnemyType;
end

local function CheckAutoActivation()
	local soloProfile = "Solo"
	--We only want to adjust the profile when you 1) Zone or 2) change specs. We don't want to automatically
	--change the profile when you are in the uninstanced world.
	-- if ( not IsInGroup() ) then
	-- 	CompactUnitFrameProfiles_SetLastActivationType(nil, nil, nil, nil);
	-- 	return;
	-- end
	
	local success, numPlayers, activationType, enemyType = CompactUnitFrameProfiles_GetAutoActivationState();
	
	if ( not success ) then
		--We didn't have all the relevant info yet. Update again the next time called.
		return;
	end

	local spec = GetSpecialization(false, false, 1);
	local lastActivationType, lastNumPlayers, lastSpec, lastEnemyType = GetLastActivationType();
	
	if ( IsInRaid() and activationType == "world" ) then	--We don't adjust due to just the number of players in the raid.
		return;
	end

	if ( activationType == "world" and enemyType == "PvE" ) then
		local groupSize = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME);
		-- TODO: Allow for a hard-coded profile name for solo
		if ( groupSize == 2 ) then
			numPlayers = 2
		elseif ( groupSize == 3 ) then
			numPlayers = 3
		elseif ( groupSize > 3) then
			numPlayers = 5
		else
			numPlayers = 2
			for i=1, GetNumRaidProfiles() do
				local profile = GetRaidProfileName(i)
				if profile == soloProfile then
					numPlayers = 1
					break
				end
			end
		end
	end

	if ( lastActivationType == activationType and lastNumPlayers == numPlayers and lastSpec == spec and lastEnemyType == enemyType ) then
		--If we last auto-adjusted for this same thing, we don't change. (In case they manually changed the profile.)
		return;
	end

	local activeProfile = GetActiveRaidProfile()
	
	if numPlayers == 1 then
		if activeProfile == soloProfile and GetRaidProfileOption(activeProfile, "autoActivateSpec"..spec) and GetRaidProfileOption(activeProfile, "autoActivate"..enemyType) then
			SetLastActivationType(activationType, numPlayers, spec, enemyType);
		else
			for i=1, GetNumRaidProfiles() do
				local profile = GetRaidProfileName(i);
				if profile == soloProfile then
					CompactUnitFrameProfiles_ActivateRaidProfile(profile);
					SetLastActivationType(activationType, numPlayers, spec, enemyType);
					break
				end
			end
		end
	else
		if ( CompactUnitFrameProfiles_ProfileMatchesAutoActivation(activeProfile, numPlayers, spec, enemyType) ) then
			SetLastActivationType(activationType, numPlayers, spec, enemyType);
		else
			for i=1, GetNumRaidProfiles() do
				local profile = GetRaidProfileName(i);
				if ( CompactUnitFrameProfiles_ProfileMatchesAutoActivation(profile, numPlayers, spec, enemyType) ) then
					CompactUnitFrameProfiles_ActivateRaidProfile(profile);
					SetLastActivationType(activationType, numPlayers, spec, enemyType);
					break
				end
			end
		end
	end
end

hooksecurefunc("CompactUnitFrame_UpdateAuras", UpdateHealthColor)
-- hooksecurefunc("CompactUnitFrame_SetUpClicks", Caerdon_OnCompactUnitFrame_SetUpClicks)
hooksecurefunc("CompactRaidFrameManager_UpdateContainerVisibility", UpdateContainerVisibility)
hooksecurefunc("CompactRaidFrameManager_UpdateContainerLockVisibility", UpdateContainerLockVisibility)
hooksecurefunc("CompactRaidFrameManager_UpdateOptionsFlowContainer", UpdateOptionsFlowContainer)
hooksecurefunc("CompactRaidFrameManager_UpdateShown", UpdateShown)
hooksecurefunc("CompactUnitFrameProfiles_CheckAutoActivation", CheckAutoActivation)

eventFrame = CreateFrame("FRAME", "CaerdonRaidFrame")
eventFrame:RegisterEvent "ADDON_LOADED"
eventFrame:SetScript("OnEvent", OnEvent)

function eventFrame:ADDON_LOADED(name)
	if name == ADDON_NAME then
		if IsLoggedIn() then
			OnEvent(eventFrame, "PLAYER_LOGIN")
		else
			eventFrame:RegisterEvent "PLAYER_LOGIN"
		end
	end
end
	
function eventFrame:PLAYER_LOGIN(...)

	if DEBUG_ENABLED then
		eventFrame:RegisterAllEvents()
	else
		eventFrame:RegisterEvent "PLAYER_ROLES_ASSIGNED"
		-- eventFrame:RegisterEvent "COMBAT_LOG_EVENT_UNFILTERED"
		-- eventFrame:RegisterEvent "UPDATE_INSTANCE_INFO"
	end
end


-- function eventFrame:COMBAT_LOG_EVENT_UNFILTERED()
-- 	local timestamp, type, hideCaster,                                                                                           -- arg1  to arg3
--        sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags,                        -- arg4  to arg11
--        spellId, spellName, spellSchool,                                                                                           -- arg12 to arg14
--        auraType, amount = CombatLogGetCurrentEventInfo()       -- arg15 to arg23

--     local inPartyFlags = bit.bor(COMBATLOG_OBJECT_AFFILIATION_RAID, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_MINE)
--     if bit.band(destFlags, inPartyFlags) ~= 0 then
-- 	    if type == "SPELL_AURA_APPLIED" then
-- 		    	-- UpdateFrames()
-- 		    	print('Processing: ' .. tostring(destName))
-- 		end
-- 	else
--     	print('OUTSIDER: ' .. tostring(destName))
-- 	end
-- end

-- function eventFrame:UPDATE_INSTANCE_INFO(self, event, ...)
	-- local arg1, arg2, arg3, arg4 = ...;
	-- UpdateFrames()
-- end

function eventFrame:PLAYER_ROLES_ASSIGNED(self, event, ...)
	local arg1, arg2, arg3, arg4 = ...;
	local ubase = IsInRaid() and "raid" or "party"
	-- UpdateFrames()
	CheckAutoActivation()
end
