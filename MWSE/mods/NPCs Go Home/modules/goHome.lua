local ActorManager = require("NPCs Go Home.components.ActorManager")
local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
local util = require("NPCs Go Home.util")


-- TODO: remove/move this from housing.lua
local contextualNPCs = { "^am_", "^sf_" }
local manager = ActorManager:new()
local log = mwse.Logger.new()


---@param ref tes3reference
---@return boolean valid
local function isValidNPC(ref)
	-- TODO: Consider checking if the actor has a AI Wander package here.

	local npc = ref.baseObject --[[@as tes3npc]]
	local lowerId = string.lower(npc.id)
	-- Don't move contextual, such as Animated Morrowind NPCs et al.
	for _, str in pairs(contextualNPCs) do
		if lowerId:match(str) then
			return false
		end
	end
	return not util.isIgnoredNPC(ref)
end

local goHome = {}

---@param e referenceActivatedEventData
function goHome.onReferenceActivated(e)
	local ref = e.reference
	local objectType = ref.object.objectType
	if objectType == tes3.objectType.npc and isValidNPC(ref) then
		manager:addActor(ref, ref.cell, enum.actorType.npc)
	elseif objectType == tes3.objectType.creature and util.isPet(ref) then
		manager:addActor(ref, ref.cell, enum.actorType.creature)
	elseif objectType == tes3.objectType.activator and util.isSiltStrider(ref) then
		manager:addActor(ref, ref.cell, enum.actorType.siltStrider)
	end
end

function goHome.onLoaded()
	manager:clearAllActors()
	for _, cell in ipairs(tes3.getActiveCells()) do
		for npcRef in cell:iterateReferences(tes3.objectType.npc) do
			if isValidNPC(npcRef) then
				manager:addActor(npcRef, cell, enum.actorType.npc)
			end
		end
		for creatureRef in cell:iterateReferences(tes3.objectType.creature) do
			if util.isPet(creatureRef) then
				manager:addActor(creatureRef, cell, enum.actorType.creature)
			end
		end

		-- For Silt Striders we only disable them in towns. There are mods that add Silt Striders in the wilderness.
		-- We don't disable those. Examples of such mods:
		-- https://www.nexusmods.com/morrowind/mods/49103
		-- https://www.nexusmods.com/morrowind/mods/53537
		if cell.restingIsIllegal then
			for activator in cell:iterateReferences(tes3.objectType.activator) do
				if util.isSiltStrider(activator) then
					manager:addActor(activator, cell, enum.actorType.siltStrider)
				end
			end
		end

	end
end

---@param e referenceDeactivatedEventData
function goHome.onReferenceDeactivated(e)
	manager:onReferenceDeactivated(e.reference)
end

function goHome.update()
	manager:update()
end

return goHome
