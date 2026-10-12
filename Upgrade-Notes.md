# Clover hub upgrade

The existing loader fetches the latest single-file `Clover-Retribution-UI.lua`.

Added shared controls and HUD across First Kingdom, Jungle, Arcane Dungeon, and a generic Explorer profile. Area detection uses streamed objects; select and load the correct area manually if detection is inconclusive. The Jungle and Arcane profiles incorporate the supplied scripts.

Shared controls include pause/resume, M1 interval, optional mana rest, low-health reset, mob/player/NPC ESP, nearby chest/drop/resource prompt collection, selected nearby quest prompts, saved settings, and diagnostics. Optional collection and quest interactions start disabled. Quest prompts do not automate dialogue or guarantee quest completion. Mana rest requires a readable current and maximum mana value.

Skill aiming uses the current target and a temporary camera position. Night Coffin aims at the ground ahead of the character. Cast confirmation checks the supplied casting/cooldown state and warns when neither appears. Camera and UI cleanup run when switching profiles.

## Validation

The complete merged file compiles successfully with official Luau 0.742. This verifies syntax and compiler limits, not Roblox execution or server acceptance. In-game testing is still required for movement, spell aim, interaction discovery, area detection, and saved settings. Local health manipulation is not a verified instant-kill mechanism.

## Test order

1. Reload the loader and check the console for errors.
2. Select the current area in Hub and load it. Start with one target and M1.
3. Enable one skill at a time; check cast warnings and Night Coffin placement.
4. Test pause/resume, profile switching, and low-health reset separately.
5. Enable ESP, then nearby collection and quest prompts individually.
6. Save settings, reload, and confirm the intended settings return.

## Research

Progression notes were checked against the [official Clover Retribution Trello](https://trello.com/b/xKxR061L/clover-retribution-official-trello), including [Jungle information](https://trello.com/c/XetqLZfE/946-the-jungle-basic-info), [Jungle questline](https://trello.com/c/CzM9BIS1/947-jungle-questline), and [Aetherion](https://trello.com/c/9xrsUh9w/735-aetherion-the-divine-arcana).

[This recent script demonstration](https://www.youtube.com/watch?v=PYx8Yu6L2AM) provided feature ideas. Its advertised features are not verification that this hub implements them. Full story automation, crafting, and dungeon queueing are not implemented; those need confirmed game interactions.
