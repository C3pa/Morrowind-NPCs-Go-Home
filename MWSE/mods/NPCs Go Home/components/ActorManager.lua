local Actor = require("NPCs Go Home.components.Actor")
local enum = require("NPCs Go Home.enum")
local housing = require("NPCs Go Home.components.housing")
local ReferenceManager = require("NPCs Go Home.components.ReferenceManager")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()

---@class NPCsGoHome.ActorManager : NPCsGoHome.ReferenceManager
---@field private actors table<tes3reference, NPCsGoHome.Actor>
---@field new fun(self: NPCsGoHome.ActorManager): NPCsGoHome.ActorManager
local ActorManager = ReferenceManager:new({ actors = {} })
ActorManager.__index = ActorManager

---@param reference tes3reference
function ActorManager:onReferenceDeactivated(reference)
	self:removeReference(reference)
	self.actors[reference] = nil
end

---@return fun(): NPCsGoHome.Actor
function ActorManager:iterate()
	return coroutine.wrap(function()
		for _, actor in pairs(self.actors) do
			coroutine.yield(actor)
		end
	end)
end

---@param actorRef tes3reference
---@param cell tes3cell
---@param actorType NPCsGoHome.actorType|integer
function ActorManager:addActor(actorRef, cell, actorType)
	if not self:addReference(actorRef) then return end
	local house
	if actorType ~= enum.actorType.siltStrider then
		house = housing.pickHomeForNPC(cell, actorRef)
	end
	local actor = Actor:new(actorRef, house)
	self.actors[actorRef] = actor
end

function ActorManager:update()
	log:debug("update")
	local isNight = util.isNight()
	local isBadWeather = util.isInclementWeather()
	for actor in self:iterate() do
		actor:update(isNight, isBadWeather)
	end
end

---@param reference tes3reference
---@return NPCsGoHome.Actor|nil
function ActorManager:getActor(reference)
	return self.actors[reference]
end

function ActorManager:clearAllActors()
	self.actors = {}
	self:clearAll()
end

return ActorManager
