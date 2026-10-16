# Clover Hub update - October 13, 2026

Merged the complete supplied world-farming script into the existing hub. The animated UI, HUD, Jungle and Arcane profiles remain included.

## Added
- Ore Farm: Stone, Copper, Iron, Manastone and Dragonite selection; mining duration and delay; live bosses interrupt mining.
- Kraken Farm: live Desert Kraken targeting, dive/emerge checks, and adjustable retreat distance, height and recovery delay.
- Party: opt-in player invitations and retry interval. Automatic invite acceptance and party damage waiting remain disabled, as in the supplied source.
- Movement: pin client-owned regular mobs. Phase-driven bosses are excluded from pinning.
- Skills: optional silent aim, weapon equip toggle, mana threshold, low-mana reset, cached skill discovery and a separate skill worker.
- Instant kill method selection with bounded retries. Local kill attempts remain unverified; normal combat continues when attempts fail.
- Account-specific settings files with migration from the old hub settings file.

## Kaldris
Kaldris > Auto summon / fight / reset / repeat starts OFF. Enabling it disables competing farm routes, enables existing selected auto skills, travels to a discovered Ember Altar prompt and activates it once. A live Kaldris takes priority. After a death signal and an eight-second phase check, the character resets; the altar route resumes as soon as the new living character exists, with no extra respawn timer. Unexpected despawns wait for a phase or death signal. An unconfirmed summon stops after 90 seconds instead of spending more sigils.

Altar dialogue fix: opening the proximity prompt now enters a separate dialogue state. The cycle selects the visible normal "Press a Cinder Sigil into the altar!" option once, then arms Fight spawned Kaldris while awaiting the boss. Unhinged and Walk Away are excluded. An already-open altar dialogue is handled too. Diagnostics now resolves PlayerGui within its callback, fixing the line-1745 nil reference. Screenshot-text selection and the complete dialogue-to-combat state transition have mocked regression coverage.

At level 200 or higher, the enabled spin-prestige option interrupts the boss cycle, resets, travels to the discovered Wizard King/Fabio prompt and chooses the visible spin-prestige dialogue. Only the matching prestige/spin choices are automated; a generic confirmation additionally requires visible spin/reset context. A detected new level of 0–5 resumes the altar cycle. Unknown dialogue or unconfirmed prestige stops the loop. Turning spin prestige off stops the cycle at level 200 instead.

The altar and Wizard King must be streamed to discover their positions. Positions remain cached for this script session and are used to return and request streaming. Unknown locations are not guessed. Print cycle diagnostics reports route, level and visible dialogue details. The sequence has mocked state-transition tests and compiles, but live NPC dialogue, boss phase timing and server-side reset/summon behavior still need validation. Aerial dodge depends on a visible Casting signal.

## Startup and pause
Every execution starts with farming, automatic attacks, automatic skills, collection, resets and party invitations off. Target selections and thresholds persist. Manually enabling combat clears a stale teleport pause. The pause control also gates the new skill and movement paths.

## Validation
- Complete hub compiled with the Luau compiler.
- Regression checks passed for mana values and invalid data, idle startup, retained ore selection, combat reactivation, exclusive Kaldris acquisition and mana-reset gating.
- Autosave checks passed for account-specific paths, debouncing, config capture, selections, false values and profile isolation.
- No live Roblox combat, ore collection, dive avoidance or server-side kill success has been verified for this merge.

Stamina detection remains separate from mana. Missing stamina data is not evidence of low stamina.

## Jungle farming follow-up
Jungle_Island is now recognized before First Kingdom detection. Mob discovery and spawn routing search nested folders, support dictionary and array spawn pools, and skip disabled spawns. Choose mobs under Jungle Mobs before enabling Auto Mob Farm; enabling it also enables M1/following and clears pause. New mobs remain unselected. Refresh mobs and routes and Print mob routes assist with streamed camps. Luau compilation and mocked spawn-route tests passed; live gameplay still requires testing.
