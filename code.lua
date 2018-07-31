local DEBUG_ENABLED = false
local ADDON_NAME, NS = ...
local eventFrame

local function UpdateHealthColor(frame)
	local r, g, b = frame.healthBar.r, frame.healthBar.g, frame.healthBar.b;
	if ( frame.unit and UnitIsConnected(frame.unit) ) then
		if frame["hasDispelDisease"] then
			r, g, b = 0.8, 0.9, 0.4;
		elseif frame["hasDispelMagic"] then
			r, g, b = 1.0, 0.0, 1.0;
		elseif frame["hasDispelPoison"] then
			r, g, b = 0.2, 0.7, 0.3;
		elseif frame["hasDispelCurse"] then
			r, g, b = 0.0, 0.0, 1.0;
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
-- 	-- ["GUILD_ROSTER_UPDATE"] = {},
-- 	-- ["ITEM_LOCK_CHANGED"] = {},
-- 	-- ["ITEM_LOCKED"] = {},
	["ITEM_PUSH"] = {},
-- 	-- ["ITEM_UNLOCKED"] = {},
	["MAIL_INBOX_UPDATE"] = {},
	["MAIL_SUCCESS"] = {},
-- 	-- ["MODIFIER_STATE_CHANGED"] = {},
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
-- 	-- ["UPDATE_MOUSEOVER_UNIT"] = {},
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

function Caerdon_OnCompactUnitFrame_UpdateAuras(frame)
		UpdateHealthColor(frame)
end

function Caerdon_OnCompactUnitFrame_SetUpClicks(frame)
	-- Experimenting with mousewheel, but this doesn't work at all.
	frame:EnableMouseWheel(1)
	frame:SetScript("OnMouseWheel",
		function(self, delta)
			if frame["hasDispelDisease"] then
				print("Dispel disease here")
			elseif frame["hasDispelMagic"] then
				CastSpellByID(527, frame.unit)
				print("Dispel magic here")
			elseif frame["hasDispelPoison"] then
				print("Dispel poison here")
			elseif frame["hasDispelCurse"] then
				print("Dispel curse here")
			end

			print(self:GetName() .. " clicked with " .. delta)
		 end
	)


end

local function UpdateOptionsFlowContainer(self)
	if IsInGroup() then return end

	local container = self.displayFrame.optionsFlowContainer;
	
	FlowContainer_RemoveAllObjects(container);
	FlowContainer_PauseUpdates(container);
	
	self.displayFrame.profileSelector:Hide();
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

hooksecurefunc("CompactUnitFrame_UpdateAuras", Caerdon_OnCompactUnitFrame_UpdateAuras)
hooksecurefunc("CompactUnitFrame_SetUpClicks", Caerdon_OnCompactUnitFrame_SetUpClicks)
hooksecurefunc("CompactRaidFrameManager_UpdateContainerVisibility", UpdateContainerVisibility)
hooksecurefunc("CompactRaidFrameManager_UpdateContainerLockVisibility", UpdateContainerLockVisibility)
hooksecurefunc("CompactRaidFrameManager_UpdateOptionsFlowContainer", UpdateOptionsFlowContainer)
hooksecurefunc("CompactRaidFrameManager_UpdateShown", UpdateShown)

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
		-- eventFrame:RegisterEvent "UPDATE_INSTANCE_INFO"
	end
end

-- function eventFrame:UPDATE_INSTANCE_INFO(self, event, ...)
	-- local arg1, arg2, arg3, arg4 = ...;
	-- UpdateFrames()
-- end

function eventFrame:PLAYER_ROLES_ASSIGNED(self, event, ...)
	local arg1, arg2, arg3, arg4 = ...;
	local ubase = IsInRaid() and "raid" or "party"
	UpdateFrames()
end
