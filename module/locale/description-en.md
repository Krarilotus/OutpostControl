# Outpost Control

**Author**: Monsterfish
**Version**: 1.0.8

More say over the European and Arabian outposts you place in the map editor. Every part can be
switched off in the settings.

## The outpost panel

Select an outpost in the map editor. The button at the top of its panel now switches between
two pages. Each slider shows its value to its right.

- **Attackers** - which troops the outpost sends, as in the game, with three sliders:
  - **Size:** how big the waves are (the game's own).
  - **Start Delay:** how long it waits before the first wave (the game's own), shown in seconds
    at normal speed.
  - **Growth:** how fast the attacks build up. Normally every wave makes the next one come
    sooner and fill up faster. None keeps every wave like the first one for the whole game;
    Full (all the way right) is the game's own pace.
- **Defenders** - the same eight troop buttons with a new meaning, and one slider:
  - **Troop buttons:** which troops guard the outpost. Pick several and they take turns. A
    European outpost offers archers, crossbowmen, spearmen, pikemen, macemen, swordsmen,
    knights and black monks; an Arabian one Arabian archers, slingers, horse archers, Arabian
    swordsmen, slaves, assassins, fire throwers and crossbowmen. With nothing picked the
    outpost uses archers, as the game does.
  - **Amount:** how many guards stand around the outpost, from none to 50. Fallen guards come
    back one at a time; the more you set, the quicker they come, so a full set takes about as
    long to come back as the game's 8 guards do (a guard every 30 seconds for 8, every 5
    seconds for 50, at normal speed).
  - **Stances:** foot soldiers who fight hand to hand (spearmen, pikemen, macemen, swordsmen,
    black monks, slaves, assassins) guard in the defensive stance and go for enemies who come
    near; knights are aggressive and charge enemies further off; horse archers are aggressive
    too and ride a patrol round the outpost. Archers, crossbowmen, slingers and fire throwers
    stand and shoot as the game's own outpost archers do.

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
attacks the way the whole wave would have. Every share can be changed in the settings.

## Siege engines on the way

Catapults and fire ballistas from an outpost walk towards the castle they attack, and stop to
shoot as soon as something of the enemy is in range - like your own siege engines do with a
target:

- **Catapults** (and trebuchets or mangonels, if a map's outposts send them) shoot the nearest
  enemy building in range, then the next one.
- **Fire ballistas** shoot enemy troops and workers in range first, then buildings.

Whether something is in range is decided by the game itself, with each engine's own range (the
one the Rebalancer sets, if you use it), exactly as for a player's engine. They only ever aim at
enemies: players on another team than the outpost's owner, never its allies and never nobody's
buildings or animals. When nothing is left in range they walk on.

## Saves and maps

What you set for each outpost is kept in the map and in saves (through the Map Extensions
module). Played without this module, the map still works: the outpost keeps the number of
guards you set (at least one, as archers), and its waves grow at the game's own pace.
