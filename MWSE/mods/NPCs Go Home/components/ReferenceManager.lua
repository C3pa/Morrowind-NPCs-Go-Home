local Class = require("NPCs Go Home.Class")

---@class NPCsGoHome.ReferenceManager
---@field private references table<tes3reference, true>
local ReferenceManager = Class:new()
ReferenceManager.__index = ReferenceManager

function ReferenceManager:new(data)
	local o = Class.new(self, data)
	o.references = {}
	return o
end

---@protected
---@param reference tes3reference
---@return boolean added
function ReferenceManager:addReference(reference)
	if self.references[reference] then
		return false
	end
	self.references[reference] = true
	return true
end

---@protected
---@param reference tes3reference
function ReferenceManager:removeReference(reference)
	self.references[reference] = nil
end

---@protected
function ReferenceManager:clearAll()
	self.references = {}
end

---@private
---@param reference tes3reference
function ReferenceManager:onReferenceDeactivated(reference)
	self:removeReference(reference)
end

---@protected
function ReferenceManager:registerEvents()
	event.register(tes3.event.referenceDeactivated, function(e)
		self:onReferenceDeactivated(e.reference)
	end)
end

---@return fun(): tes3reference
function ReferenceManager:iterate()
	return coroutine.wrap(function()
		for ref in pairs(self.references) do
			coroutine.yield(ref)
		end
	end)
end

return ReferenceManager
