local Class = require("NPCs Go Home.Class")
local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")
local util = require("NPCs Go Home.util")

---@class NPCsGoHome.Actor
---@field private reference tes3reference
---@field private log mwseLogger
---@field private hasHouse boolean
local Actor = Class:new()
Actor.__index = Actor

---@param reference tes3reference
---@param house? NPCsGoHome.house
---@return NPCsGoHome.Actor
function Actor:new(reference, house)
	local o = Class.new(self, {
		reference = reference,
		hasHouse = house and true or false,
		log = mwse.Logger.new({
			moduleName = string.format("Actor: %s", reference.id)
		})
	})
	if not reference.data.NPCsGoHome then
		---@type NPCsGoHome.npcReferenceData
		reference.data.NPCsGoHome = {
			disabled = false,
			state = enum.actorState.originalLocation,
			routine = {
				originalCellId = reference.cell.id,
				originalPosition = util.toTable(reference.position),
				originalOrientation = util.toTable(reference.orientation)
			},
		}
		if house then
			reference.data.NPCsGoHome.house = {
				isHome = house.isHome,
				cellId = house.cellId,
				position = util.toTable(house.position),
				orientation = util.toTable(house.orientation)
			}
		end
	end
	Actor.storeAIPackage(o)

	return o
end

---@return NPCsGoHome.npcReferenceData
function Actor:getData()
	return self.reference.data.NPCsGoHome
end

function Actor:getState()
	return self:getData().state
end

---@private
---@param newState NPCsGoHome.actorState|integer
function Actor:setState(newState)
	local data = self:getData()
	data.state = newState
end

---@private
function Actor:storeAIPackage()
	local data = self:getData()
	local mobile = self.reference.mobile
	if not mobile or not mobile.aiPlanner then
		self.log:warn("No mobile available to store current AI package.")
		return
	end
	-- TODO: this needs to be update if we start messing with actors that have AI packages other than wander.
	local package = mobile.aiPlanner:getActivePackage() --[[@as tes3aiPackageWander]]
	local idles = {}
	for _, node in ipairs(package.idles) do
		table.insert(idles, node.chance)
	end
	data.originalPackage = {
		idles = idles,
		range = package.distance,
		duration = package.duration,
		-- TODO: these two are unconfirmed.
		time = package.hourOfDay,
		reset = package.isReset
	}
end

function Actor:resetAI()
	local package = self:getData().originalPackage
	if not package then
		self.log:error("No package stored for an NPC to restore.")
		return
	end
	-- TODO: may need to move the actor to starting location and only then resume wandering
	tes3.setAIWander({
		reference = self.reference,
		idles = package.idles,
		range = package.range,
		duration = package.duration,
		time = package.time,
		reset = package.reset
	})
end

function Actor:getReference()
	return self.reference
end

---@private
function Actor:canGoHome()
	if not self.hasHouse then
		return false
	end
	if self:getState() == enum.actorState.originalLocation then
		return true
	end
	return false
end

---@private
function Actor:moveHome()
	local house = self:getData().house
	if not house then
		self.log:error("No house found when moving an NPC home.")
		return
	end
	tes3.positionCell({
		reference = self.reference,
		cell = house.cellId,
		position = house.position,
		orientation = house.orientation
	})
	self:setState(enum.actorState.home)
end

---@private
function Actor:moveBack()
	local routine = self:getData().routine
	tes3.positionCell({
		reference = self.reference,
		cell = routine.originalCellId,
		position = routine.originalPosition,
		orientation = routine.originalOrientation
	})
	self:setState(enum.actorState.originalLocation)
end

---@private
function Actor:disable()
	if self:getState() ~= enum.actorState.originalLocation then return end
	self.reference:disable()
	self:setState(enum.actorState.disabled)
	local data = self:getData()
	data.disabled = true
end

---@private
function Actor:enable()
	if self:getState() ~= enum.actorState.disabled then return end
	self.reference:enable()
	self:setState(enum.actorState.originalLocation)
	local data = self:getData()
	data.disabled = false
end

function Actor:goBack()
	local state = self:getState()
	if state == enum.actorState.disabled then
		self:enable()
	elseif state == enum.actorState.home then
		self:moveBack()
	end
end

---@param isNight boolean
---@param isBadWeather boolean
function Actor:update(isNight, isBadWeather)
	if (self.reference.cell.restingIsIllegal and not config.disableNPCsInWilderness)
	or not config.disableNPCs then
		self:goBack()
		return
	end
	local goHome = isNight or isBadWeather
	-- TODO: restore util.isBadWeatherNPC check. Those NPCs shouldn't be disabled on bad weather.
	-- + config.keepBadWeatherNPCs
	if goHome then
		if config.moveNPCs and self:canGoHome() then
			self:moveHome()
		else
			self:disable()
		end
		return
	end

	self:goBack()
end

return Actor
