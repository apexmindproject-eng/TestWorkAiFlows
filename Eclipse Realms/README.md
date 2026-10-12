# Eclipse Realms (working title)

A grindy, competitive Roblox game. Pick a race, grow strong in your own territory, then push
through the Neutral Grounds into the Warzone where anything goes and the rewards are biggest.

**Races:** Vampires, Wolves, Witches, Humans, Monks. Each race has its own start zone, mission zone,
team and (coming next) unique powers.

## Map layout

Everything is arranged in rings around the Warzone at the centre of the map. Each race owns a
72-degree wedge of the outer rings, walled off from its neighbours.

```
   Start Zone  ->  Mission Zone  ->  Neutral Grounds (ring)  ->  WARZONE (centre)
   (safe)          (race-only)        (PvP, trade posts)         (no rules, high reward)
```

| Race     | Start zone       | Mission zone      |
| -------- | ---------------- | ----------------- |
| Vampires | Castle Noctis    | Crimson Crypts    |
| Wolves   | Moonfang Forest  | Howling Hollow    |
| Witches  | Hexwood Coven    | Thornveil Marsh   |
| Humans   | Aldermere Keep   | Ironfield Outpost |
| Monks    | Jade Monastery   | Serene Summit     |

New players spawn in the **Selection Chamber**, a platform floating above the Warzone, and pick a
race from the on-screen cards. The choice is saved, so returning players go straight to their
home zone.

## Opening it in Roblox Studio

1. Open `build/Place1.rbxl` in Roblox Studio.
2. Press **Play**. The map builds itself in about a second, the Selection Chamber appears, and
   the race picker shows up.
3. To bake the map permanently into the place (so it shows in the editor without pressing Play),
   run this in the Studio **Command Bar** and then save:

   ```lua
   require(game.ServerScriptService.MapBuilder).Build()
   ```

Race choices are saved with DataStores. In Studio, enable
*Game Settings > Security > Enable Studio Access to API Services* if you want saving to work in
Play mode. Set `REMEMBER_RACE = false` in `RaceService.server.lua` while testing to re-pick every
join.

## Project structure

The place file is generated from these source files with [Rojo](https://rojo.space) so the game
can live in git.

```
default.project.json                   Rojo project: services, Teams, Lighting, Remotes
src/ReplicatedStorage/Shared/
  RaceConfig.lua                       The five races: names, colours, powers, zone names
  MapConfig.lua                        Ring radii, sector math, GetZoneAt(position)
src/ServerScriptService/
  MapBuilder.lua                       Builds the whole map out of Parts
  Bootstrap.server.lua                 Runs MapBuilder on server start (unless baked in)
  RaceService.server.lua               Race selection, teams, spawns, DataStore save
src/StarterGui/RaceSelect/
  RaceSelectController.client.lua      Race selection screen (built from RaceConfig)
src/StarterPlayerScripts/
  ZoneHUD.client.lua                   Zone name badge + banner when crossing zones
build/Place1.rbxl                      The built place file. Open this in Studio.
```

Rebuild the place after editing source files:

```sh
rojo build default.project.json -o build/Place1.rbxl
```

## Roadmap

- [x] Map: start zones, mission zones, neutral ring, warzone, lobby
- [x] Race selection UI + teams + race spawns
- [ ] Race powers (3 per race, see `RaceConfig.lua` for the planned names)
- [ ] Combat and PvP rules per zone (safe / race-only / PvP / anything goes)
- [ ] Missions and mission boards
- [ ] Loot, currency, Eclipse Altar rewards in the Warzone
- [ ] Trade posts and shops on the neutral ring
