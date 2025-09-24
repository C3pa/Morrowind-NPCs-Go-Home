---@meta

--- Stored AI Wander package configuration of this NPC.
---@class NPCsGoHome.originalPackage
---@field idles integer[] An array with 8 values that corresponds to the chance of playing each idle animation. For more info see [tes3aiPackageWander.idles](https://mwse.github.io/MWSE/types/tes3aiPackageWander/#idles).
---@field range integer
---@field duration integer How long the actor will be wandering around, in hours.
---@field time integer
---@field reset boolean

---@class NPCsGoHome.routine
---@field originalPosition NPCsGoHome.vector3Table
---@field originalOrientation NPCsGoHome.vector3Table
---@field originalCellId string

-- This table has the same layout as NPCsGoHome, but position and orientation are stored as Lua tables
-- so it can be serialized in reference.data table.
---@class NPCsGoHome.houseSerialized
---@field isHome boolean True if this is a home belonging to this npc.
---@field cellId string The id of the home.
---@field position NPCsGoHome.vector3Table
---@field orientation NPCsGoHome.vector3Table

-- TODO: consider removing disabled field
---@class NPCsGoHome.npcReferenceData
---@field disabled boolean
---@field routine NPCsGoHome.routine
---@field originalPackage NPCsGoHome.originalPackage?
---@field state NPCsGoHome.actorState|integer
---@field house NPCsGoHome.houseSerialized?
