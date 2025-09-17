local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
local runtimeData = require("NPCs Go Home.components.runtimeData")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local housing = {}
-- TODO: add a better filter for these. Looks like these come from Animated Morrowind. The other
-- pattern could be for Starfire's NPC additions.
-- Don't move NPCs whose ids match these, just disable them
local contextualNPCs = { "^AM_", "^SF_" }
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

local publicPlaces = {
	enum.publicHouse.guildhalls, enum.publicHouse.temples
}

---@param npcRef tes3reference
---@param city string
---@return tes3cell|nil
local function pickPublicHouseForNPC(npcRef, city)
	-- Look for wandering guild members
	local availablePublicHouses = runtimeData.publicHouses.byType[city]
	if not availablePublicHouses then
		return
	end

	for _, placeType in ipairs(publicPlaces) do
		for _, data in pairs(availablePublicHouses[placeType] or {}) do
			if npcRef.object.faction == data.proprietor.object.faction then
				log:debug("Picking %s for %s based on faction.", data.cell.id, npcRef.object.name)
				return data.cell
			end
		end
	end

	-- TODO: pick an Inn intelligently?
	-- High class inns for nobles and rich merchants and such
	-- lower class inns for middle class npcs and merchants
	-- temple for commoners and the poorest people
	-- but for now pick one at random
	local choice = table.choice(availablePublicHouses[enum.publicHouse.inns] or {})
	if not choice then return end
	log:debug("Picking inn %s, %s for %s", choice.city, choice.name, npcRef.object.name)
	return choice.cell
end

-- Looks through doors to find a cell that matches a wandering NPCs name
---@param cell tes3cell
---@param npc tes3reference
function housing.pickHomeForNPC(cell, npc)
	-- Don't move contextual, such as Animated Morrowind NPCs et al
	for _, str in pairs(contextualNPCs) do
		if npc.object.id:match(str) then
			return
		end
	end

	-- Time to pick the "home"
	local name = npc.object.name:gsub(" the .*$", "") -- remove "the whatever" from NPCs name
	-- TODO: extract the city name logic into a separate function. This is also present in one of the util functions.
	local city = cell.name and string.split(cell.name, ",")[1] or "wilderness"

	-- Don't need to pick a home if we already have one
	if runtimeData.homes.byName[name] then
		return runtimeData.homes.byName[name]
	end

	-- Check if the NPC already has a house
	for door in cell:iterateReferences(tes3.objectType.door) do
		if door.destination then
			local dest = door.destination.cell

			-- Essentially, if npc full name, or surname matches the cell name
			if dest.id:match(name) or livesInManor(dest.name, name) then
				return runtimeData.insertNPCHome(npc, dest, cell, true)
			end
		end
	end

	-- Haven't found a home, so put them in an inn or guildhall, or inside a canton
	if not config.homelessWanderersToPublicHouses then
		return
	end

	log:debug("Didn't find a home for %s, trying inns", npc.object.name)
	local dest = pickPublicHouseForNPC(npc, city)

	if dest then
		return runtimeData.insertNPCHome(npc, dest, cell, false)
	end

	-- If nothing was found, then we'll settle on Canton works cell, if the cell is a Canton
	if not util.isCantonCell(cell) then
		return
	end

	local availableHouses = runtimeData.publicHouses.byType[city]
	local canton = table.choice(availableHouses[enum.publicHouse.cantons] or {})
	log:debug("Picking works %s, %s for %s", canton.city, canton.name, npc.object.name)
	if not canton then return end
	runtimeData.insertNPCHome(npc, canton.cell, cell, false)
end

return housing
