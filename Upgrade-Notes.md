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
Enable Kaldris > Fight spawned Kaldris only inside the Ashen Crucible. This disables other farm routes. It looks for the live Kaldris model and waits in place if absent; it does not travel to mob camps or the altar. Aerial dodge still depends on a visible Casting signal and needs live validation.

## Startup and pause
Every execution starts with farming, automatic attacks, automatic skills, collection, resets and party invitations off. Target selections and thresholds persist. Manually enabling combat clears a stale teleport pause. The pause control also gates the new skill and movement paths.

## Validation
- Complete hub compiled with the Luau compiler.
- Regression checks passed for mana values and invalid data, idle startup, retained ore selection, combat reactivation, exclusive Kaldris acquisition and mana-reset gating.
- Autosave checks passed for account-specific paths, debouncing, config capture, selections, false values and profile isolation.
- No live Roblox combat, ore collection, dive avoidance or server-side kill success has been verified for this merge.

Stamina detection remains separate from mana. Missing stamina data is not evidence of low stamina.
