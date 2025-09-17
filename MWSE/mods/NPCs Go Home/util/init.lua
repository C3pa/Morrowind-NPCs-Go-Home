local cellEvaluator = require("NPCs Go Home.components.cellEvaluator")
local cellTypeUtil = require("NPCs Go Home.util.cellTypeUtil")
local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
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
	if tes3.isAffectedBy({ reference = ref, effect = tes3.effect.vampirism }) then
		-- local isVampire = mwscript.getSpellEffects({reference = npc, spell = "vampire sun damage"})
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

function util.buildFollowerTable()
	---@type table<tes3mobileActor, true>
	local followers = {}
	for _, friend in ipairs(tes3.mobilePlayer.friendlyActors) do
		-- todo: check for ignored NPCs if followers list is ever used for anything other than part of checks.ignoredNPC()
		if friend ~= tes3.mobilePlayer then -- ? why is the player friendly towards the player ?
			followers[friend.object.id] = true
			log:debug("%s is a follower.", friend.object.id)
		end
	end
	return followers
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
	local isFargothActive = isFargoth and this.fargothCheck() or false
	local isClassBlacklisted = config.classBlacklist[npc.class.id:lower()]
	local isFollower = runtimeData.followers[npcRef.object.id]
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
	log:trace("Cell %s: interior: %s, behaves as exterior: %s therefore returning %s",
		cell.id, cell.isInterior, cell.behavesAsExterior, realInterior)

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
			cellEvaluator.calculateWorth(cell),
			cellEvaluator.pickCellFaction(cell),
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
				cellEvaluator.calculateWorth(cell),
				cellEvaluator.pickCellFaction(cell))
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

			-- TODO: this duplicates some code from cellEvaluator
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
			cellEvaluator.calculateWorth(cell),
			cellEvaluator.pickCellFaction(cell),
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
				cellEvaluator.calculateWorth(cell),
				cellEvaluator.pickCellFaction(cell),
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
	log:trace("Current time is %.2f (%snight), things are closed between %s and %s",
		hour, isNight and "" or "not ", config.closeTime, config.openTime)

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

local prisonMarkerId = "PrisonMarker"

---@param internalCellId string
---@param externalCellId string
local function isCityCell(internalCellId, externalCellId)
	-- Easy mode
	if string.match(internalCellId, externalCellId) then
		log:trace("Easy mode city: %s in %s", internalCellId, externalCellId)
		return true
	end

	local cityMatch = "^(%w+), (.*)"
	-- check for "advanced" cities
	local _, _, internalCity = string.find(internalCellId, cityMatch)
	local _, _, externalCity = string.find(externalCellId, cityMatch)

	if externalCity and externalCity == internalCity then
		log:trace("Hard mode city: %s in %s, %s == %s", internalCellId, externalCellId, externalCity, internalCity)
		return true
	end

	log:trace("Hard mode not city: %s not in %s, %s ~= %s or both are nil",
		internalCellId, externalCellId, externalCity, internalCity)
	return false
end

-- Doors that lead to ignored, exterior, canton, unoccupied, or public cells, and doors that aren't in cities.
---@param door tes3reference
---@param homeCellId string
function util.isIgnoredDoor(door, homeCellId)
	-- Don't lock prison markers.
	if door.id == prisonMarkerId then
		return true
	end

	-- Don't lock non-cell change doors.
	if not door.destination then
		log:trace("Non-Cell-change door %s, ignoring", door.id)
		return true
	end

	-- We use this a lot, so set a reference to it.
	local dest = door.destination.cell

	-- Only doors in cities and towns (interior cells with names that contain the exterior cell).
	local inCity = isCityCell(dest.id, homeCellId)

	-- Peek inside doors to look for guild halls, inns and clubs.
	local leadsToPublicCell = util.isPublicHouse(dest)

	-- Don't lock unoccupied cells.
	local hasOccupants = false
	for npc in dest:iterateReferences(tes3.objectType.npc) do
		if not util.isIgnoredNPC(npc) then
			hasOccupants = true
			break
		end
	end

	-- Don't lock doors to canton cells.
	local isCantonWorks = util.isCantonWorksCell(dest)

	log:trace("%s is %s, (%sin a city, is %spublic, %soccupied)",
		dest.id, util.isIgnoredCell(dest) and "ignored" or "not ignored",
		inCity and "" or "not ", leadsToPublicCell and "" or "not ", hasOccupants and "" or "un")

	return util.isIgnoredCell(dest) or
		not util.isInteriorCell(dest) or
		isCantonWorks or
		not inCity or
		leadsToPublicCell or
		not hasOccupants
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
