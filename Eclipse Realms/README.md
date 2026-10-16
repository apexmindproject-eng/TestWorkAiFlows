# Eclipse Realms (working title)

A grindy, competitive Roblox game. Pick a race, grow strong in your own territory, then push
through the Neutral Grounds into the Warzone where anything goes and the rewards are biggest.

**Races:** Vampires, Wolves, Witches, Humans, Monks. Each race has its own start zone, mission zone,
team and (coming next) unique powers.

## The world

A single continuous world about 2.5 km across, built from real Roblox terrain: a central crater,
a ring of open plains, a river with five stone bridges, and five large territories walled off from
each other by mountain ridges. A ring of snow-capped mountains closes the horizon.

```
   Territory (settlement + wilds)  ->  River bridge  ->  Neutral Grounds  ->  Crater rim  ->  THE WARZONE
   safe, missions, exploration         contested, caravan camps, old ruins     lawless, Eclipse Altar
```

Each race's territory is one place, not a set of zones: a lived-in settlement where missions are
picked up from somewhere that makes sense, with the mission country spreading out around it toward
the river.

| Race     | Settlement        | Where missions are posted              | Out in the wilds                                    |
| -------- | ----------------- | -------------------------------------- | --------------------------------------------------- |
| Humans   | Aldermere Keep    | The Gilded Stag tavern, gate bounties  | Farmland, bandit camp, old mine, ruined watchtower  |
| Vampires | Castle Noctis     | The Blood Court in the keep            | Thrall village, graveyard, crypt, dead woods        |
| Wolves   | Moonfang village  | The Great Lodge hunt board             | Old-growth forest, dens, ponds, hunters' camp       |
| Witches  | Hexwood Coven     | The Covenstead grimoire wall           | Marsh, sunken chapel, witchfinder camp, hag's hut   |
| Monks    | Jade Monastery    | The Hall of Scrolls                    | Bamboo slopes, waterfall, hot spring, summit shrine |

New players see a slow flyover of the world while they choose a race. The choice is saved, so
returning players go straight home.

## Opening it in Roblox Studio

1. Open `build/Place1.rbxl` in Roblox Studio.
2. Press **Play**. The world generates itself (terrain and all) in a few seconds, then the
   flyover and race picker appear.
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
src/ServerScriptService/MapBuilder/
  init.lua                             Orchestrates the build
  Lib.lua                              Part, terrain, light and sign helpers; ground height
  Props.lua                            Trees, houses, towers, bridges, furniture, camps
  World.lua                            Terrain base, river, mountains, roads, Neutral Grounds, Warzone
  Territories/*.lua                    One file per race territory
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

- [x] World: terrain, five territories with settlements and wilds, river, Neutral Grounds, Warzone
- [x] Race selection with flyover, teams and race spawns
- [x] Mission boards with notices in every settlement (reading them does nothing yet)
- [ ] Race powers (3 per race, see `RaceConfig.lua` for the planned names)
- [ ] Combat and PvP rules per zone (safe / race-only / PvP / anything goes)
- [ ] Missions and mission boards
- [ ] Loot, currency, Eclipse Altar rewards in the Warzone
- [ ] Trade posts and shops on the neutral ring
