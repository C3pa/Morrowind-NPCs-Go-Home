local cellTypeUtil = require("NPCs Go Home.util.cellTypeUtil")
local npcEvaluator = require("NPCs Go Home.components.npcEvaluator")
local positions = require("NPCs Go Home.data.positions")

---@alias NPCsGoHome.publicHouseMap table<string, NPCsGoHome.publicHouseData>

local log = mwse.Logger.new()
local runtimeData = {
	-- Cells marked as public
	publicHouses = {
		-- Used for caching public houses to avoid reiterating NPCs
		---@type table<string, NPCsGoHome.publicHouseMap>
		byName = {},
		-- Used for picking cells to move NPCs to
		---@type table<string, table<NPCsGoHome.publicHouseType, NPCsGoHome.publicHouseMap>>
		byType = {}
	},
	-- Homes picked for NPCs
	homes = {
		-- Used for caching homes to avoid reiterating NPCs
		--- @type table<string, NPCsGoHome.movedNPCData>
		byName = {},
		-- Used for checking when entering wandering NPC's house, will probably remove
		--- @type table<string, NPCsGoHome.movedNPCData>
		byCell = {}
	},
	-- Holder for all NPC data
	NPCs = {
		-- NPCs who have been moved
		--- @type table<string, table<string, NPCsGoHome.movedNPCData>>
		moved = {},
		-- NPCs who stick around in bad weather and have been moved
		--- @type table<string, table<string, NPCsGoHome.movedNPCData>>
		movedBadWeather = {},

		-- TODO: the two tables below need to use safe object handles instead.
		-- NPCs who have been disabled
		--- @type table<string, tes3reference>
		disabled = {},
		-- NPCs who stick around in bad weather and have been disabled
		--- @type table<string, tes3reference>
		disabledBadWeather = {}
	},
	-- Positions that haven't been used
	---@type table<string, { orientation: NPCsGoHome.vector3Table, position: NPCsGoHome.vector3Table}[]|nil>
	availablePositions = {},
}


---@param publicCell tes3cell
---@param proprietor? tes3reference TODO: the type is only a guess
---@param city string
---@param name string
---@param cellWorth integer
---@param cellFaction string
---@param type? NPCsGoHome.publicHouseType|integer
function runtimeData.insertPublicHouse(publicCell, proprietor, city, name, cellWorth, cellFaction, type)
	local typeOfPub = type or cellTypeUtil.pickPublicHouseType(publicCell) -- Use shitty type picker if none specified

	local proprietorName = proprietor and proprietor.object.name or "no one"

	---@class NPCsGoHome.publicHouseData
	local data = {
		name = name,
		city = city,
		cell = publicCell,
		type = type,
		proprietor = proprietor,
		proprietorName = proprietorName,
		worth = cellWorth,
		faction = cellFaction
	}

	-- Create by type
	if not runtimeData.publicHouses.byType[city] then
		runtimeData.publicHouses.byType[city] = {}
	end
	if not runtimeData.publicHouses.byType[city][typeOfPub] then
		runtimeData.publicHouses.byType[city][typeOfPub] = {}
	end
	runtimeData.publicHouses.byType[city][typeOfPub][publicCell.id] = data

	-- Create by name
	if not runtimeData.publicHouses.byName[city] then
		runtimeData.publicHouses.byName[city] = {}
	end
	runtimeData.publicHouses.byName[city][publicCell.id] = data
end

---@class NPCsGoHome.vector3Table
---@field x number
---@field y number
---@field z number

-- TODO: this needs a better implementation.
---@param cellId string
local function getModdedCellId(cellId)
	local id

	if cellId == "Balmora, South Wall Cornerclub" and (tes3.isModActive("South Wall.ESP") or tes3.isModActive("South Wall_RP.ESP")) then
		id = "Balmora, South Wall Den Of Iniquity"
	elseif cellId == "Balmora, Eight Plates" and (tes3.isModActive("Eight Plates.esp") or tes3.isModActive("Beautiful cities of Morrowind.ESP")) then
		id = "Balmora, Seedy Eight Plates"
	elseif cellId == "Hla Oad, Fatleg's Drop Off" and (tes3.isModActive("Clean DR115_TheDropoff_HlaOadDocks.ESP") or tes3.isModActive("Beautiful cities of Morrowind.ESP")) then
		id = "Hla Oad, The Drop Off"
	else
		id = cellId
	end

	return id
end

---@param npc tes3reference
---@param home tes3cell
---@param startingPlace tes3cell
---@param isHome boolean
---@param position? NPCsGoHome.vector3Table
---@param orientation? NPCsGoHome.vector3Table
---@return NPCsGoHome.movedNPCData|nil
function runtimeData.insertNPCHome(npc, home, startingPlace, isHome, position, orientation)
	if not npc.object then
		log:error("An unexpected branch entered!")
		return
	end
	local name = npc.object.name
	if name == nil or name == "" then return end

	-- Mod support for different positions in cells
	local id = getModdedCellId(home.id)

	log:debug("Found %s for %s from %s: %s... adding it to cached table...",
		isHome and "home" or "public house", name, startingPlace.id, id)

	-- Pick the position and orientation the NPC will be placed at
	local pos, ori = { 0, 0, 0 }, { 0, 0, 0 }

	local positionData = positions.npcs[name]
	if isHome and positionData then
		pos = positionData.position
		ori = positionData.orientation
	elseif runtimeData.availablePositions[id] and not table.empty(runtimeData.availablePositions[id]) then
		-- Pick a random position out of the positions in memory
		local choice, index = table.choice(runtimeData.availablePositions[id])
		pos = choice.position
		ori = choice.orientation
		table.remove(runtimeData.availablePositions[id], index)
	end

	local pickedPosition = tes3vector3.new(unpack(pos))
	local pickedOrientation = tes3vector3.new(unpack(ori))

	log:trace("Chosen position: %s, orientation: %s for %s in %s", pickedPosition, pickedOrientation, name, id)

	local ogPosition = position and (tes3vector3.new(position.x, position.y, position.z)) or
		(npc.position and npc.position:copy() or tes3vector3.zeroes())

	local ogOrientation = orientation and (tes3vector3.new(orientation.x, orientation.y, orientation.z)) or
		(npc.orientation and npc.orientation:copy() or tes3vector3.zeroes())

	---@class NPCsGoHome.movedNPCData
	local entry = {
		name = name,                   -- string
		npc = npc,                     -- tes3npc
		isHome = isHome,               -- bool
		home = home,                   -- tes3cell
		homeName = home.id,            -- string
		ogPlace = startingPlace,       -- tes3cell
		ogPlaceName = startingPlace.id, -- string
		ogPosition = ogPosition,       -- tes3vector3
		ogOrientation = ogOrientation, -- tes3vector3
		homePosition = pickedPosition, -- tes3vector3
		homeOrientation = pickedOrientation, -- tes3vector3
		worth = npcEvaluator.calculateWorth(npc)
	}

	runtimeData.homes.byName[name] = entry
	if isHome then
		runtimeData.homes.byCell[home.id] = entry
	end

	return entry
end

return runtimeData
