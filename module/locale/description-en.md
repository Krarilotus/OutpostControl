# Outpost Control

**Author**: Monsterfish
**Version**: 1.0.0

More say over the European and Arabian outposts you place in the map editor. Every part can be
switched off in the settings.

## The Defenders page

Select an outpost in the map editor. The button at the top of its panel now switches between
two pages:

- **Attackers** - the game's own page: which troops the outpost sends, how big the waves are,
  and how long it waits before the first one.
- **Defenders** - the same eight troop buttons and two sliders, with a new meaning:
  - **Troop buttons:** which troops guard the outpost. Pick several and they take turns. A
    European outpost offers archers, crossbowmen, spearmen, pikemen, macemen, swordsmen,
    knights and black monks; an Arabian one Arabian archers, slingers, horse archers, Arabian
    swordsmen, slaves, assassins, fire throwers and crossbowmen. With nothing picked the
    outpost uses archers, as the game does.
  - **Amount:** how many guards stand around the outpost, from none to 8. Fallen guards come
    back after a while, as before.
  - **Growth:** how fast the outpost's attacks build up. Normally every wave makes the next one
    come sooner and fill up faster. None keeps every wave like the first one for the whole game;
    Full is the game's own pace.

## Attackers' jobs

Normally a whole wave does the same thing: walk up and attack a building, digging at the moat
now and then. With this module, each wave splits up by unit type when it leaves, and each part
gets a job that suits it:

| Unit | First job (default share) | The rest |
| --- | --- | --- |
| Slaves | fill the moat (50%) | burn and wreck buildings |
| Spearmen | fill the moat (50%) | hack at walls and gates |
| Macemen | fill the moat (30%) | wreck buildings |
| Swordsmen | hack at walls and gates (60%) | wreck buildings |
| Arabian swordsmen | hack at walls and gates (50%) | wreck buildings |
| Knights | hunt the lord (40%) | ride round the castle |
| Archers, Arabian archers | fill the moat (30%) | walk up and shoot the troops they meet |
| Slingers | walk round the castle (30%) | walk up and shoot the troops they meet |
| Horse archers | ride round the castle (100%) | walk up and shoot the troops they meet |
| Fire throwers | burn buildings (60%) | walk up and burn the troops they meet |

Riding round the castle means circling it a good way out and cutting down workers and troops
outside the walls. Knights only go for the lord when they can reach him; otherwise they ride
round the castle too. A troop with nothing left to do (the moat is filled, no wall in the way)
attacks the way the whole wave would have. Catapults and fire ballistas attack as before. Every
share can be changed in the settings.

## Saves and maps

What you set for each outpost is kept in the map and in saves (through the Map Extensions
module). Played without this module, the map still works: the outpost keeps the number of
guards you set (at least one, as archers), and its waves grow at the game's own pace.
