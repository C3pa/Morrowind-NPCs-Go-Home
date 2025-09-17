local config = require("NPCs Go Home.config")
local npcEvaluator = require("NPCs Go Home.components.npcEvaluator")
local runtimeData = require("NPCs Go Home.components.runtimeData")

local log = mwse.Logger.new()
local cellEvaluator = {}

-- TODO:
-- cellEvaluator can't require util module because util already requires cellEvaluator.
-- this means I have too much spaghetti
---@param npc tes3reference
local function isIgnoredNPCLite(npc)
	local obj = npc.baseObject and npc.baseObject or npc.object

	local isGuard = obj.isGuard or (obj.name and (obj.name:lower():match("guard") and true or false) or false) -- maybe this should just be an if else
	local isVampire = obj.head and (obj.head.vampiric and true or false) or false

	return config.npcBlacklist[obj.id:lower()] or
		config.pluginBlacklist[obj.sourceMod:lower()] or
		isGuard or
		isVampire or
		runtimeData.followers[npc.object.id]
end

-- Cell worth is combined worth of all NPCs
---@param cell tes3cell
---@param proprietor? tes3reference
function cellEvaluator.calculateWorth(cell, proprietor)
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
function cellEvaluator.pickCellFaction(cell)
	local npcs = {
		majorityFactions = {},
		allFactions = {},
		total = 0
	}

	-- Count all the npcs with factions
	for npcRef in cell:iterateReferences(tes3.objectType.npc) do
		if isIgnoredNPCLite(npcRef) then
			goto continue
		end

		local npc = npcRef.object
		local faction = npc.faction
		if faction then
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
		end

		npcs.total = npcs.total + 1
		:: continue ::
	end

	-- Pick out all the factions that make up a percentage of the cell greater than the configured value
	-- as long as the cell passes the minimum requirement check.
	local highestPercentage = -1
	for id, info in pairs(npcs.allFactions) do
		info.percentage = (info.total / npcs.total) * 100
		if info.percentage >= config.factionIgnorePercentage and npcs.total >= config.minimumOccupancy then
			npcs.majorityFactions[id] = info.percentage
			if info.percentage > highestPercentage then
				highestPercentage = info.percentage
			end
		end
	end

	-- From the majority values, return the faction with the largest percentage, or nil
	local picked = table.find(npcs.majorityFactions, highestPercentage)
	log:debug("Picked faction %s for cell %s", picked, cell.id)
	log:trace("\tbreakdown:\n%s", npcs)
	return picked
end

return cellEvaluator
