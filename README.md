# League of Explorers

An exploration addon for the League of Explorers guild on WoW Forever. It
tracks the zones you explore, the rares and treasures you find, and the
points you earn, and shares them with the guild.

Open it with `/loe` (or `/explorers`), the minimap button, or the book tab on
the side of the Guild & Communities window.

You don't need to be in a guild to use it: see [Solo mode](#solo-mode).

## Pages

The window is laid out as a book, with a tab for each page. It opens and
closes like one: the cover (with your name and rank on it) swings open over
the spine and two blank pages follow it, and it swings shut again when you
close it. **Open and close like a book** in the settings turns this off.

- **Guild**: how many members use the addon, guild totals, your rank,
  this week's leaders and recent activity.
- **My Journal**: your rank and totals, and every zone with a dot for each
  of its areas. Select a zone to see its map with your explored areas.
- **Bestiary**: every rare, grouped by zone and creature type. Rares no one
  in the guild has found show as an unnamed silhouette. Rares the guild has
  found show as a named silhouette until you find them yourself. Each rare's
  page shows who found
  it first, sightings, your notes and any bounty on it.
- **Expeditions**: the weekly hunt, plus expeditions and bounties posted
  by officers. Rare goals in all of these need a kill, not just a sighting. An expedition pays everyone who completes it, with half
  extra for the first. A bounty pays only the first. Only progress made
  after something is posted counts.
- **Submissions**: suggest a place to the officers. Approved places earn
  points and become guild places that anyone can visit.
- **Leaders**: leaderboards by week, month, season and all time, your rank,
  collections and season winners.

### How things are detected

- **Exploration** uses the game's explored-map data, so "fully explored"
  means every area of the zone has been explored.
- **Rares** are detected when they appear on your minimap, show a nameplate,
  or are targeted or moused over.
- **Treasures** are detected when they appear on your minimap.
- **Kills**: addons can't read the full combat log on Forever, so a rare
  counts as killed when you loot its corpse, or when you see it die after
  fighting it yourself. A corpse tagged by someone else never counts. In a
  group, everyone who loots it or was fighting it gets the kill.

### Points

Points are for the leaderboards. Your characters count together, and each
find counts once per player.

| Action | Points |
| --- | --- |
| Discover a new zone | 10 |
| Fully explore a zone | 40 |
| Reach a new continent | 25 |
| Find a rare creature | 10 |
| First in the guild to find a rare | +40 |
| Find a new type of treasure | 15 |
| Visit a guild place | 25 |
| Each target of the weekly hunt | 15 |
| Complete the weekly hunt | +25 |
| Have a submission approved | 30 |
| Find every rare in a zone (collection) | 30 |
| Fully explore a continent (collection) | 100 |
| Complete a guild expedition | set by officers |

Exploration from before you installed the addon earns no points, but counts
toward your rank.

### Ranks

Ranks are based on what you've done, not points. Each rank needs a mix of
things (plus everything the ranks below it need), so you can't reach it by
doing only one thing.

| Rank | Needs |
| --- | --- |
| Wanderer | nothing |
| Pathfinder | 10 zones discovered |
| Scout | 20 zones, 10 rares |
| Trailblazer | 30 zones, 5 fully explored, 25 rares |
| Wayfinder | 40 zones, 10 fully explored, 50 rares |
| Cartographer | 20 fully explored, 80 rares |
| Pioneer | 30 fully explored, 120 rares, 1 guild first |
| Master Explorer | 40 fully explored, 200 rares, 3 guild firsts |
| Grand Explorer | every zone fully explored, 300 rares, 5 guild firsts |

### Rare alerts and map pins

When you spot a rare alive, guildmates who are online hear about it. Which
sightings pop up for you is set in the settings (or `/loe alerts`):

- **Your zone and hunted rares** (default): rares in the zone you're in, and
  any rare you're hunting for the weekly hunt, a bounty or an expedition.
- **Hunted rares only**
- **Every rare**
- **Off**

Rares more than 10 levels below you don't pop up unless you're hunting them,
and at most 4 others pop up in any 10 minutes. Click a pop-up to set a
waypoint. When the rare is killed, it's taken off everyone's map.

Pins on the world map and minimap show:

- rares spotted in the last 10 minutes
- rares you need to kill, where you or the guild last saw them
- guild places (faded once you've visited)

The addon never shows a rare's spawn point from its rare list, only places
someone in the guild has actually seen it. Hover a pin for details and click
it to set a waypoint. On the minimap, rares you're hunting stay on the edge
when they're out of range. World map and minimap pins can each be turned off
in the settings.

### Pop-ups

Pop-ups appear at the top of the screen and wait while the game is showing a
zone name, so the two don't overlap. To move them, use **Move pop-ups** in
the settings (or `/loe toasts move`), drag the box, and right-click it when
done. `/loe toasts reset` puts them back.

### Mains and alts

Your characters share one rank and one row on the leaderboards. Choose your
main in the settings (the cog); every character on your account uses it.

### Ongoing content

- **Weekly hunt**: each level band (1-19, 20-29, 30-39, 40-49, 50-60) gets
  its own hunt every week: three rares and two zones for those levels,
  outside the other faction's starting zones. Kill the rares and enter the
  zones before the week ends. They count even if you've done them before.
  Your band is set by your level at the start of the week, and you get one
  hunt a week across all your characters.
- **Seasons**: a season is three months. Season 1 is autumn 2026 (October to
  December), Season 2 is winter 2027, and so on. Each season's top three
  players are listed under Season winners.
- **Guild places**: approved submissions. Stand within 30 yards of one to
  visit it.
- **Collections**: find every rare in a zone, or fully explore a continent.
- **Guild milestones**: shared goals for rares, fully explored zones and
  guild places. Reached milestones show in recent activity.
- **Expeditions and bounties** from the officers.

## Solo mode

Solo mode is for using the addon on your own. Turn it on or off with
**Solo mode** in the settings, or `/loe solo`. It's set per character, and
starts on for a character that isn't in a guild.

In solo mode:

- The Guild, Leaders and Submissions pages are hidden. Expeditions becomes
  **Weekly hunt**, with just your own hunt.
- Nothing is sent to or taken from the guild: no shared finds, rare alerts,
  ranks in the guild window or chat, expeditions, bounties or guild places.
- Your exploration, rares, treasures, points, rank, weekly hunt, Bestiary
  and map pins all work as usual. Finds count for you alone.
- There's no bonus for being first in the guild to find a rare, and ranks
  don't ask for guild firsts.

Nothing is deleted when you switch, so turning solo mode off brings the
guild features back with everything you found in the meantime.

## Guild window and chat

For guild members who use the addon:

- **Guild window**: an icon in their rank's colour next to their name, and
  their rank, points, weekly position and finds in the tooltip.
- **Guild chat**: their rank in brackets before their name in guild and
  officer chat, e.g. "[Guild] [Cartographer] [Brennan Black]: ...". It works
  alongside Kinship and Total RP 3 roleplay names too.

Both can be turned off in the settings. They only add to the game's own
display, so Kinship's roleplay names still work. Addons can't give real
in-game titles.

## Officers

Guild ranks 0 and 1 count as officers by default (0 is the guild master).
The guild master can change this with `/loe officers <rank>`, or in the
settings.

Anyone can try the officer and guild master tools with **Preview officer
tools** in the settings. While it's on, you count as guild master on your
own computer only. Nothing you post, review or change is sent to the guild,
and it's all deleted when you turn preview off.

## Credits

The rare creature list in `Data/Rares.lua` is exported from Polestar's
Polestar Codex data (GPL-3.0), which was built from pfQuest (MIT),
QuestieDB (Questie-Forever) and the game client's map tables. Only facts
are used: IDs, names, levels and locations. `tools/export_rares.lua`
rebuilds it from an installed Polestar_Codex.

## Commands

- `/loe`: open or close the window
- `/loe status`: check which game features the addon can use
- `/loe minimap`: show or hide the minimap button
- `/loe toasts`: turn discovery pop-ups on or off
- `/loe toasts move`: move the pop-ups (`/loe toasts reset` puts them back)
- `/loe sync`: guild sync status
- `/loe demo`: a tour of every page and pop-up with an example guild
  (nothing is sent or saved; type `/loe demo` again to stop)
- `/loe whoami`: show your character name as the game and addon see it
- `/loe kofi`: show the Ko-fi link
- `/loe officers`: show which guild ranks are officers
- `/loe alerts`: choose which guild rare sightings pop up
- `/loe solo`: switch between solo and guild mode

## Planned

- Officers setting point values for their guild.
- Fixes and changes from guild feedback.

## For developers

- `tools/test_logic.lua` runs the addon against a fake game API:
  `luatex --luaonly tools/test_logic.lua`, or any Lua 5.1+.
- `tools/export_areas.py` rebuilds `Data/Areas.lua` from an export of the
  client's map overlay tables.

## Support

I make this addon for the League of Explorers guild. If you'd like to
support it, I'm on [Ko-fi](https://ko-fi.com/vaxorus).
