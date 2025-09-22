local config = require("NPCs Go Home.config")
local nameUtil = require("NPCs Go Home.util.nameUtil")


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
function util.isFollower(reference)
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
	local isFollower = util.isFollower(npcRef)
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

---@param cell tes3cell
function util.isCantonCell(cell)
	if util.isInteriorCell(cell) then
		return false
	end
	for door in cell:iterateReferences(tes3.objectType.door) do
		if util.isTeleportDoor(door) and nameUtil.isCantonWorksCell(door.destination.cell) then
			return true
		end
	end
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

---@param door tes3reference
function util.isTeleportDoor(door)
	if door.destination then
		return true
	end
	return false
end

return util
