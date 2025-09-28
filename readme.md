# NPCs Go Home #

A fork of [Celediel's NPCs Go Home](https://github.com/celediel/Morrowind-NPCs-Go-Home). This is a continuation of their work with the intention of fixing the remiaining issues and adding new features as well. Some initial work has been done to move to newer MWSE APIs. Much of the codebase was refactored to make it easier to work with. As for the functionality of the original, the basic level of moving/disabling NPCs at night as in the original now works. I also made a quick test of the nighttime door locking feature and it appears to work for me. For now I've only tested the functionality of this mod in Balmora, and becuse of that I'm not sure how many NPCs it covers in various settlements on Vvardenfell, mainland or other provinces. I consider that it can be used in regular playtroughs. Please leave any `mwse.log` files that contain errors or crashes due to this mod in the NPCs Go Home thread of the [Morrowind Modding Community Discord server](https://discord.me/mwmods).

Now follows the readme of the original with some updates. Some points are still outdated:

### The "Big" Stuff ###

- NPC "homes"
  - Outside NPCs who have homes (local cell that contains their name, i.e.: NPC Fargoth and cell "Seyda Neen, Fargoth's House") are currently paired with the inside cell of their home
  - Other NPCs are configurably paired with local public houses (Inns, temples, and guildhalls of their faction)
- Option to move NPCs into their home rather than disable them
    - Working on a better variety of positions in cells
- Moved NPCs persist on save/load

### Other Stuff ###

- ~~Timer for updating everything, configurable interval~~
- Disabled NPCs are reenabled even if the option to disable NPCs is off
- Silt Striders and pack guars are disabled as well
- Travel agents, their silt striders, and configured races/classes optionally stay in inclement weather
- When locking doors, cells that contain NPCs of any class on the ignore list are left alone
  - Cells that are >= 67% (configurable) one faction will be public, if that faction is on the ignore list
  - Cells of player joined factions are also public
  - Additionally, NPCs in those cells can still be interacted with
- Cells with no NPCs are not locked

### Debug / Devel Stuff ###

- ~~data/positions.lua contains positions used for NPC placement in homes and public houses~~
- ~~I haven't done many as it's tedious work, so I've added debug some debug keybinds to help:
  - ~~ctrl + c prints to mwse.log position data sorta properly formatted for positions.lua~~
  - ~~alt + c prints to mwse.log all the current runtime data, found in common.runtimeData~~
    - ~~includes: public houses and homes found for NPCs: cells that NPCs will be moved to, needing position data~~

## WIP ##

- Currently NPCs without a home are moved into local cells with matching faction, or a random public cell
- NPCs are classed based on the worth of their equipped items, and inventory
  - NPC worth is a table of: equipped items worth, inventory items worth, barter
    gold and if a merchant with a cell, the worth of items in containers in that
    cell that the NPC sells is added, and the total of all calculated values
- Public houses are classed based on the worth of NPCs in the cell

## TODO ##

- Move non-faction NPCs who don't have homes to temples or inns based on their "worth"
- Pick temple for the poorest NPCs, or classed inns based on NPC/inn "worth"
- Only disable NPCs while the player isn't looking. [This](https://mwse.github.io/MWSE/types/niCamera/#worldpointtoscreenpoint) function will return nil if the actor's position isn't in the camera view.
- Make NPCs walk to their home using: tes3.setAIActivate/tes3.setAITravel/npcRef:activate(doorRef)
- Consider making NPCs that are always in their homes get a schedule to walk around the town a bit.

## Known issues ##

- ~~If NPCs in a town are moved, and the player moves far away from that town before they're moved back, then
  saves and reloads, those NPCs will probably stay moved.~~ should be fixed

## Recommended mods

- [Patch for Purists](https://www.nexusmods.com/morrowind/mods/45096). There are many NPCs with homes that are spelled differently, be it a misspelling in the NPC name or the house name. Patch for Purists fixes many of these instances. This allows this mod to correctly find homes for more NPCs. That leads to the preferred path of moving these NPCs to their homes at night instead of just disabling them. To illustrate this, in Balmora, 12 people are wandering around, with 4 of them having homes in the town. Out of these 4 instances, there are 3 misspellings.
