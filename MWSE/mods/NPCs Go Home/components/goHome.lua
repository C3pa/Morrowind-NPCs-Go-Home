local config = require("NPCs Go Home.config")
local housing = require("NPCs Go Home.components.housing")
local positions = require("NPCs Go Home.data.positions")
local runtimeData = require("NPCs Go Home.components.runtimeData")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local goHome = {}


-- Create an in memory list of positions for a cell, to ensure multiple NPCs aren't placed in the same spot.
---@param cell tes3cell
local function updatePositions(cell)
	local id = cell.id
	-- update runtime positions in cell, but don't overwrite loaded positions
	-- TODO: keys in these tables aren't lowercase
	if not runtimeData.availablePositions[id] and positions.cells[id] then
		runtimeData.availablePositions[id] = {}
		for _, data in pairs(positions.cells[id]) do
			table.insert(runtimeData.availablePositions[id], data)
		end
	end
end

-- TODO: make this recursive?
function goHome.searchCellsForPositions()
	for _, cell in pairs(tes3.getActiveCells()) do
		updatePositions(cell)
		for door in cell:iterateReferences(tes3.objectType.door) do
			if not door.destination then
				goto continue
			end
			updatePositions(door.destination.cell)
			-- one more time
			for internalDoor in door.destination.cell:iterateReferences(tes3.objectType.door) do
				if internalDoor.destination and internalDoor.destination.cell ~= cell then
					updatePositions(internalDoor.destination.cell)
				end
			end

			:: continue ::
		end
	end
end

---@param npcData table<string, NPCsGoHome.movedNPCData>
local function putNPCsBack(npcData)
	log:debug("Moving back NPCs:\n%s", npcData)
	for id, data in pairs(npcData) do
		local npcObject = data.npc.object
		if not npcObject then
			-- TODO: npcData[id] isn't cleared in this case.
			goto continue
		end

		log:debug("Moving %s back outside to %s (%s, %s, %s)", npcObject.name,
			data.ogPlace.id, data.ogPosition.x, data.ogPosition.y, data.ogPosition.z)

		-- Unset NPC data so we don't try to move them on load.
		data.npc.data.NPCsGoHome = nil

		-- And put them back
		tes3.positionCell({
			cell = data.ogPlace,
			reference = data.npc,
			position = data.ogPosition,
			orientation = data.ogPlace
		})
		npcData[id] = nil
		:: continue ::
	end

	-- Reset loaded position data
	runtimeData.availablePositions = {}
	goHome.searchCellsForPositions()
end

---@param npcs table<string, tes3reference>
local function reEnableNPCs(npcs)
	log:debug("Re-enabling NPCs:\n%s", npcs)
	for id, ref in pairs(npcs) do
		log:debug("Making attempt at re-enabling %s", id)
		if not ref.object then
			goto continue
		end
		if ref.disabled then
			tes3.setEnabled({ reference = ref })
		end
		ref.data.NPCsGoHome = nil
		npcs[id] = nil

		:: continue ::
	end
end

---@param cell tes3cell
---@return fun(): tes3reference, keep: boolean
local function iterateNPCs(cell)
	local function iterator()
		for npc in cell:iterateReferences(tes3.objectType.npc) do
			if not util.isIgnoredNPC(npc) then
				local keep = util.isBadWeatherNPC(npc)
				coroutine.yield(npc, keep)
			end
		end
	end
	return coroutine.wrap(iterator)
end

---@param homeData NPCsGoHome.movedNPCData
local function moveNPC(homeData)
	local npc = homeData.npc
	log:debug("Moving %s to home %s (%s, %s, %s)", npc.object.name,
		homeData.home.id, homeData.homePosition.x, homeData.homePosition.y, homeData.homePosition.z)
	local ogPlaceName = homeData.ogPlaceName

	-- Add to the cached table
	local badWeather = util.isBadWeatherNPC(npc)
	if badWeather then
		runtimeData.NPCs.movedBadWeather[ogPlaceName] = runtimeData.NPCs.movedBadWeather[ogPlaceName] or {}
		runtimeData.NPCs.movedBadWeather[ogPlaceName][npc.id] = homeData
	else
		runtimeData.NPCs.moved[ogPlaceName] = runtimeData.NPCs.moved[ogPlaceName] or {}
		runtimeData.NPCs.moved[ogPlaceName][npc.id] = homeData
	end

	-- Store necessary info to npc.data, so we can move NPCs back after a load.
	npc.data.NPCsGoHome = {
		position = { x = npc.position.x, y = npc.position.y, z = npc.position.z },
		orientation = { x = npc.orientation.x, y = npc.orientation.y, z = npc.orientation.z },
		cell = ogPlaceName
	}

	tes3.positionCell({
		cell = homeData.home,
		reference = homeData.npc,
		position = homeData.homePosition,
		orientation = homeData.homeOrientation
	})
end

---@param npc tes3reference
---@param cell tes3cell
local function disableNPC(npc, cell)
	log:debug("Disabling un-homed %s", npc.id)
	if util.isBadWeatherNPC(npc) then
		runtimeData.NPCs.disabledBadWeather[cell.id] = runtimeData.NPCs.disabledBadWeather[cell.id] or {}
		runtimeData.NPCs.disabledBadWeather[cell.id][npc.id] = npc
	else
		runtimeData.NPCs.disabled[cell.id] = runtimeData.NPCs.disabled[cell.id] or {}
		runtimeData.NPCs.disabled[cell.id][npc.id] = npc
	end
	-- Set NPC data
	npc.data.NPCsGoHome = { disabled = true }
	-- npc:disable() -- ! this one sometimes causes crashes
	-- mwscript.disable({reference = npc}) -- ! this one is deprecated
	tes3.setEnabled({ reference = npc, enabled = false }) -- ! but this one causes crashes too
end

---@param npc tes3reference
---@param cell tes3cell
local function disableOrMove(npc, cell)
	local npcHome = config.moveNPCs and housing.pickHomeForNPC(cell, npc) or nil
	if npcHome then
		moveNPC(npcHome)
	else
		disableNPC(npc, cell)
	end
end

-- Search in a specific cell for moved or disabled NPCs and update our runtimeData.
---@param cell tes3cell
local function updateRuntimeData(cell)
	local cellId = cell.id
	log:debug("Looking for moved NPCs in cell %s", cellId)
	for npc in cell:iterateReferences(tes3.objectType.npc) do
		if not (npc.data and npc.data.NPCsGoHome) then
			goto continue
		end
		local data = npc.data.NPCsGoHome
		log:trace("%s has NPCsGoHome data, deciding if disabled or moved...%s", npc, data)
		local isBadWeather = util.isBadWeatherNPC(npc)
		if data.disabled then
			-- The NPC was disabled.
			if isBadWeather then
				runtimeData.NPCs.disabledBadWeather[cellId] = runtimeData.NPCs.disabledBadWeather[cellId] or {}
				runtimeData.NPCs.disabledBadWeather[cellId][npc.id] = npc
			else
				runtimeData.NPCs.disabled[cellId] = runtimeData.NPCs.disabled[cellId] or {}
				runtimeData.NPCs.disabled[cellId][npc.id] = npc
			end
		else
			-- homed NPC
			local homeData = runtimeData.insertNPCHome(npc, cell, tes3.getCell({ id = data.cell }),
				true, data.position, data.orientation)
			local ogPlaceName = homeData.ogPlaceName
			if isBadWeather then
				runtimeData.NPCs.movedBadWeather[ogPlaceName] = runtimeData.NPCs.movedBadWeather[ogPlaceName] or {}
				runtimeData.NPCs.movedBadWeather[ogPlaceName][npc.id] = homeData
			else
				runtimeData.NPCs.moved[ogPlaceName] = runtimeData.NPCs.moved[ogPlaceName] or {}
				runtimeData.NPCs.moved[ogPlaceName][npc.id] = homeData
			end
		end
		:: continue ::
	end
end

function goHome.loadRuntimeDataFromNPCData()
	for _, cell in pairs(tes3.getActiveCells()) do
		updateRuntimeData(cell)
		for door in cell:iterateReferences(tes3.objectType.door) do
			if door.destination then
				-- then check cells attached to active cells
				updateRuntimeData(door.destination.cell)
			end
		end
	end
end

---@param cell tes3cell
function goHome.processNPCs(cell)
	log:info("Looking for NPCs to send home in: %s.", cell.id)

	local isNight = util.isNight()
	local isBadWeather = util.isInclementWeather()

	if not cell.restingIsIllegal and not config.disableNPCsInWilderness then
		-- Shitty way of implementing this config option and re-enabling NPCs when it gets turned off
		-- but at least it's better than trying to keep track of NPCs that have been disabled in the wilderness
		log:debug("Shitty hack ACTIVATE! It's now not night, and the weather is great.")
		isNight = false
		isBadWeather = false
	end

	if not config.disableNPCs
		or not (isBadWeather or isNight) then
		log:trace("!!Good weather and not night!!")
		if not table.empty(runtimeData.NPCs.moved[cell.id]) then
			putNPCsBack(runtimeData.NPCs.moved[cell.id])
		end
		if not table.empty(runtimeData.NPCs.movedBadWeather[cell.id]) then
			putNPCsBack(runtimeData.NPCs.movedBadWeather[cell.id])
		end
		if not table.empty(runtimeData.NPCs.disabled[cell.id]) then
			reEnableNPCs(runtimeData.NPCs.disabled[cell.id])
		end
		if not table.empty(runtimeData.NPCs.disabledBadWeather[cell.id]) then
			reEnableNPCs(runtimeData.NPCs.disabledBadWeather[cell.id])
		end
		return
	end

	if isBadWeather and not isNight then
		log:trace("!!Bad weather and not night!!")
		-- Bad weather during the day, so disable some NPCs.
		for npc, keep in iterateNPCs(cell) do
			if not keep or not config.keepBadWeatherNPCs then
				disableOrMove(npc, cell)
			end
		end

		-- Check for bad weather NPCs that have been disabled, and re-enable them.
		if config.keepBadWeatherNPCs then
			if not table.empty(runtimeData.NPCs.movedBadWeather[cell.id]) then
				putNPCsBack(runtimeData.NPCs.movedBadWeather[cell.id])
			end
			if not table.empty(runtimeData.NPCs.disabledBadWeather[cell.id]) then
				reEnableNPCs(runtimeData.NPCs.disabledBadWeather[cell.id])
			end
		end
	elseif isNight then
		log:trace("!!Good or bad weather and night!!")
		-- at night, weather doesn't matter, disable everyone
		for npc in iterateNPCs(cell) do
			if not npc.disabled then
				disableOrMove(npc, cell)
			end
		end
	end
end

---@param cell tes3cell
---@return fun(): tes3reference, linkedToTravel: boolean
local function iteratePets(cell)
	local function iterator()
		for creature in cell:iterateReferences(tes3.objectType.creature) do
			local isPet, linkedToTravel = util.isPet(creature)
			if isPet then
				coroutine.yield(creature, linkedToTravel)
			end
		end
	end
	return coroutine.wrap(iterator)
end

-- TODO: maybe rewrite this one like processNPCs() too
-- Deal with trader's guars, and other npc linked creatures/whatever
---@param cell tes3cell
function goHome.processPets(cell)
	local isNight = util.isNight()
	local isBadWeather = util.isInclementWeather()

	log:info("Looking for NPC pets to process in cell: %s", cell.id)

	if not cell.restingIsIllegal and not config.disableNPCsInWilderness then
		log:debug("Shitty hack ACTIVATE! It's not night, and the weather is great now.")
		isNight = false
		isBadWeather = false
	end

	-- TODO: should also mark which pets were disabled.
	for pet, linkedToTravel in iteratePets(cell) do
		-- This is becoming too much lol
		if config.disableNPCs and
			(isNight or (isBadWeather and (not linkedToTravel or (linkedToTravel and not config.keepBadWeatherNPCs)))) then
			if not pet.disabled then
				log:debug("Disabling NPC Pet %s!", pet.object.id)
				tes3.setEnabled({ reference = pet, enabled = false })
			end
		else
			-- TODO: this can enable creatures not disabled by this mod.
			if pet.disabled then
				log:debug("Enabling NPC Pet %s!", pet.object.id)
				tes3.setEnabled({ reference = pet })
			end
		end
	end
end

---@param cell tes3cell
---@return fun(): tes3reference
local function iterateSilts(cell)
	local function iterator()
		for activator in cell:iterateReferences(tes3.objectType.activator) do
			if util.isSiltStrider(activator) then
				coroutine.yield(activator)
			end
		end
	end
	return coroutine.wrap(iterator)
end

-- TODO: maybe deal with these like NPCs, adding to runtime data
-- TODO: and setting ref.data.NPCsGoHome = {disabled = true}
-- TODO: would have to check for them on load/cell change as well
---@param cell tes3cell
function goHome.processSiltStriders(cell)
	log:info("Looking for silt striders to process in cell: %s", cell.id)

	local isNight = util.isNight()
	local isBadWeather = util.isInclementWeather()

	-- TODO: below assumption isn't correct. There are mods that add Silts Striders in the wild. For example:
	-- https://www.nexusmods.com/morrowind/mods/53537
	-- https://www.nexusmods.com/morrowind/mods/49103
	-- I don't think there are any silt striders in wilderness cells so not bothering with config.disableNPCsInWilderness
	local disable = config.disableNPCs and (isNight or (isBadWeather and not config.keepBadWeatherNPCs))
	for silt in iterateSilts(cell) do
		log:debug("Setting silt strider to disabled: %s!", silt.object.name, disable)
		tes3.setEnabled({ reference = silt, enabled = not disable })
	end
end

return goHome
