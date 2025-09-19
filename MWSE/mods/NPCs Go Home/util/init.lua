local cellTypeUtil = require("NPCs Go Home.util.cellTypeUtil")
local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
local npcEvaluator = require("NPCs Go Home.components.npcEvaluator")
local runtimeData = require("NPCs Go Home.components.runtimeData")

local log = mwse.Logger.new()

-- Very Todd workaround
---@param id string
local function getFightFromSpawnedReference(id)
	-- Spawn a reference of the given id in toddtest
	local toddTest = tes3.getCell({ id = "toddtest" })
	log:debug("Spawning %s in %s", id, toddTest.id)

	local ref = tes3.createReference({
		object = id,
		cell = toddTest,
		-- cell = tes3.getPlayerCell(),
		position = tes3vector3.new(0, 0, 0),
		-- position = {0, 0, 10000},
		orientation = tes3vector3.new(0, 0, 0)
	})

	local fight = ref.mobile.fight

	log:debug("Got fight of %s, time to yeet %s", fight, id)
	ref:delete()
	return fight
end

---@param ref tes3reference
local function isDead(ref)
	if ref.isDead then
		return true
	end

	local mob = ref.mobile
	if mob and mob.health.current <= 0 then
		return true
	end

	-- TODO: is this check even necessary.
	if ref.baseObject.id:match("[Dd]ead") or ref.baseObject.name:match("[Dd]ead") then
		log:error("A reference %q isDead check entered a strange branch.", ref.id)
		return true
	end

	return false
end

---@param ref tes3reference
local function isVampire(ref)
	if ref.mobile and tes3.isAffectedBy({ reference = ref, effect = tes3.effect.vampirism }) then
		return true
	end
	local npc = ref.baseObject
	return npc.head and (npc.head.vampiric and true or false) or false
end

---@param ref tes3reference
local function isHostile(ref)
	if ref.mobile and ref.mobile.fight > 70 then
		return true
	end
	-- local fight = getFightFromSpawnedReference(obj.id) -- ! calling this hundreds of times is bad for performance lol
	-- if (fight or 0) > 70 then
	-- 	return true
	-- end
	return false
end

---@param ref tes3reference
local function isWerewolf(ref)
	-- if ref.mobile.werewolf then
	-- 	return true
	-- end

	local werewolfVisionSpellId = "werewolf vision"
	return mwscript.getSpellEffects({ reference = ref, spell = werewolfVisionSpellId })
end

---@param ref tes3reference
local function isGuard(ref)
	if ref.object.isGuard then
		return true
	end
	-- Some TR "Hired Guards" aren't actually "guards", ignore them as well
	if ref.baseObject.name:lower():match("guard") then
		return true
	end
	return false
end


local util = {}

local followPackage = {
	[tes3.aiPackage.follow] = true,
	[tes3.aiPackage.escort] = true,
}

--- This function returns `true` if a given actor has
--- follow AI package with the player as its target.
---@param reference tes3reference
---@return boolean isFollower
local function isFollower(reference)
	local mobile = reference.mobile
	if not mobile then
		return false
	end
	local planner = mobile.aiPlanner
	if not planner then
		return false
	end

	local package = planner:getActivePackage()
	if not package then
		return false
	end

	if not followPackage[package.type] then
		return false
	end
	if package.targetActor.objectType ~= tes3.objectType.mobilePlayer then
		return false
	end
	return true
end


-- todo: more quest aware checks like this
local function fargothCheck()
	local fargothJournal = tes3.getJournalIndex({ id = "MS_Lookout" })
	if not fargothJournal then return false end

	-- only disable Fargoth before speaking to Hrisskar, and after observing Fargoth sneak
	local isActive = fargothJournal > 10 and fargothJournal <= 30

	log:trace("Fargoth journal check, %s is active: %s", fargothJournal, isActive)

	return isActive
end

---@param npcRef tes3reference
function util.isIgnoredNPC(npcRef)
	local npc = npcRef.baseObject and npcRef.baseObject or npcRef.object
	local id = string.lower(npc.id)
	local sourceMod = string.lower(npc.sourceMod)
	local name = npc.name

	-- Ignore dead, attack on sight NPCs, vampires, werewolves and guards
	local isDead = isDead(npcRef)
	local isHostile = isHostile(npcRef)
	local isVampire = isVampire(npcRef)
	local isWerewolf = isWerewolf(npcRef)
	local isGuard = isGuard(npcRef)

	-- TODO: implement quest-based exceptions
	local isFargoth = npc.id:match("fargoth")
	local isFargothActive = isFargoth and fargothCheck() or false
	local isClassBlacklisted = config.classBlacklist[npc.class.id:lower()]
	local isFollower = isFollower(npcRef)
	log:trace("Checking NPC: %s (%s or %s): \z
				isNPCBlacklisted: %s, %s isPluginBlacklisted: %s, class: &s, \z
				isClassBlacklisted: %s, guard: %s, dead: %s, vampire: %s, werewolf: %s, \z
				follower: %s, hostile: %s%s%s",
		name, npcRef.object.id, npcRef.object.baseObject and npcRef.object.baseObject.id or "nil",
		config.npcBlacklist[id], sourceMod, config.pluginBlacklist[sourceMod], npc.class,
		isClassBlacklisted, isGuard, isDead, isVampire, isWerewolf,
		-- TODO:
		isFollower, isHostile, isFargoth and ", fargoth active: " or "", isFargoth and tostring(isFargothActive) or "")


	return config.npcBlacklist[id] or
		config.pluginBlacklist[sourceMod] or
		isGuard or
		isFargothActive or
		isDead or
		isHostile or
		isFollower or
		isVampire or
		isWerewolf or
		isClassBlacklisted
end

---@param cell tes3cell
---@return boolean
function util.isIgnoredCell(cell)
	local isIgnored = config.cellBlacklist[cell.id:lower()]
	log:trace("%q isIgnored: %s.", cell.id, isIgnored)

	return isIgnored
end

---@param cell tes3cell
function util.isInteriorCell(cell)
	local realInterior = cell.isInterior and not cell.behavesAsExterior
	return realInterior
end

local plazaPattern = {
	"waistworks", "vivec, .* plaza", -- Vvardenfell
	"almas thirr, plaza",         -- Tamriel Rebuilt
	"molag mar, plaza"            -- No-frills closed Molag Mar
}
-- Waistworks and plaza
---@param lowerId string
local function isPublicCantonCell(lowerId)
	for _, pattern in ipairs(plazaPattern) do
		if lowerId:match(pattern) then
			return true
		end
	end
	return false
end

local otherCantonPattern = {
	"canalworks", "underworks"
}

-- Any interior canton cell
---@param cell tes3cell
function util.isCantonWorksCell(cell)
	local lowerId = cell.id:lower()
	if isPublicCantonCell(lowerId) then
		return true
	end

	for _, pattern in ipairs(otherCantonPattern) do
		if lowerId:match(pattern) then
			return true
		end
	end
	return false
end

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
		isFollower(npc)
end

-- Cell worth is combined worth of all NPCs
---@param cell tes3cell
---@param proprietor? tes3reference
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

-- Checks NPC class and faction in cells for block list and adds to publicHouse list
-- TODO: rewrite this
---@param cell tes3cell
function util.isPublicHouse(cell)
	-- Public spaces can only be interior cells
	if not util.isInteriorCell(cell) then
		return false
	end

	local cellName = cell.name
	local cellId = cell.id
	local lowerId = string.lower(cellId)
	-- Gather some data about the cell
	local city, publicHouseName

	if cellName and string.match(cellName, ",") then
		-- TODO: this heuristic isn't always correct. What about Seyda Neen?
		local result = string.split(cellName, ",")
		city = result[1]
		publicHouseName = result[2]:gsub("^%s", "")
	else
		city = "Wilderness"
		publicHouseName = cellId
	end

	-- Don't iterate NPCs in the cell if we've already marked it public
	local publiceCityCells = runtimeData.publicHouses.byName[city]
	if publiceCityCells and publiceCityCells[cellId] then
		return true
	end

	-- If it's a waistworks or plaza cell, it's public, with no proprietor
	if config.cantonCellsPolicy == enum.cantonPolicy.public and isPublicCantonCell(lowerId) then
		runtimeData.insertPublicHouse(cell, nil, city, publicHouseName,
			calculateCellWorth(cell),
			pickCellFaction(cell),
			enum.publicHouse.cantons)
		return true
	end

	local npcs = {
		factions = {},
		total = 0
	}

	for npcRef in cell:iterateReferences(tes3.objectType.npc) do
		if util.isIgnoredNPC(npcRef) then
			goto continue
		end

		local npc = npcRef.object
		if npc.class and config.classBlacklist[npc.class.id:lower()] then
			log:debug("%q of class: %q made %s public", npc.name, npc.class and npc.class.id or "none", cellName)
			runtimeData.insertPublicHouse(cell, npcRef, city, publicHouseName,
				calculateCellWorth(cell),
				pickCellFaction(cell))
			return true
		end

		local faction = npc.faction
		if faction then
			local id = faction.id:lower()
			if not npcs.factions[id] then
				npcs.factions[id] = {
					playerJoined = faction.playerJoined,
					total = 0,
					percentage = 0
				}
			end

			-- TODO: this duplicates some code from pickCellFaction
			local highestRankingMember = npcs.factions[id].master
			if not highestRankingMember or highestRankingMember.object.factionRank < npc.factionRank then
				npcs.factions[id].master = npcRef
			end

			npcs.factions[id].total = npcs.factions[id].total + 1
		end

		npcs.total = npcs.total + 1
		:: continue ::
	end

	-- Temples are always public
	if npcs.factions["temple"] and cellName and cellName:lower():match("temple") then
		local master = npcs.factions["temple"].master
		log:debug("%s is a temple, and %s, %s is the highest ranking member.", cell.id,
			master.object.name, master.object.class)
		runtimeData.insertPublicHouse(cell, master, city, publicHouseName,
			calculateCellWorth(cell),
			pickCellFaction(cell),
			enum.publicHouse.temples)
		return true
	end

	-- No NPCs of ignored classes, so let's check out factions
	-- TODO: keys in npcs.factions aren't lowercase
	for faction, info in pairs(npcs.factions) do
		info.percentage = (info.total / npcs.total) * 100
		local ignored = config.factionBlacklist[faction]
		log:trace(
			"No NPCs of ignored class in %s, checking faction %s (ignored: %s, player joined: %s) with %s (%s%%) vs total %s",
			cellName, faction, ignored, info.playerJoined, info.total, info.percentage, npcs.total)

		-- Less than configured amount of NPCs can't be a public house unless it's a Blades house
		local hasMinimumNPCCount = npcs.total >= config.minimumOccupancy or faction == "Blades"
		if (ignored or info.playerJoined) and hasMinimumNPCCount and
			(info.percentage >= config.factionIgnorePercentage) then
			log:debug("%s is %s%% faction %s, marking public.", cellName, info.percentage, faction)

			-- Try id based categorization, but fallback on guildhall
			-- TODO: this variable isn't even used
			local type = cellTypeUtil.pickPublicHouseType(cell)
			if type == enum.publicHouse.inns then
				type = enum.publicHouse.guildhalls
			end

			runtimeData.insertPublicHouse(cell, npcs.factions[faction].master, city, publicHouseName,
				calculateCellWorth(cell),
				pickCellFaction(cell),
				enum.publicHouse.guildhalls)
			return true
		end
	end

	log:trace("%s isn't public.", cellName)
	return false
end

function util.isNight()
	local hour = tes3.worldController.hour.value
	local isNight = hour >= config.closeTime or hour <= config.openTime

	return isNight
end

function util.isInclementWeather()
	-- TODO: make characters with frost resistance such as Nords be fine with standing outside when it's snowing.
	return tes3.getCurrentWeather().index >= config.worstWeather
end

---@param npc tes3reference
local function offersTravel(npc)
	for _, _ in ipairs(npc.object.aiConfig.travelDestinations or {}) do
		return true
	end

	return false
end

-- Travel agents, their steeds, and argonians stick around
---@param npcRef tes3reference
function util.isBadWeatherNPC(npcRef)
	local npc = npcRef.object
	local race = npc.race.id
	local offersTravel = offersTravel(npcRef)
	local is = offersTravel or config.ignoresBadWeatherRace[race] or config.ignoresBadWeatherClass[npc.class.id]
	log:trace("%s, %s%s is inclement weather NPC? %s", npc.name, race, offersTravel and ", travel agent" or "", is)
	return is
end

---@param cell tes3cell
function util.isCantonCell(cell)
	if util.isInteriorCell(cell) then
		return false
	end
	for door in cell:iterateReferences(tes3.objectType.door) do
		if door.destination and util.isCantonWorksCell(door.destination.cell) then
			return true
		end
	end
	return false
end

---@param creature tes3reference
---@return boolean isPet
---@return boolean? isLinkedToTravelNPC
function util.isPet(creature)
	local obj = creature.baseObject and creature.baseObject or creature.object

	-- TODO: more pets?
	-- Pack guars
	if obj.id:match("guar") and obj.mesh:match("pack") then
		return true
		-- Imperial carriages
	elseif obj.id:match("_[Hh]rs") and obj.mesh:match("_[Hh]orse") then
		return true, true
	end

	return false, false
end

---@param activator tes3reference
function util.isSiltStrider(activator)
	local id = activator.object.id:lower()
	log:trace("Is %s a silt strider?", id)
	return id:match("siltstrider") or
		-- TODO: is this for Kilchunda's Balmora?
		id:match("kil_silt")
end

-- Returns "n" if "a" needs to become "an" for the word in question
---@param word string
function util.vowel(word)
	local s = string.sub(word, 1, 1)
	local n = ""
	if string.match(s, "[AOEUIaoeui]") then
		n = "n"
	end
	return n
end

-- Returns true if NPC offers any kind of service, otherwise false
---@param npc tes3reference
function util.isServicer(npc)
	if not npc or not npc.mobile then
		return false
	end

	for serviceName, service in pairs(tes3.merchantService) do
		if tes3.checkMerchantOffersService({ reference = npc, service = service }) then
			log:debug("%s offers service \"%s\"", npc.object.name, serviceName)
			return true
		end
	end

	log:trace("%s doesn't offer services", npc.object.name)
	return false
end

return util
