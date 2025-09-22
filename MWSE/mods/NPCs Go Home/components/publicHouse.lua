local cellTypeUtil = require("NPCs Go Home.util.cellTypeUtil")
local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
local nameUtil = require("NPCs Go Home.util.nameUtil")
local npcEvaluator = require("NPCs Go Home.components.npcEvaluator")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local publicHouse = {}


-- TODO: remove/consolidate with util.isIgnoredNPC
---@param npc tes3reference
local function isIgnoredNPCLite(npc)
	local obj = npc.baseObject and npc.baseObject or npc.object

	local isGuard = obj.isGuard or (obj.name and (obj.name:lower():match("guard") and true or false) or false) -- maybe this should just be an if else
	local isVampire = obj.head and (obj.head.vampiric and true or false) or false

	return config.npcBlacklist[obj.id:lower()] or
		config.pluginBlacklist[obj.sourceMod:lower()] or
		isGuard or
		isVampire or
		util.isFollower(npc)
end

-- Cell worth is combined worth of all NPCs
---@param cell tes3cell
---@param proprietor? tes3reference
---@return integer
local function calculateCellWorth(cell, proprietor)
	local worth = 0

	local msg = "\tbreakdown:\n"
	for innard in cell:iterateReferences(tes3.objectType.npc) do
		if isIgnoredNPCLite(innard) then
			goto continue
		end

		local total = npcEvaluator.calculateWorth(innard, innard == proprietor and cell or nil).total
		worth = worth + total

		if log.level == mwse.logLevel.trace then
			msg = msg .. string.format("%s worth: %s, ", innard.object.name, total)
		end

		:: continue ::
	end

	log:debug("Calculated worth of %s for cell %s.", worth, cell.id)
	log:trace(msg:sub(1, #msg - 2)) -- strip off last ", "
	return worth
end

-- Iterate over NPCs in the cell, if configured amount of the population is in the same faction,
-- that's the cell's faction, otherwise, the cell doesn't have a faction.
---@param cell tes3cell
local function pickCellFaction(cell)
	local npcs = {
		---@type table<string, number>
		majorityFactions = {},
		---@type table<string, { total: integer, percentage: number, master: tes3reference }>
		allFactions = {},
		total = 0
	}

	-- Count all the npcs with factions
	for npcRef in cell:iterateReferences(tes3.objectType.npc) do
		if isIgnoredNPCLite(npcRef) then
			goto continue
		end

		npcs.total = npcs.total + 1
		local npc = npcRef.object --[[@as tes3npc]]
		local faction = npc.faction
		if not faction then
			goto continue
		end
		if not npcs.allFactions[faction.id] then
			npcs.allFactions[faction.id] = {
				total = 0,
				percentage = 0
			}
		end

		local highestRankingMember = npcs.allFactions[faction.id].master
		if not highestRankingMember or highestRankingMember.object.factionRank < npc.factionRank then
			npcs.allFactions[faction.id].master = npcRef
		end

		npcs.allFactions[faction.id].total = npcs.allFactions[faction.id].total + 1

		:: continue ::
	end

	-- Pick out all the factions that make up a percentage of the cell greater than the configured value
	-- as long as the cell passes the minimum requirement check.
	local highestPercentage = -1
	for factionId, info in pairs(npcs.allFactions) do
		info.percentage = (info.total / npcs.total) * 100

		local hasMinimumNPCCount = npcs.total >= config.minimumOccupancy
		local hasMinimumNPCPercentage = info.percentage >= config.factionIgnorePercentage
		if hasMinimumNPCPercentage and hasMinimumNPCCount then
			npcs.majorityFactions[factionId] = info.percentage
			highestPercentage = math.max(highestPercentage, info.percentage)
		end
	end

	-- From the majority values, return the faction with the largest percentage, or nil
	local picked = table.find(npcs.majorityFactions, highestPercentage) --[[@as string|nil]]
	log:debug("Picked faction %s for cell %s", picked, cell.id)
	log:trace("\tbreakdown:\n%s", npcs)
	return picked
end

---@class NPCsGoHome.publicCellData
---@field name string The name of the public cell.
---@field city string The city the cell is found in.
---@field cell tes3cell
---@field type NPCsGoHome.publicHouseType|integer|nil
---@field proprietor mwseSafeObjectHandle|nil
---@field worth integer
---@field faction string

-- Indexed by the cell id of the city and interior cell.
---@type table<string, table<string, NPCsGoHome.publicCellData>>
local publicPlaces = {}
---@type table<integer, table<integer, boolean>>
local exploredExteriors = {}

---@param publicCell tes3cell The cell to be designated as a public place.
---@param cellName string
---@param city string The city the cell is found in.
---@param type? NPCsGoHome.publicHouseType|integer
---@param proprietor? tes3reference
local function insertPublicPlace(publicCell, cellName, city, type, proprietor)
	-- Use shitty type picker if none specified
	type = type or cellTypeUtil.pickPublicHouseType(publicCell)
	local factionId
	if proprietor then
		local faction = proprietor.object.faction
		factionId = faction.id
	else
		factionId = pickCellFaction(publicCell)
	end
	---@type NPCsGoHome.publicCellData
	local data = {
		name = cellName,
		city = city,
		cell = publicCell,
		type = type,
		proprietor = proprietor and tes3.makeSafeObjectHandle(proprietor),
		worth = calculateCellWorth(publicCell, proprietor),
		faction = factionId
	}
	publicPlaces[city][publicCell.id] = data
	return data
end

local templeFactionId = "temple"
local templePattern = "temple"
local bladesFactionId = "Blades"

-- Checks NPC class and faction in cells for block list and adds to publicPlaces list
-- TODO: rewrite this
---@param cell tes3cell
function publicHouse.isPublicHouse(cell)
	-- Public spaces can only be interior cells.
	if not util.isInteriorCell(cell) then
		return false
	end

	local cellName = cell.name
	local cellId = cell.id
	local lowerId = string.lower(cellId)
	-- Gather some data about the cell
	local city, publicHouseName = nameUtil.getCityAndBuildingName(cell)

	-- Don't iterate NPCs in the cell if we've already marked it public.
	local publicPlace = publicPlaces[city]
	if publicPlace and publicPlace[cellId] then
		return true
	end

	-- If it's a waistworks or plaza cell, it's public, with no proprietor.
	if config.cantonCellsPolicy == enum.cantonPolicy.public and nameUtil.isPublicCantonCell(lowerId) then
		insertPublicPlace(cell, publicHouseName, city, enum.publicHouse.cantons)
		return true
	end

	local npcs = {
		---@type table<string, { total: integer, percentage: number, playerJoined: boolean, master: tes3reference }>
		factions = {},
		total = 0
	}

	-- TODO: this duplicates some code from pickCellFaction
	for npcRef in cell:iterateReferences(tes3.objectType.npc) do
		if util.isIgnoredNPC(npcRef) then
			goto continue
		end

		local npc = npcRef.object --[[@as tes3npc]]
		local cellType = config.publicCellOwnerClass[npc.class.id:lower()]
		if cellType then
			log:debug("%q of class: %q made %s public", npc.name, npc.class.id, cellId)
			insertPublicPlace(cell, publicHouseName, city, cellType, npcRef)
			return true
		end

		npcs.total = npcs.total + 1
		local faction = npc.faction
		if not faction then
			goto continue
		end

		local factionId = faction.id:lower()
		if not npcs.factions[factionId] then
			npcs.factions[factionId] = {
				playerJoined = faction.playerJoined,
				total = 0,
				percentage = 0
			}
		end

		local highestRankingMember = npcs.factions[factionId].master
		if not highestRankingMember or highestRankingMember.object.factionRank < npc.factionRank then
			npcs.factions[factionId].master = npcRef
		end

		npcs.factions[factionId].total = npcs.factions[factionId].total + 1

		:: continue ::
	end


	-- Temples are always public.
	if npcs.factions[templeFactionId] and cellName and cellName:lower():match(templePattern) then
		local master = npcs.factions[templeFactionId].master
		log:debug("%s is a temple, and %s, %s is the highest ranking member.", cell.id,
			master.object.name, master.object.class)
		insertPublicPlace(cell, publicHouseName, city, enum.publicHouse.temples, master)
		return true
	end

	-- No NPCs of ignored classes, so let's check out factions.
	-- TODO: keys in npcs.factions aren't lowercase, also change case of bladesFactionId var
	for factionId, info in pairs(npcs.factions) do
		info.percentage = (info.total / npcs.total) * 100
		local ignored = config.factionsWithPublicCells[factionId]
		log:trace("No NPCs of ignored class in %s, checking faction %s (ignored: %s, player joined: %s) with \z
			%s (%s%%) vs total %s", cellName, factionId, ignored, info.playerJoined, info.total, info.percentage,
			npcs.total)

		-- TODO: the playerJoined checking here only makes sense for checking public cells that need to be locked,
		-- not for public cells the NPCs can come at night.

		-- A cell with less than a configured amount of NPCs can't be a public house unless it's a Blades house.
		local hasMinimumNPCCount = npcs.total >= config.minimumOccupancy or factionId == bladesFactionId
		local hasMinimumNPCPercentage = info.percentage >= config.factionIgnorePercentage
		if (ignored or info.playerJoined) and hasMinimumNPCCount and hasMinimumNPCPercentage then
			log:debug("%s is %s%% faction %s, marking public.", cellName, info.percentage, factionId)

			-- Try id based categorization, but fallback on guildhall
			local type = cellTypeUtil.pickPublicHouseType(cell)
			if type == enum.publicHouse.inns then
				type = enum.publicHouse.guildhalls
			end
			insertPublicPlace(cell, publicHouseName, city, type, info.master)
			return true
		end
	end

	log:trace("%s isn't public.", cellName)
	return false
end



---@param cell tes3cell
local function isExplored(cell)
	local x = table.getset(exploredExteriors, cell.gridX, {})
	local explored = table.get(x, cell.gridY, false) --[[@as boolean]]
	return explored
end

---@param cell tes3cell
local function setExplored(cell)
	local x = table.getset(exploredExteriors, cell.gridX, {})
	x[cell.gridY] = true
end

---@param cell tes3cell
---@param checked table<tes3cell, true>
local function recursiveExploreInterior(cell, checked)
	if not cell.isInterior then return end
	publicHouse.isPublicHouse(cell)
	checked[cell] = true
	for door in cell:iterateReferences(tes3.objectType.door) do
		if util.isTeleportDoor(door) then
			recursiveExploreInterior(door.destination.cell, checked)
		end
	end
end

local function exploreCity()
	local exploredInteriors = {}
	for _, cell in ipairs(tes3.getActiveCells()) do
		if cell.isInterior then
			log:error("exploreCity called in an interior cell!")
			return
		end
		if not isExplored(cell) then
			for door in cell:iterateReferences(tes3.objectType.door) do
				if util.isTeleportDoor(door) then
					recursiveExploreInterior(door.destination.cell, exploredInteriors)
				end
			end
			setExplored(cell)
		end
	end
end


local factionPlace = {
	[enum.publicHouse.guildhalls] = true,
	[enum.publicHouse.temples] = true
}

---@param cell tes3cell
---@param npcRef tes3reference
---@param city string
function publicHouse.pickPublicHouseForNPC(cell, npcRef, city)
	exploreCity()

	local availablePlaces = publicPlaces[city]
	if not availablePlaces then
		return
	end

	local npcFaction = npcRef.object.faction
	---@type NPCsGoHome.publicHouseData[]
	local availableInns = {}
	local availableTemples = {}
	local availableCantons = {}
	for _, data in pairs(availablePlaces) do
		if npcFaction and factionPlace[data.type] then
			if data.faction == npcFaction.id then
				log:debug("Picking %s for %s based on faction.", data.cell.id, npcRef.object.name)
				return data.cell
			end
		end
		if data.type == enum.publicHouse.inns then
			table.insert(availableInns, data)
		elseif data.type == enum.publicHouse.temples then
			table.insert(availableTemples, data)
		elseif data.type == enum.publicHouse.cantons then
			table.insert(availableCantons, data)
		end
	end

	-- TODO: pick an Inn intelligently?
	-- High class inns for nobles and rich merchants and such
	-- lower class inns for middle class npcs and merchants
	-- temple for commoners and the poorest people
	-- but for now pick one at random.
	local choice = table.choice(availableInns or {})
	if choice then
		log:debug("Picking inn %s, %s for %s", choice.city, choice.name, npcRef.object.name)
		return choice.cell
	end

	local choice = table.choice(availableTemples or {})
	if choice then
		log:debug("Picking temple %s, %s for %s", choice.city, choice.name, npcRef.object.name)
		return choice.cell
	end

	-- If nothing was found, then we'll settle on Canton works cell, if the cell is a Canton.
	if not util.isCantonCell(cell) then
		return
	end
	local choice = table.choice(availableCantons or {})
	if choice then
		log:debug("Picking works %s, %s for %s", choice.city, choice.name, npcRef.object.name)
		return choice.cell
	end
end

return publicHouse
