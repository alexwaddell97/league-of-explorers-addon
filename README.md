# League of Explorers

An adventurer's journal for the guild on WoW Forever. It records the zones you
explore, the rare creatures and treasures you find, and the points you earn.

Open it with `/loe` (or `/explorers`) or the book button on the minimap.

## Stage 1 (this version)

The journal is built around the map. Across its top is the real map of the
zone in view, drawn from the game's own map tiles with the areas you have
explored painted in. It follows you on the Journal page, shows the zone you
pick in the Atlas, and pins where a rare or treasure was last seen.

There are two looks, switched with the gear on the map or `/loe look`:
**Explorer** (the League's own: slate panels, a turquoise accent) and
**Blizzard** (the game's own metal rim, rock backdrop and red buttons).

- **Journal**: your figures at a glance, your points, the zone nearest to
  fully explored, and a timeline of your discoveries.
- **Atlas**: every zone on each continent, with a dot for each of its areas.
  Forever's own zones (Mount Hyjal, Zephras Isle, Riverglades,
  Shen'dralas) are included.
- **Bestiary**: rare creatures you have sighted, with where and when.
  Each sighting can be marked on your map.
- **Treasures & Secrets**: treasure chests the game marks on your minimap.
- **Hall of Fame**: points this week, this month and all time; points by deed;
  your characters ranked; and the scale of rewards.

### How things are detected

- **Exploration** uses the game's own explored-map data, so "fully explored"
  means every area of the zone has been charted.
- **Rares** are noticed when they appear on your minimap, show a nameplate,
  or are targeted or moused over.
- **Treasures** are noticed when they appear on your minimap.

### Points

| Deed | Points |
| --- | --- |
| Discover a new zone | 10 |
| Fully explore a zone | 25 |
| Discover a new continent | 50 |
| Find a rare creature | 20 |
| Find hidden treasure | 30 |

These deeds come in later stages: first guild discovery of a rare (50), a
secret location (30) and a guild expedition (50).

Each deed is rewarded once per character, so seeing a rare again or walking
back into a zone earns nothing more. The first time a character opens the
journal, exploration it had already done is written in without points.

## Commands

- `/loe`: open or close the journal
- `/loe status`: what the journal can detect on this client
- `/loe minimap`: show or hide the minimap button
- `/loe toasts`: turn discovery pop-ups on or off
- `/loe look`: switch between the Explorer and Blizzard looks

## Coming next

- **Stage 2**: guild sync, a shared bestiary, first guild discoveries and
  guild leaderboards.
- **Stage 3**: ranks, achievements, titles and guild expeditions.
- **Stage 4**: polish and officer settings.

## For developers

- `tools/test_logic.lua` runs the addon against a fake game API:
  `luatex --luaonly tools/test_logic.lua`, or any Lua 5.1+.
- `tools/export_areas.py` rebuilds `Data/Areas.lua` from an export of the
  client's map overlay tables.
