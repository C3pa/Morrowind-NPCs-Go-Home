local config = require("NPCs Go Home.config")
local nameUtil = require("NPCs Go Home.util.nameUtil")
local publicHouse = require("NPCs Go Home.components.publicHouse")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local housing = {}

-- TODO: add a better filter for these. Looks like these come from Animated Morrowind. The other
-- pattern could be for Starfire's NPC additions.
-- Don't move NPCs whose ids match these, just disable them
local contextualNPCs = { "^am_", "^sf_" }
-- TODO: i18n
local MANOR = "Manor"

---@param cellName string
---@param npcName string
local function livesInManor(cellName, npcName)
	if not cellName or (cellName and not string.find(cellName, MANOR)) then
		return false
	end

	local splitName = string.split(npcName)
	local given = splitName[1]
	local sur = splitName[2]

	-- Surnameless peasants don't live in manors
	if not sur then
		return false
	end

	log:trace("Checking if %s %s lives in %s", given, sur, cellName)
	return string.match(cellName, sur)
end

-- Essentially, if npc full name, or surname matches the cell name.
---@param cell tes3cell
---@param npcName string
local function livesHere(cell, npcName)
	local houseOwner = cell.id:match(npcName)
	if houseOwner or livesInManor(cell.name, npcName) then
		return true
	end
	return false
end


---@class NPCsGoHome.houseData
---@field isHome boolean True if this is a home belonging to this npc.
---@field cellId string The id of the home.
---@field position tes3vector3
---@field orientation tes3vector3

-- Indexed by the NPC id.
---@type table<string, NPCsGoHome.houseData>
local homes = {}

---@param npc tes3npc
---@param isHome boolean
---@param homeCell tes3cell
---@param position tes3vector3
---@param orientation tes3vector3
local function insertNPCHome(npc, isHome, homeCell, position, orientation)
	-- TODO: restore picking functionality from data\positions .

	---@type NPCsGoHome.houseData
	local entry = {
		isHome = isHome,
		cellId = homeCell.id,
		position = position,
		orientation = orientation
	}
	homes[string.lower(npc.id)] = entry
	return entry
end

local doorMarkerId = "DoorMarker"

-- Looks through doors to find a cell that matches a wandering NPCs name
---@param cell tes3cell
---@param npcRef tes3reference
function housing.pickHomeForNPC(cell, npcRef)
	local npc = npcRef.baseObject --[[@as tes3npc]]
	local lowerId = string.lower(npc.id)
	-- Don't move contextual, such as Animated Morrowind NPCs et al.
	for _, str in pairs(contextualNPCs) do
		if lowerId:match(str) then
			return false
		end
	end

	-- Time to pick q "home".
	local name = nameUtil.removeTitle(npc.name)
	local city = nameUtil.getCityAndBuildingName(cell)

	-- Don't need to pick a home if we already have one.
	if homes[lowerId] then
		return homes[lowerId]
	end

	-- Check if the NPC already has a house
	for door in cell:iterateReferences(tes3.objectType.door) do
		if util.isTeleportDoor(door) then
			local dest = door.destination.cell
			if livesHere(dest, name) then
				local marker = door.destination.marker
				return insertNPCHome(npc, true, dest, marker.position:copy(), marker.orientation:copy())
			end
		end
	end

	-- Haven't found a home, so put them in an inn or guildhall, or inside a canton.
	if not config.homelessWanderersToPublicHouses then
		return
	end

	log:debug("Didn't find a home for %s, trying inns", npc.name)
	local dest = publicHouse.pickPublicHouseForNPC(cell, npcRef, city)

	if dest then
		-- All, even unloaded, cells in Morrowind always have available their NPC, teleport door and DoorMarkers
		-- loaded. We use that fact to get a point inside the cell. This may not be the optimal point in the cell
		-- to put the NPCs.

		-- TODO other option is to traverse cell's pathgrid and take the coords of a pathgrid node.

		local position, orientation
		for ref in cell:iterateReferences(tes3.objectType.static) do
			if ref.id == doorMarkerId then
				position = ref.position
				orientation = ref.orientation
				break
			end
		end

		return insertNPCHome(npc, false, dest, position, orientation)
	end
end

return housing
