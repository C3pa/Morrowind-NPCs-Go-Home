---@enum NPCsGoHome.cantonPolicy
return {
	-- Canton plazas are considered exterior cells and NPCs should go home from there.
	exterior = 1,
	-- Canton plazas are considered as public interior cells and NPCs from nearby exterior cells without a home
	-- can stay in the plaza for the night.
	public = 2,
	-- Canton plazas are considered as interior cells and NPCs can stay here for the night.
	interior = 3,
}
