local ActorManager = require("NPCs Go Home.components.ActorManager")
local enum = require("NPCs Go Home.enum")
local util = require("NPCs Go Home.util")


-- TODO: remove/move this from housing.lua
local contextualNPCs = { "^am_", "^sf_" }
local manager = ActorManager:new()
local log = mwse.Logger.new()


---@param ref tes3reference
---@return boolean valid
local function isValidNPC(ref)
	-- TODO: Consider checking
	-- * If the actor has a AI Wander package here.
	-- * Exclude actors that have an interior cell as their default position

	local npc = ref.baseObject --[[@as tes3npc]]
	local lowerId = string.lower(npc.id)
	-- Don't move contextual, such as Animated Morrowind NPCs et al.
	for _, str in pairs(contextualNPCs) do
		if lowerId:match(str) then
			return false
		end
	end
	if util.isIgnoredNPC(ref) then
		return false
	end
	-- We always attach NPCsGoHome table to ref.data if the NPC
	-- is moved to and interior cell by this mod.
	if ref.cell.isInterior and not ref.data.NPCsGoHome then
		return false
	end
	return true
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

---@param cell tes3cell
local function scanActorsInInteriorCell(cell)
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

	-- TODO: make this feature optional
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

---@param cell tes3cell
local function scanActorsInExteriorCell(cell)
	scanActorsInInteriorCell(cell)
	-- We don't scan cells with disabled doors. We consider these inaccessible.
	-- For example Chargen Boat.
	for door in cell:iterateReferences(tes3.objectType.door, false) do
		if util.isTeleportDoor(door) then
			scanActorsInInteriorCell(door.destination.cell)
		end
	end
end

---@param e cellActivatedEventData
function goHome.onCellActivated(e)
	local cell = e.cell
	if not cell.isInterior then return end
	scanActorsInExteriorCell(cell)
end

function goHome.onLoaded()
	manager:clearAllActors()
	for _, cell in ipairs(tes3.getActiveCells()) do
		scanActorsInExteriorCell(cell)
	end
	manager:update()
end

---@param e referenceDeactivatedEventData
function goHome.onReferenceDeactivated(e)
	manager:onReferenceDeactivated(e.reference)
end

function goHome.update()
	manager:update()
end

function goHome.logActors()
	log:debug(function() return manager:getDebugString() end)
end

return goHome
