--[[
  Outpost Control

  Outposts (the European and Arabian outposts of the map editor) send waves of attackers
  and keep a handful of archers around themselves. This module adds to that:

  1. Defenders. A second page in the outpost's panel (a button over the panel's title switches
     it) uses the same eight troop buttons and the size slider: the buttons pick which troops
     guard the outpost (several may be picked, they take turns), the slider how many (0 to 50).
     The game only has 8 defender slots, so an outpost with settings keeps its guards in a list
     of its own, and waits 9600 / amount ticks between guards (the game: 1200 for its 8). The
     game's own defender count field gets the amount (1 to 8), so the map still means about
     the same without the module.
  2. Growth. A third slider on the attacker page (the size and start delay sliders move up to
     make room): how much bigger each wave gets, 0 to 100 percent of the first wave per wave
     sent (0 = the game: every wave the same size). The game's own speed-up of the waves (100
     ticks less wait per wave, 4 less between units) is left as it is.
  3. Jobs. When a wave leaves, its troops are split by unit type into troops with a job of
     their own: filling the moat, hacking at walls and gates, burning or wrecking buildings,
     fighting the troops they meet, riding round the castle, or hunting the lord. Each troop
     is registered with the AI like the wave was, so the outpost's own attack logic keeps
     looking after it; this module only changes what it is told to do.

  The per-outpost settings and the jobs live in the save (and in the map) through the
  map-extensions module. Without this module the game ignores that data.
]]

local MODULE_NAME = "outpost-control"

-- Constants live in one table: a chunk may only have 200 locals.
local K = {}
K.SAVE_SECTION = "outpost-control"
K.SAVE_BUILDINGS = "buildings.bin"
K.SAVE_JOBS = "jobs.bin"
K.SAVE_GUARDS = "guards.bin"
K.SAVE_WAVES = "waves.bin"
K.SAVE_GROWTH = "growth.bin"      -- the size growth (buildings.bin keeps a 0 where 1.0.15 kept speed)

local templates = require("templates")

-- Jobs.
K.JOB_NONE, K.JOB_ENGAGE, K.JOB_BUILDINGS, K.JOB_MOAT, K.JOB_WALLS, K.JOB_LORD, K.JOB_PATROL = 0, 1, 2, 3, 4, 5, 6
K.JOB_SIEGE = 7
K.JOB_LAST = K.JOB_SIEGE
K.JOB_NAMES = { [0] = "as the game does", "fight troops", "attack buildings", "fill the moat",
  "attack walls and gates", "hunt the lord", "ride round the castle", "shoot on the way" }

-- Siege engines an outpost sends (catapults, and fire ballistas at an Arabian one; trebuchets
-- and mangonels if a map's outposts were made to send them): like the AI's raid engines they are
-- ordered at whatever is in their range on their way. Fire ballistas take troops first.
K.SIEGE = { [39] = "catapult", [40] = "catapult", [41] = "catapult", [77] = "ballista" }
-- Their projectile, whose range (in tiles, straight line) the game's range table holds.
K.SIEGE_PROJECTILE = { [39] = 2, [40] = 3, [41] = 4, [77] = 0x25 }

-- The AI's attack army: behaviour types and their troop slots (aiTribeIDs), lord-hunt's table.
K.BEHAVIOUR_MAIN, K.BEHAVIOUR_BACKUP = 20, 17
K.ARMY_SLOTS = { [20] = { 0xC0, 0xC7 }, [17] = { 0xBA, 0xBC } }
K.RANGED_TROOPS = { [22] = true, [23] = true, [70] = true, [72] = true, [74] = true, [76] = true }
-- AICState::addUnitToItsTribe(unit, behaviour) (lord-hunt's pattern).
K.AOB_ADD_TO_ITS_TRIBE = "56 57 8B 7C 24 0C 8B C7 69 C0 90 04 00 00 0F BF 90 ? ? ? ? 8B F2 69 F6 F4 39 00 00"

-- Each unit type an outpost sends: the first job, its default share in percent, the job of the
-- rest, and the setting that holds the share.
K.PLANS = {
  { kind = 71, name = "slaves", first = K.JOB_MOAT, rest = K.JOB_BUILDINGS, share = 50 },
  { kind = 24, name = "spearmen", first = K.JOB_MOAT, rest = K.JOB_WALLS, share = 50 },
  { kind = 26, name = "macemen", first = K.JOB_MOAT, rest = K.JOB_BUILDINGS, share = 30 },
  { kind = 27, name = "swordsmen", first = K.JOB_WALLS, rest = K.JOB_BUILDINGS, share = 60 },
  { kind = 75, name = "arab_swordsmen", first = K.JOB_WALLS, rest = K.JOB_BUILDINGS, share = 50 },
  { kind = 28, name = "knights", first = K.JOB_LORD, rest = K.JOB_PATROL, share = 40 },
  { kind = 22, name = "archers", first = K.JOB_MOAT, rest = K.JOB_ENGAGE, share = 30 },
  { kind = 70, name = "arab_archers", first = K.JOB_MOAT, rest = K.JOB_ENGAGE, share = 30 },
  { kind = 72, name = "slingers", first = K.JOB_PATROL, rest = K.JOB_ENGAGE, share = 30 },
  { kind = 74, name = "horse_archers", first = K.JOB_PATROL, rest = K.JOB_ENGAGE, share = 100 },
  { kind = 76, name = "fire_throwers", first = K.JOB_BUILDINGS, rest = K.JOB_ENGAGE, share = 60 },
}

K.DEFAULTS = {
  defenders = { enabled = false, walls = false, knights = false },
  waves = { exact = false },
  growth = { enabled = false },
  jobs = { enabled = false },
  siege = { enabled = false },
  join = { enabled = false },
  retarget = { enabled = false },
  diagnostics = { log = false },
}
for _, plan in ipairs(K.PLANS) do K.DEFAULTS.jobs[plan.name] = plan.share end

-- Defender troops per button, European outpost then Arabian outpost.
K.DEFENDER_TYPES = {
  22, 23, 24, 25, 26, 27, 28, 37,
  70, 72, 74, 75, 71, 73, 76, 23,
}
-- Their names: game texts (group, index), from the outpost's own list (group 0x40) where it has
-- the troop, otherwise from the unit buttons' help (group 8; the assassin has a singular name only).
K.DEFENDER_TEXTS = {
  { 0x40, 1 }, { 8, 248 }, { 0x40, 2 }, { 8, 246 }, { 0x40, 3 }, { 0x40, 4 }, { 0x40, 5 }, { 8, 254 },
  { 0x40, 10 }, { 0x40, 15 }, { 0x40, 13 }, { 0x40, 11 }, { 0x40, 12 }, { 8, 318 }, { 0x40, 14 },
  { 8, 248 },
}
-- The panel's own words come from the module's locale catalogs: English until the game's
-- language (textResourceModifier's name for it) is known.
K.LOCALE = "ucp/modules/outpost-control/locale/"
K.CATALOGS = { german = "de", french = "fr", russian = "ru", hungarian = "hu", turkish = "tr",
  chinese = "ch", spanish = "es", persian = "fa" }

-- The left column of the panel. The game has the size slider at y 510 and the start delay
-- slider at 568, with their names at the left and their ends written above them. With growth on
-- the two move up and the growth slider goes below them; the ends are left out. A slider's knob
-- reaches 5 px above the bar and 31 below its top, so three rows of 36 px just fit.
K.SLIDER_X, K.SLIDER_W, K.SLIDER_H = 130, 104, 26
K.GAME_SIZE_Y, K.GAME_DELAY_Y = 510, 568
K.SIZE_Y, K.DELAY_Y, K.GROWTH_Y = 494, 530, 566
K.LABEL_X, K.LABEL_DROP = 0x19, 7
K.TEXT_SIZE, K.TEXT_DELAY = 0x12, 0x15     -- the game's own "Size" and "Start Delay"
K.NUMBER_X = 242                  -- each slider's value, right of it (the troop buttons start at 280)
K.TICKS_PER_SECOND = 40           -- at normal game speed
K.SIZE_FIELD, K.DELAY_FIELD = 0x30E, 0x310
K.WAVE_FIELD = 0x30A              -- the size the forming wave troop leaves at
K.VANILLA_TOP = 5                 -- the game's size slider: multiplier 1 to 6
K.GROWTH_CAP = 999                -- the biggest a grown wave gets
-- The outpost troop kinds: 16 x 0x34 (8 European, 8 Arabian): +8 base size, +0xC size range.
K.KIND_STRIDE, K.KIND_BASE, K.KIND_RANGE, K.KINDS = 0x34, 8, 0xC, 16
-- UpdateOutpostBuilding: a new wave troop's size, (rand % range + base) * (size + 1).
K.AOB_WAVE_SIZE = "66 8B 81 ? ? ? ? 66 05 01 00 66 C7 86 ? ? ? ? ? 00 66 03 97 ? ? ? ? 66 0F AF D0 66 89 91"
K.WAVE_SIZE_AT, K.WAVE_SIZE_SIZE = 0x1F, 7
K.WAVE_SIZE_KINDS = { 0x14, { 0x66, 0x03, 0x97 } }
K.WAVE_START_AT, K.WAVE_START_SIZE = 4, 8  -- from the end of the guard slots: test ebp,ebp / jne
K.KNOB_W, K.KNOB_ABOVE, K.KNOB_H = 15, 5, 36

-- Guards in a troop of their own per outpost, for a stance: melee guards defensive, slaves
-- aggressive, knights aggressive and on patrol round the outpost (attacking enemy buildings they
-- come near), horse archers aggressive and on patrol round the outpost. Archers, crossbowmen,
-- slingers and fire throwers stay as the game has its archers (no troop).
K.STANCE_DEFENSIVE, K.STANCE_AGGRESSIVE = 1, 2
K.GUARD_GROUP = {
  [24] = "defensive", [25] = "defensive", [26] = "defensive", [27] = "defensive", [37] = "defensive",
  [73] = "defensive", [75] = "defensive",
  [71] = "aggressive", [74] = "patrol", [28] = "knights",
}
K.GUARD_STANCE = { defensive = 1, aggressive = 2, patrol = 2, knights = 2 }
K.GUARD_INDEX = { defensive = 1, aggressive = 2, patrol = 3, knights = 4 }
K.GUARD_PATROLS = { patrol = true, knights = true }
K.RIDER_REACH = 10                -- tiles: an enemy building this close draws a patrolling knight troop
K.KNIGHT = 28
-- Guards who man walls and towers near their outpost: every foot soldier; riders stay below.
K.WALL_GUARDS = { [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true,
  [37] = true, [70] = true, [71] = true, [72] = true, [73] = true, [75] = true, [76] = true }
K.WALL_RADIUS = 16                -- tiles from the outpost's middle
K.WALL_CROWD = 2                  -- guards closer than this to a spot (tiles) crowd it
K.WALL_TRIES = 24                 -- least crowded spots offered to the area test
-- Stone gatehouses and towers, whose tops guards stand on (walls are tiles, not buildings).
K.WALL_BUILDINGS = { [45] = true, [46] = true, [60] = true, [61] = true, [74] = true, [75] = true,
  [76] = true, [77] = true, [78] = true }
K.NOT_WALKABLE_FLAG = 0x2         -- with the wall flag: a wall tile nobody stands on
K.FLAGS_TO_WALL_OWNER = 0x2C6E50 - 0x165160
-- UpdateOutpostBuilding, before the guard site: where it sends a new guard (the area map, the
-- path finder and its area test, setDestinationForUnit).
K.GUARD_AREA = { -0x99, { 0x0F, 0xBF, 0x04, 0x55 } }
K.GUARD_PATHS = { -0x67, { 0xB9 } }
K.GUARD_NAVIGATE = -0x62
K.GUARD_DESTINATION = -0x05
K.GUARD_PATROL_NEAR, K.GUARD_PATROL_FAR = 7, 15   -- tiles from the outpost's middle
K.GUARD_PATROL_POINTS = 6         -- a troop route holds 9 points; the first is where it starts
K.GUARD_PATROL_TRIES = 12
K.WALL_FLAG = 0x100               -- tile flag: a wall stands here
-- The tile flags (lord-hunt's pattern) and, at a fixed distance from them, the building on each
-- tile and the map rows (both exes).
K.AOB_TILE_FLAGS = "F7 04 9D ? ? ? ? 00 01 00 00"
K.TILE_FLAGS_OPERAND = 0x03
K.FLAGS_TO_BUILDINGS = 0x2029B0 - 0x165160
K.FLAGS_TO_ROWS = 0x8A40F8 - 0x165160

K.MAX_DEFENDERS = 50
K.VANILLA_SLOTS = 8           -- the game's own defender slots
K.USUAL_DEFENDERS = 7         -- the game rolls 6 or 7 when the field is unset
K.MAX_GUARDS = K.MAX_DEFENDERS  -- the module's guard list, per outpost: unit id, unit uid
K.GUARD_PACE = 9600           -- ticks for a full refill (the game: 8 guards, 1200 each)
K.LONGEST_WAIT, K.SHORTEST_WAIT = 1200, 100
K.ENTRY_SIZE, K.ENTRY_SHIFT = 16, 4  -- per building: uid, troop bits, amount, growth, wave size
K.MAX_BUILDINGS = 2000         -- the building array, both exes
K.MAX_TRIBES = 1250            -- the troop array, both exes
K.EURO_ARCHER, K.ARAB_ARCHER = 22, 70
K.OUTPOST_EURO, K.OUTPOST_ARAB = 106, 107
K.KIND_RANGED, K.KIND_MELEE, K.KIND_SIEGE = 0xB6, 0xB8, 0xB9
K.STANCE_AGGRESSIVE = 2
K.ORDER_ATTACK_UNIT, K.ORDER_ATTACK_WALL_AT, K.ORDER_DIG_MOAT = 4, 7, 0x23
K.ORDER_ATTACK_BUILDING = 9
K.TEXT_BUTTON = 332           -- the outpost's own text button picture
-- The page button, over the panel's title (the title is drawn at 25, 463).
K.TOGGLE_X, K.TOGGLE_Y, K.TOGGLE_W, K.TOGGLE_H = 18, 456, 125, 30

K.PATROL_RADIUS = 25          -- tiles round the lord
K.PATROL_ARRIVED = 4
K.WAIT = { [K.JOB_MOAT] = 3, [K.JOB_WALLS] = 3, [K.JOB_LORD] = 2, [K.JOB_PATROL] = 10 }

---------------------------------------------------------------------------------------
-- What the game's code looks like where this module reads it (the same in both exes)
---------------------------------------------------------------------------------------

-- UpdateOutpostBuilding: is the defender count set (cmp byte [ecx+field],0 / jle roll).
K.AOB_DEFENDER_COUNT = "80 B9 ? ? ? ? 00 0F 8E ? ? ? ? 66 83 81 ? ? ? ? FF 0F B7 81 ? ? ? ? 66 85 C0 0F 8D"
K.DEFENDER_COUNT_SIZE = 13
K.DEFENDER_COUNT_FIELD = 0x2A7
-- UpdateOutpostBuilding: every 1200 ticks, before counting its defenders (mov word [timer],1200).
K.AOB_GUARD_COUNT = "8B 3D ? ? ? ? 8B C7 69 C0 2C 03 00 00 66 C7 81 ? ? ? ? B0 04 0F B7 90"
K.GUARD_COUNT_AT, K.GUARD_COUNT_SIZE = 0x0E, 9
K.TIMER_FIELD = 0x29A
-- UpdateOutpostBuilding: finding a free slot for the new defender (mov ebp,[current]).
K.AOB_GUARD_RECORD = "8B 2D ? ? ? ? 8B D5 69 D2 2C 03 00 00 33 C9 81 C2 ? ? ? ? EB"
K.GUARD_RECORD_SIZE = 6
K.GUARD_RECORDED = 0x90       -- mov ebp,[esp+0x10], after the slot loop
-- UpdateOutpostBuilding: the defender's type (archer, or Arab archer at an Arabian outpost).
K.AOB_DEFENDER_TYPE = "66 83 B9 ? ? ? ? 6B BA 16 00 00 00 75 05 BA 46 00 00 00"
K.DEFENDER_TYPE_SIZE = 20
-- UpdateOutpostBuilding, after a wave: add 100 to the wave counter, 4 to the unit pace.
K.AOB_GROWTH = "66 83 80 ? ? ? ? 64 66 83 80 ? ? ? ? 04 5D 5F 5E 5B 83 C4 1C C3"
K.GROWTH_SIZE = 16
K.WAVES_FIELD, K.PACE_FIELD = 0x316, 0x318
-- UpdateOutpostBuilding: aiRegisterTribeAndAssignTarget(tribe, uid) sends the wave.
K.AOB_LAUNCH = "8B 80 ? ? ? ? 50 56 B9 ? ? ? ? E8 ? ? ? ? A1 ? ? ? ? 69 C0 2C 03 00 00 66 C7 80 ? ? ? ? 00 00 66 83"
K.LAUNCH_AI = { 0x08, { 0xB9 } }
K.LAUNCH_CALL = 0x0D
K.LAUNCH_CURRENT = { 0x12, { 0xA1 } }
K.REGISTER_SET_TARGET = 0x89      -- aiRegisterTribeAndAssignTarget: call setTargetForTribe...
-- makeOutpostTribesAttack: every registered outpost troop -> decideOnTribeAttackLocation.
K.AOB_MAKE = "53 55 56 8B E9 57 8D ? ? ? ? 00 8D ? ? ? ? 00 BB E8 03 00 00 0F BF 06 85 C0 74 ? 8B C8 "
  .. "69 C9 ? ? 00 00 8B 91 ? ? ? ? 3B 17 75 ? 50 8B CD E8"
K.MAKE_STRIDE = { 0x20, { 0x69, 0xC9 } }
K.MAKE_UID = { 0x26, { 0x8B, 0x91 } }
K.MAKE_CALL = 0x33
-- decideOnTribeAttackLocation(tribe): the outpost troops' own order logic.
K.AOB_DECIDE = "83 EC 0C 57 8B 7C 24 14 6A 01 6A 00 57 89 4C 24 10 E8 ? ? ? ? 85 C0"
K.DECIDE_BUSY = 0x11
K.DECIDE_TARGET = { 0x41, { 0x0F, 0xBF, 0xAE } }
K.DECIDE_TRIBES = { 0x91, { 0xB9 } }
K.DECIDE_LEAD = 0xA9
K.DECIDE_UNIT_Y = { 0xC6, { 0x0F, 0xBF, 0x88 } }
K.DECIDE_OWNER = { 0xD9, { 0x8B, 0x86 } }
K.DECIDE_PATHS = { 0xE3, { 0xB9 } }
K.DECIDE_PATH = 0xE8
K.DECIDE_ROWS = { 0xFE, { 0x8B, 0x14, 0x8D } }
K.DECIDE_UNITS_THIS = { 0x10F, { 0xB9 } }
K.DECIDE_RELAY = 0x114
K.DECIDE_KIND = { 0x145, { 0x0F, 0xB7, 0x86 } }
K.DECIDE_BUILDING_UID = { 0x187, { 0x8B, 0x90 } }
K.DECIDE_CAMP = { 0x229, { 0x8B, 0x98 } }
K.DECIDE_REACH = 0x24C
K.DECIDE_COMMAND = 0x263

-- The outpost panel: its text, the troop buttons, their click, the two sliders.
K.AOB_PANEL = "A1 ? ? ? ? 69 C0 2C 03 00 00 33 D2 66 83 B8 ? ? ? ? 6B 75 05 BA 09 00 00 00 A1 ?"
K.PANEL_SELECTED = { 0x00, { 0xA1 } }
K.PANEL_TYPE = { 0x0D, { 0x66, 0x83, 0xB8 } }
K.PANEL_MENU_Y = { 0x1C, { 0xA1 } }
K.PANEL_MENU_X = { 0x21, { 0x8B, 0x0D } }
K.PANEL_TEXT_MANAGER = { 0x3E, { 0xB9 } }
K.PANEL_RENDER_TEXT = 0x4E
K.AOB_BUTTON_RENDER = "56 57 8B 7C 24 0C 8B CF BA 01 00 00 00 D3 E2 8B 0D ? ? ? ? 8B C1 69 C0 2C 03 00 00 "
  .. "33 F6 66 83 B8 ? ? ? ? 6B 75"
K.BUTTON_RENDER_SIZE = 8
K.RENDER_SELECTED = { 0x0F, { 0x8B, 0x0D } }
K.RENDER_HOVER = { 0x2E, { 0x83, 0x3D } }
K.RENDER_MASK = { 0x3B, { 0x0F, 0xBF, 0x80 } }
K.RENDER_BUTTON = 0x5A
K.RENDER_W = { 0xA6, { 0xA1 } }
K.RENDER_Y = { 0xAB, { 0x8B, 0x0D } }
K.RENDER_X = { 0xBC, { 0x03, 0x05 } }
K.RENDER_TEXT_MANAGER = { 0xCA, { 0xB9 } }
K.RENDER_SHADOW_TEXT = 0xDA
K.AOB_BUTTON_CLICK = "A1 ? ? ? ? 8B 4C 24 04 69 C0 2C 03 00 00 BA 01 00 00 00 D3 E2 8D 80 ? ? ? ? 66 31 10"
K.BUTTON_CLICK_SIZE = 5
K.AOB_SLIDER = "8B 4C 24 08 A1 ? ? ? ? 83 C1 FF 83 F9 05 0F 87 ? ? ? ? FF 24 8D ? ? ? ? 8B 4C 24 0C "
  .. "69 C0 2C 03 00 00 8B 54 24 10 C7 01 00 00 00 00 8B 4C 24 14 C7 02 "
K.AOB_SIZE = K.AOB_SLIDER .. "05 00 00 00"
K.AOB_DELAY = K.AOB_SLIDER .. "C0 5D 00 00"
K.PANEL_GET_TEXT = 0x43
K.SLIDER_FIELD = { 0x3A, { 0x0F, 0xBF, 0x80 } }   -- msg 1: movsx eax, word [eax + field]
K.SLIDER_SIZE = 9
K.SLIDER_SELECTED = { 0x04, { 0xA1 } }
-- The game's button picture renderer: the picture index and the draw buffer choice.
K.BUTTON_IMAGE = { 0x00, { 0x8B, 0x0D } }
K.BUTTON_DRAW_CHOICE = { 0x1A, { 0xC7, 0x05 } }

-- handleMenuElementsCallbacks: the mouse (+0x10 x, +0x14 y, +0x34 left click this frame).
K.AOB_MENU_ITEM = "8B 56 10 8B 46 4C 8B 4E 0C 52 8B 50 08 03 56 08 8B 40 04 03 46 04 51 52 50 B9 ? ? ? ? E8"
K.MENU_ITEM_MOUSE = { 0x19, { 0xB9 } }
K.MOUSE_X, K.MOUSE_Y, K.LEFT_CLICK, K.LEFT_HELD = 0x10, 0x14, 0x34, 0x40
-- ToolbarButtonPressed (found 0x1B in, improved-tunnelers jumps over its start): the click sound.
K.AOB_TOOLBAR = "A1 ? ? ? ? 8B C8 69 C9 F4 39 00 00 39 99 ? ? ? ? 74 18 39 1D ?"
K.TOOLBAR_PATTERN_OFFSET = 0x1B
K.TOOLBAR_SOUND_ID = { 0x227, { 0x68 } }
K.TOOLBAR_SOUNDS = { 0x22C, { 0xB9 } }
K.TOOLBAR_PLAY_SOUND = 0x23D

-- Troop functions (the same patterns lord-hunt uses).
K.AOB_ADD_TO_TRIBE = "53 8B 5C 24 08 56 57 8B 7C 24 14 8B C7 69 C0 ? ? 00 00 66 83"
K.AOB_REMOVE_FROM_TRIBE = "53 55 56 8B 74 24 10 8B D9 8B CE 69 C9 90 04 00 00 66 83 B9 ? ? ? ? 00 57 8B 7C 24 18"
K.AOB_CREATE_TRIBE = "53 55 8B 6C 24 0C 56 57 BF ? ? 00 00 2B FD 33 DB 3B FB 7E"
K.AOB_INSTRUCTION = "83 EC 1C 8B 44 24 20 69 C0 ? ? 00 00 53 8B 5C 24 30 55 8D 2C 08 33 D2 56 0F BF 75 5C"
K.AOB_STANCE = "8B 44 24 04 66 8B 54 24 08 69 C0 ? ? 00 00 66 89 94 08 ? ? 00 00 C7 05"
-- giveTribeMoveInstruction(tribe, x, y, patrol, store as route, speed) and addRallyPoint(tribe,
-- x, y, step) (lord-hunt's and attack-move's ground): a patrol is a move order flagged 1 plus
-- route points; the troop walks them in a loop.
K.AOB_MOVE = "83 EC 34 33 C0 55 8B 6C 24 44 57 8B 7C 24 44 3B F8 89 4C 24 08 89 44 24 18"
K.AOB_ADD_POINT = "8B 44 24 04 8B D0 69 C0 ? ? 00 00 69 D2 ? ? 00 00 56 8B 74 24 14 57 66 8B 7C 24 10 03 D6"
-- The team table (lord-hunt's pattern): dword per player.
K.AOB_TEAMS = "8B 0C 85 ? ? ? ? 8B 44 24 30 3B 0C 85 ? ? ? ?"
K.TEAMS_OPERAND = 0x03
-- acquireShootTarget: where it reads the range table (mov eax,[eax*4+ranges]). The Rebalancer
-- puts a jump there to its own code, which reads the same table: then look where it leads.
K.AOB_ACQUIRE = "83 EC 40 53 56 57 8B 7C 24 50 69 FF 90 04 00 00 8B F1 0F BF 84 37 AA 06 00 00"
K.ACQUIRE_RANGE = 0x131
K.RANGE_READ = { 0x8B, 0x04, 0x85 }
K.RANGE_SEARCH = 0x100
-- updateUnits, where it calls each unit's update function from the table by unit type.
K.AOB_UPDATE_CALL = "0F BF 91 A2 06 00 00 8B 04 95 ? ? ? ? FF D0"
K.UPDATE_TABLE = { 0x07, { 0x8B, 0x04, 0x95 } }
K.UPDATE_CURRENT = { -0x19, { 0xA1 } }        -- mov eax,[current unit], before the patched part
-- The game tick counter (lord-hunt's pattern).
K.AOB_TICKS = "8B 87 50 0A 00 00 8B 8F 98 09 00 00 8B 15"
K.TICKS_OPERAND = 0x0E
K.OUTPOST_BEHAVIOUR = 0x32        -- every unit an outpost spawns
K.SIEGE_EVERY = 15                -- check each engine every 16 ticks (0.4 s at normal speed)
K.STATE_MOVING = 0x65
K.STATE_WALKING = 1               -- siege engines walk in state 1 as well as 0x65
K.STATE_CREEPING = 9              -- the AI siege code walking an engine forward in steps
K.UNIT_TYPES = 80
K.STATE_SHOOT = 8                 -- aim (then 2 load, 4 fire)
K.SHOOTING = { [8] = true, [2] = true, [4] = true }
K.SHOOT_BEFORE_STOP = 10          -- what the game's own idle code sets
K.SIEGE_TRIES = 3                 -- nearest buildings in range offered to acquireShootTarget
-- The game's "stop walking" (clears the unit's path), used by its attack orders.
K.AOB_HALT = "8B 44 24 04 69 C0 90 04 00 00 03 C1 33 C9 66 89 88 ? ? 00 00 66 89 88 ? ? 00 00 66 89 88 "
  .. "? ? 00 00 66 89 88 ? ? 00 00 C2 04 00"

-- MenuItem layout (0x50 bytes) and the outpost's static size slider item, which leads to the
-- building menu's item table and its constructor.
K.ITEM_SIZE, K.ITEM_TYPE, K.ITEM_ACTION, K.ITEM_PARAM, K.ITEM_IMAGE = 0x50, 0x00, 0x14, 0x18, 0x20
K.ITEM_MIN, K.ITEM_MAX, K.ITEM_VALUE = 0x3C, 0x40, 0x44
K.ITEM_Y, K.ITEM_RENDER, K.ITEM_HIDDEN = 0x08, 0x1C, 0x36
K.TYPE_GROUP, K.TYPE_LAST = 0x01000000, 0x66
K.SIZE_ITEM_FROM_GROUP = 9    -- group header, eight buttons, then the size slider

---------------------------------------------------------------------------------------
-- Layouts (read from the code above where they differ between the exes)
---------------------------------------------------------------------------------------

local U = { STRIDE = 0x490, STATE = 0x8C, TYPE = 0x8E, OWNER = 0x96, UID = 0x98, X = 0xC4, Y = 0xC6,
  TILE = 0xD4, DYING = 0x2A0, CLIMB = 0x360, ACTION = 0x2C0, TRIBE = 0x2D8, TRIBE_UID = 0x2E4, TARGET_BUILDING = 0x336,
  SHOOT_UNIT = 0x344, TARGETING = 0x39C, SHOOT_BEFORE_STOP = 0x3D8, TARGET_UNIT = 0x39E, TARGET_UID = 0x3A0, BEHAVIOUR = 0x42A,
  STATE_OFFSET = 0x614 }
local T = { OWNER = 0x2C, UID = 0x34, STATE = 0x40, SIZE = 0x5C }
local B = { STRIDE = 0x32C, STATE = 0xD0, TYPE = 0xD2, OWNER = 0xD6, UID = 0xD8, X = 0xEE, Y = 0xF0,
  SIZE = 0xF8, TRIBE_UID = 0x304, MASK = 0x300 }
local P = { STRIDE = 0x39F4, CAMP = 0x1D8, LORD = 0x21F8, LORD_UID = 0x21FC, AI_TYPE = 0x2300,
  TRIBE_IDS = 0x310C, TRIBE_UIDS = 0x329C }
K.LORD_TYPE = 55
K.MAP_SIZE = 400

---------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------

local rd32, rd16, rd8 = core.readInteger, core.readSmallInteger, core.readByte
local wr32, wr16, wr8 = core.writeInteger, core.writeSmallInteger, core.writeByte

local function scan(pattern, purpose)
  local ok, address = pcall(core.AOBScan, pattern)
  if not ok or address == nil then
    error(MODULE_NAME .. ": could not find " .. purpose)
  end
  return address
end

local function expectBytes(address, bytes, purpose)
  for index, byte in ipairs(bytes) do
    if (rd8(address + index - 1) & 0xFF) ~= byte then
      error(string.format("%s: %s at 0x%X is not the code this module knows", MODULE_NAME, purpose, address))
    end
  end
end

local function readOperand(base, site, purpose)
  expectBytes(base + site[1], site[2], purpose)
  return rd32(base + site[1] + #site[2])
end

local function readCallTarget(base, offset, purpose)
  expectBytes(base + offset, { 0xE8 }, purpose)
  return base + offset + 5 + rd32(base + offset + 1)
end

local function readJumpTarget(at, purpose)
  expectBytes(at, { 0x0F }, purpose)
  return at + 6 + rd32(at + 2)
end

local function same(a, b, purpose)
  if a ~= b then
    error(string.format("%s: %s is not laid out as the module expects (0x%X, 0x%X)", MODULE_NAME, purpose, a, b))
  end
end

local function setting(config, group, name)
  local section = config[group]
  if type(section) == "table" and section[name] ~= nil then
    return section[name]
  end
  return K.DEFAULTS[group][name]
end

local function percent(value)
  value = math.tointeger(math.floor(tonumber(value) or 0)) or 0
  if value < 0 then return 0 end
  if value > 100 then return 100 end
  return value
end

local function strip(script)
  local lines = {}
  for line in script:gmatch("[^\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" then lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n") .. "\n"
end

-- Only the constants a script names go to the assembler (its buffer is small).
local function assemble(script, values)
  script = strip(script)
  local used = {}
  for name, value in pairs(values) do
    if script:find(name, 1, true) then used[name] = value end
  end
  return core.allocateAssembly(script, used)
end

local function jumpTo(site, target, size)
  local bytes = { 0xE9, core.itob(core.getRelativeAddress(site, target, -5)) }
  for _ = 6, size do bytes[#bytes + 1] = 0x90 end
  core.writeCode(site, bytes)
end

local function callTo(site, target)
  core.writeCode(site, { 0xE8, core.itob(core.getRelativeAddress(site, target, -5)) })
end

local function cString(text)
  local address = core.allocate(#text + 1, true)
  core.writeString(address, text)
  core.writeByte(address + #text, 0)
  return address
end

---------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------

local G = {}             -- addresses
local F = {}             -- the game's functions, exposed to lua
local O = {}             -- options
local orders = {}        -- per troop id: what this module last told it
local guardTroops = {}   -- per outpost and stance group: the guards' troop (id, uid)
local wallSpots = {}     -- per guard sent onto a wall: { uid, x, y }
local guardInfo = {}     -- per guard troop id: { uid, outpost, group, attack = { id, uid } }
local broken = false

local function diag(fmt, ...)
  if O.log then
    log(INFO, MODULE_NAME .. ": " .. string.format(fmt, ...))
  end
end

local function unit(id) return G.units + id * U.STRIDE end
local function tribe(id) return G.tribes + id * G.tribeStride end
local function building(id) return G.buildings + id * B.STRIDE end
local function player(p) return G.players + p * P.STRIDE end

local function tileAt(x, y)
  if x < 0 or y < 0 or x >= K.MAP_SIZE or y >= K.MAP_SIZE then return nil end
  return rd32(G.rows + y * 12) + x
end

local function team(p) return rd32(G.teams + p * 4) end

local function distance(ax, ay, bx, by)
  local dx, dy = math.abs(ax - bx), math.abs(ay - by)
  return dx > dy and dx or dy
end

local function setJob(id, job)
  if id <= 0 or id >= K.MAX_TRIBES then return end
  wr8(G.jobs + id, job)
  wr32(G.jobUids + id * 4, job ~= 0 and rd32(tribe(id) + T.UID) or 0)
  orders[id] = nil
end

local function aliveLord(p)
  if p < 1 or p > 8 then return nil end
  local id = rd32(player(p) + P.LORD)
  if id <= 0 then return nil end
  local u = unit(id)
  if rd16(u + U.STATE) ~= 2 or rd16(u + U.TYPE) ~= K.LORD_TYPE then return nil end
  if rd32(u + U.UID) ~= rd32(player(p) + P.LORD_UID) then return nil end
  return { id = id, uid = rd32(u + U.UID), x = rd16(u + U.X), y = rd16(u + U.Y), tile = rd32(u + U.TILE) }
end

---------------------------------------------------------------------------------------
-- Jobs: splitting a wave when it leaves
---------------------------------------------------------------------------------------

local function newTribe(owner, units, from, kind)
  local id = F.createTribe(G.tribesThis, owner)
  if id == nil or id <= 0 or id >= K.MAX_TRIBES then return nil end
  for _, u in ipairs(units) do
    F.removeFromTribe(G.tribesThis, u, from)
    F.addToTribe(G.tribesThis, u, id)
  end
  F.setStance(G.tribesThis, id, K.STANCE_AGGRESSIVE)
  wr16(tribe(id) + G.tribeKind, kind)
  return id
end

-- The option to hand a wave to its AI owner's attack army: every unit but the siege engines goes
-- into the attack troop the game's own reinforcement code (spawnUnitsForAITribe) would give it -
-- archers, crossbowmen, slingers, horse archers and fire throwers the backup troops, the rest the
-- main army - with the AI's own addUnitToItsTribe, which takes the smallest such troop. A unit
-- whose troop the AI does not have stays with the wave.
local function aiHasTroop(owner, behaviour)
  local slots = K.ARMY_SLOTS[behaviour]
  local base = player(owner)
  for slot = slots[1], slots[2] do
    local id = rd16(base + P.TRIBE_IDS + slot * 2)
    if id > 0 and id < K.MAX_TRIBES and rd32(tribe(id) + T.UID) == rd32(base + P.TRIBE_UIDS + slot * 4)
        and rd16(tribe(id) + T.STATE) == 2 then
      return true
    end
  end
  return false
end

local function joinArmy(t, owner)
  if rd32(player(owner) + P.AI_TYPE) == 0 then return end
  local joined, kept = 0, 0
  for id = 1, rd32(G.unitsThis) - 1 do
    local u = unit(id)
    if rd16(u + U.TRIBE) == t and rd16(u + U.STATE) == 2 and rd16(u + U.OWNER) == owner
        and K.SIEGE[rd16(u + U.TYPE)] == nil then
      local behaviour = K.RANGED_TROOPS[rd16(u + U.TYPE)] and K.BEHAVIOUR_BACKUP or K.BEHAVIOUR_MAIN
      if aiHasTroop(owner, behaviour) then
        F.removeFromTribe(G.tribesThis, id, t)
        F.addToItsTribe(G.aiState, id, behaviour)
        joined = joined + 1
      else
        kept = kept + 1
      end
    end
  end
  diag("player %d wave (troop %d): %d units to the attack army, %d stay", owner, t, joined, kept)
end

local function onLaunch()
  local t, ai = rd32(G.launchTribe), rd32(G.launchThis)
  if t <= 0 or t >= K.MAX_TRIBES then return end
  local tb = tribe(t)
  if rd16(tb + T.STATE) ~= 2 then return end
  setJob(t, K.JOB_NONE)
  local owner = rd32(tb + T.OWNER)

  if O.join then joinArmy(t, owner) end
  if rd16(tb + T.STATE) ~= 2 then return end

  local byKind, kinds = {}, {}
  local count = rd32(G.unitsThis)
  for index = 1, count - 1 do
    local u = unit(index)
    if rd16(u + U.TRIBE) == t and rd16(u + U.STATE) == 2 and rd16(u + U.OWNER) == owner then
      local kind = rd16(u + U.TYPE)
      if byKind[kind] == nil then
        byKind[kind] = {}
        kinds[#kinds + 1] = kind
      end
      table.insert(byKind[kind], index)
    end
  end
  table.sort(kinds)

  local groups = {}
  local function put(job, id)
    groups[job] = groups[job] or {}
    table.insert(groups[job], id)
  end
  for _, kind in ipairs(kinds) do
    local list = byKind[kind]
    local plan = O.jobs and O.plans[kind] or nil
    if O.siege and K.SIEGE[kind] ~= nil then
      for _, id in ipairs(list) do put(K.JOB_SIEGE, id) end
    elseif plan == nil then
      for _, id in ipairs(list) do put(K.JOB_NONE, id) end
    else
      local first = (#list * plan.share + 50) // 100
      for index, id in ipairs(list) do put(index <= first and plan.first or plan.rest, id) end
    end
  end

  -- The wave's own troop keeps whatever the game handles itself (siege engines), else its
  -- largest group.
  local keeper = groups[K.JOB_NONE] and K.JOB_NONE or nil
  for job = K.JOB_ENGAGE, K.JOB_LAST do
    if keeper == nil and groups[job] then keeper = job end
    if groups[job] and keeper ~= K.JOB_NONE and #groups[job] > #groups[keeper] then keeper = job end
  end
  if keeper == nil then return end

  local kind = rd16(tb + G.tribeKind)
  local made = {}
  for job = K.JOB_ENGAGE, K.JOB_LAST do
    if groups[job] and job ~= keeper then
      local id = newTribe(owner, groups[job], t, kind)
      if id ~= nil then
        F.register(ai, id, rd32(tribe(id) + T.UID))
        setJob(id, job)
        made[#made + 1] = string.format("%d %s (troop %d)", #groups[job], K.JOB_NAMES[job], id)
      end
    end
  end
  setJob(t, keeper)
  diag("player %d wave (troop %d): %d %s%s", owner, t, #groups[keeper], K.JOB_NAMES[keeper],
    #made > 0 and (", " .. table.concat(made, ", ")) or "")
end

---------------------------------------------------------------------------------------
-- Jobs: orders, each time the game looks at an outpost troop
---------------------------------------------------------------------------------------

-- The game's own order logic. Without a kind the troop keeps the wave's, so archers walk up
-- and shoot, melee troops attack a building and siege engines move up as the game has them.
local function gameChoice(ai, t, kind)
  if kind ~= nil then wr16(tribe(t) + G.tribeKind, kind) end
  F.decide(ai, t)
end

-- The game's own path to the castle: where it is blocked, and whether that is moat.
local function breach(owner, target, x, y)
  wr32(G.scratch, 0)
  wr32(G.scratch + 4, 0)
  wr32(G.scratch + 8, 0)
  if (F.path(G.paths, owner, target, x, y, G.scratch, G.scratch + 4, G.scratch + 8) & 0xFF) == 0 then
    return nil
  end
  return (rd8(G.scratch) & 0xFF) ~= 0, rd32(G.scratch + 4), rd32(G.scratch + 8)
end

local function patrolPoint(ai, t, cx, cy, step)
  for try = 0, 7 do
    local angle = ((step + try) % 8) * math.pi / 4
    local x = math.floor(cx + K.PATROL_RADIUS * math.cos(angle) + 0.5)
    local y = math.floor(cy + K.PATROL_RADIUS * math.sin(angle) + 0.5)
    x = math.max(1, math.min(K.MAP_SIZE - 2, x))
    y = math.max(1, math.min(K.MAP_SIZE - 2, y))
    local tile = tileAt(x, y)
    if tile ~= nil and F.reach(ai, t, tile) ~= 0 then return x, y, step + try + 1 end
  end
  return nil
end

local function enemies(owner)
  local list = {}
  for p = 1, 8 do
    if p ~= owner and team(p) ~= team(owner) then list[p] = true end
  end
  return list
end

local function squared(ax, ay, bx, by) return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) end

-- Enemy buildings standing within reach (squared, straight line) of x, y, nearest first.
local function buildingsInReach(owner, x, y, reach)
  local foes = enemies(owner)
  local found = {}
  for id = 1, K.MAX_BUILDINGS - 1 do
    local b = building(id)
    if rd16(b + B.STATE) ~= 0 and foes[rd16(b + B.OWNER)] then
      local size = rd32(b + B.SIZE)
      local half = size > 0 and size // 2 or 0
      local d = squared(x, y, rd16(b + B.X) + half, rd16(b + B.Y) + half)
      if d <= reach then found[#found + 1] = { id = id, d = d } end
    end
  end
  table.sort(found, function(p, q) return p.d < q.d or (p.d == q.d and p.id < q.id) end)
  return found
end

-- What a player's idle siege engine does with a target (UpdateCatapult, state 0): the game's
-- acquireShootTarget decides whether it can be shot from here - the game's own range, as the
-- Rebalancer set it - and aims; then the engine stops and goes into its shooting state. The AI's
-- own idle code never does this for an engine outside an AI siege, so outpost engines walked
-- past everything.
local function startShooting(id, u)
  F.halt(G.unitsThis, id)
  wr16(u + U.SHOOT_BEFORE_STOP, K.SHOOT_BEFORE_STOP)
  wr16(u + U.ACTION, K.STATE_SHOOT)
end

local function tryBuilding(id, u, b)
  local targeting, target, uid = rd16(u + U.TARGETING), rd16(u + U.TARGET_BUILDING), rd32(u + U.TARGET_UID)
  wr16(u + U.TARGETING, K.ORDER_ATTACK_BUILDING)
  wr16(u + U.TARGET_BUILDING, b)
  wr32(u + U.TARGET_UID, rd32(building(b) + B.UID))
  if F.acquire(G.unitsThis, id) ~= 0 then return true end
  wr16(u + U.TARGETING, targeting)
  wr16(u + U.TARGET_BUILDING, target)
  wr32(u + U.TARGET_UID, uid)
  return false
end

-- The game's own search for an enemy unit in range (acquireShootTarget with no target), which
-- fire ballistas use when idle.
local function tryUnits(id, u, foes)
  local targeting = rd16(u + U.TARGETING)
  wr16(u + U.TARGETING, 0)
  if F.acquire(G.unitsThis, id) ~= 0 then
    local v = rd16(u + U.SHOOT_UNIT)
    if v > 0 and foes[rd16(unit(v) + U.OWNER)] then return v end
  end
  wr16(u + U.TARGETING, targeting)
  return nil
end

-- A new guard of an outpost with settings (asm, when it is put in the outpost's list): melee
-- guards go into the outpost's defensive troop, knights into its aggressive one, horse archers
-- into its patrol troop, which is sent round the outpost again with every new rider. A troop
-- the AI has not registered never gets AI orders, so they stay at their outpost.
-- A patrol point is free when no building or wall stands on it and the troop can walk there.
local function freeSpot(t, x, y)
  local tile = tileAt(x, y)
  if tile == nil then return false end
  if rd32(G.tileFlags + tile * 4) & K.WALL_FLAG ~= 0 then return false end
  if rd16(G.buildingLayer + tile * 2) ~= 0 then return false end
  return F.reach(G.aiState, t, tile) ~= 0
end

-- The patrol: GUARD_PATROL_POINTS spots round the outpost, one in each sixth of the circle at a
-- random angle and distance in it. A blocked spot moves - nearer and further, then round the
-- circle - until a free one is found. The random numbers come from the game state (outpost,
-- troop, tick), so every player of a multiplayer game gets the same patrol.
local function patrolRound(t, bid)
  local b = building(bid)
  local half = rd32(b + B.SIZE) // 2
  local cx, cy = rd16(b + B.X) + half, rd16(b + B.Y) + half
  local seed = (bid * 7919 + t * 104729 + rd32(G.ticks)) & 0x7FFFFFFF
  local function random(n)
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    return (seed >> 8) % n
  end
  local sector = 2 * math.pi / K.GUARD_PATROL_POINTS
  local span = K.GUARD_PATROL_FAR - K.GUARD_PATROL_NEAR + 1
  local points = {}
  for index = 0, K.GUARD_PATROL_POINTS - 1 do
    local angle = (index + random(100) / 100) * sector
    local radius = K.GUARD_PATROL_NEAR + random(span)
    for try = 0, K.GUARD_PATROL_TRIES - 1 do
      local r = K.GUARD_PATROL_NEAR + (radius - K.GUARD_PATROL_NEAR + (try % 3) * 3) % span
      local turn = try // 3
      local a = angle + (turn + 1) // 2 * sector / 4 * (turn % 2 == 0 and 1 or -1)
      local x = math.max(1, math.min(K.MAP_SIZE - 2, math.floor(cx + r * math.cos(a) + 0.5)))
      local y = math.max(1, math.min(K.MAP_SIZE - 2, math.floor(cy + r * math.sin(a) + 0.5)))
      if freeSpot(t, x, y) then
        points[#points + 1] = { x, y }
        break
      end
    end
  end
  if #points == 0 then return end
  F.move(G.tribesThis, t, points[1][1], points[1][2], 1, 1, 0)
  for index = 2, #points do F.addPoint(G.tribesThis, t, points[index][1], points[index][2], index) end
end

-- A new foot guard goes up onto the owner's walls, stone towers or stone gatehouses within
-- WALL_RADIUS of the outpost: the free spot with the fewest guards round it (nearest the outpost
-- on a tie), which also fills the places of guards who fell. A spot counts only when the guard
-- can walk there (the game's own area test, as for the outpost's own spot). With none, the guard
-- keeps the spot the game gave it.
local function manWalls(id, bid)
  local u = unit(id)
  if not K.WALL_GUARDS[rd16(u + U.TYPE)] then return end
  local owner = rd16(u + U.OWNER)
  local b = building(bid)
  local half = rd32(b + B.SIZE) // 2
  local cx, cy = rd16(b + B.X) + half, rd16(b + B.Y) + half
  local r = K.WALL_RADIUS

  -- where the owner's people stand or are going, near the outpost
  local taken = {}
  local function mark(x, y) local k = y * K.MAP_SIZE + x taken[k] = (taken[k] or 0) + 1 end
  for other = 1, rd32(G.unitsThis) - 1 do
    if other ~= id then
      local o = unit(other)
      if rd16(o + U.STATE) == 2 and rd16(o + U.OWNER) == owner then
        local spot = wallSpots[other]
        if spot ~= nil and spot.uid == rd32(o + U.UID) then
          mark(spot.x, spot.y)
        else
          wallSpots[other] = nil
          local ox, oy = rd16(o + U.X), rd16(o + U.Y)
          if math.abs(ox - cx) <= r + K.WALL_CROWD and math.abs(oy - cy) <= r + K.WALL_CROWD then mark(ox, oy) end
        end
      end
    end
  end

  local spots = {}
  for y = math.max(1, cy - r), math.min(K.MAP_SIZE - 2, cy + r) do
    for x = math.max(1, cx - r), math.min(K.MAP_SIZE - 2, cx + r) do
      local tile = tileAt(x, y)
      if tile ~= nil and (taken[y * K.MAP_SIZE + x] or 0) == 0 then
        local flags = rd32(G.tileFlags + tile * 4)
        local ok = false
        if flags & K.WALL_FLAG ~= 0 then
          ok = flags & K.NOT_WALKABLE_FLAG == 0 and (rd8(G.wallOwner + tile) & 7) + 1 == owner
        else
          local on = rd16(G.buildingLayer + tile * 2)
          if on > 0 then
            local bb = building(on)
            ok = K.WALL_BUILDINGS[rd16(bb + B.TYPE)] == true and rd16(bb + B.OWNER) == owner
          end
        end
        if ok then
          local crowd = 0
          for dy = -K.WALL_CROWD, K.WALL_CROWD do
            for dx = -K.WALL_CROWD, K.WALL_CROWD do
              crowd = crowd + (taken[(y + dy) * K.MAP_SIZE + x + dx] or 0)
            end
          end
          spots[#spots + 1] = { x = x, y = y, tile = tile, crowd = crowd, d = distance(x, y, cx, cy) }
        end
      end
    end
  end
  if #spots == 0 then return end
  table.sort(spots, function(p, q)
    if p.crowd ~= q.crowd then return p.crowd < q.crowd end
    if p.d ~= q.d then return p.d < q.d end
    return p.tile < q.tile
  end)

  local from = rd16(G.area + rd32(u + U.TILE) * 2) & 0xFFFF
  local climb = rd16(u + U.CLIMB)
  for index = 1, math.min(#spots, K.WALL_TRIES) do
    local spot = spots[index]
    local to = rd16(G.area + spot.tile * 2) & 0xFFFF
    if to ~= 0 and (to == from or F.navigate(G.pathFinder, owner, from, to, climb) ~= 0) then
      F.setDestination(G.unitsThis, id, spot.x, spot.y, 0)
      wallSpots[id] = { uid = rd32(u + U.UID), x = spot.x, y = spot.y }
      diag("outpost %d: guard %d to the wall at %d,%d", bid, id, spot.x, spot.y)
      return
    end
  end
end

local function onGuard()
  local id, bid = rd32(G.guardUnit), rd32(G.current)
  if O.walls then manWalls(id, bid) end
  local u = unit(id)
  local group = K.GUARD_GROUP[rd16(u + U.TYPE)]
  if group == nil or rd16(u + U.TRIBE) > 0 then return end
  local owner = rd16(u + U.OWNER)
  local key = bid * 8 + K.GUARD_INDEX[group]
  local g = guardTroops[key]
  local buildingUid = rd32(building(bid) + B.UID)
  if g == nil or g.building ~= buildingUid or rd16(tribe(g.id) + T.STATE) ~= 2
      or rd32(tribe(g.id) + T.UID) ~= g.uid then
    local t = F.createTribe(G.tribesThis, owner)
    if t == nil or t <= 0 or t >= K.MAX_TRIBES then return end
    F.setStance(G.tribesThis, t, K.GUARD_STANCE[group])
    g = { id = t, uid = rd32(tribe(t) + T.UID), building = buildingUid }
    guardTroops[key] = g
    guardInfo[t] = { uid = g.uid, outpost = bid, group = group }
  end
  F.addToTribe(G.tribesThis, id, g.id)
  if K.GUARD_PATROLS[group] then patrolRound(g.id, bid) end
  diag("outpost %d: %s guard %d in troop %d", bid, group, id, g.id)
end

-- Shoot if anything is in range: fire ballistas take enemy troops first, then like catapults,
-- trebuchets and mangonels the nearest enemy building. True when the engine now shoots.
local function shootIfInRange(id)
  local u = unit(id)
  local kind = rd16(u + U.TYPE)
  if K.SIEGE[kind] == nil or rd16(u + U.STATE) ~= 2 then return false end
  local owner = rd16(u + U.OWNER)
  local foes = enemies(owner)
  if K.SIEGE[kind] == "ballista" then
    local v = tryUnits(id, u, foes)
    if v ~= nil then
      startShooting(id, u)
      diag("fire ballista %d shoots unit %d", id, v)
      return true
    end
  end
  local range = rd32(G.ranges + K.SIEGE_PROJECTILE[kind] * 4)
  local candidates = buildingsInReach(owner, rd16(u + U.X), rd16(u + U.Y), range * range)
  for index = 1, math.min(#candidates, K.SIEGE_TRIES) do
    local b = candidates[index].id
    if tryBuilding(id, u, b) then
      startShooting(id, u)
      diag("%s %d shoots building %d (range %d)", K.SIEGE[kind], id, b, range)
      return true
    end
  end
  return false
end

-- A patrolling knight guard, standing or riding (asm hands it over every 16 ticks): its troop
-- attacks the nearest enemy building within RIDER_REACH with the game's own attack order, and
-- rides its patrol again once that building is down. Enemy troops it meets it fights anyway
-- (aggressive stance).
local function onRider()
  local id = rd32(G.riderUnit)
  local u = unit(id)
  if rd16(u + U.TYPE) ~= K.KNIGHT or rd16(u + U.STATE) ~= 2 then return end
  local t = rd16(u + U.TRIBE)
  local info = guardInfo[t]
  if info == nil or info.group ~= "knights" or rd32(tribe(t) + T.UID) ~= info.uid
      or rd32(u + U.TRIBE_UID) ~= info.uid then
    return
  end
  local owner = rd16(u + U.OWNER)
  local foes = enemies(owner)
  if info.attack ~= nil then
    local b = building(info.attack.id)
    if rd16(b + B.STATE) ~= 0 and rd32(b + B.UID) == info.attack.uid and foes[rd16(b + B.OWNER)] then return end
    info.attack = nil
    patrolRound(t, info.outpost)
    diag("outpost %d: knights back on patrol", info.outpost)
    return
  end
  local near = buildingsInReach(owner, rd16(u + U.X), rd16(u + U.Y), K.RIDER_REACH * K.RIDER_REACH)
  if #near > 0 then
    local b = near[1].id
    local buid = rd32(building(b) + B.UID)
    F.instruction(G.tribesThis, t, K.ORDER_ATTACK_BUILDING, b, buid, 0)
    info.attack = { id = b, uid = buid }
    diag("outpost %d: patrolling knights attack building %d", info.outpost, b)
  end
end

-- An outpost siege engine standing, walking (state 1 or 0x65), or creeping forward in the AI's
-- siege steps (asm hands it over every 16 ticks).
local function onSiegeUnit()
  shootIfInRange(rd32(G.siegeUnit))
end

-- The game's order round for a siege troop: while any of its engines shoots or has something in
-- range (which it then starts shooting), the whole troop holds where it is - like the AI's raid
-- engines, they never walk past a target. Only with nothing in range anywhere does it get the
-- outpost logic's own siege order: walk up to a building of the castle it goes for.
local function siegeOrders(ai, t)
  local holding = false
  local size = rd16(tribe(t) + T.SIZE)
  for index = 0, size - 1 do
    local id = F.lead(G.tribesThis, t, index)
    if id ~= nil and id > 0 then
      if K.SHOOTING[rd16(unit(id) + U.ACTION)] or shootIfInRange(id) then holding = true end
    end
  end
  if not holding then gameChoice(ai, t, K.KIND_SIEGE) end
end

local function onDecide()
  local t, ai = rd32(G.decideTribe), rd32(G.decideThis)
  local tb = tribe(t)
  local job = rd8(G.jobs + t) & 0xFF
  if F.busy(ai, t, 0, 1) ~= 0 then return end
  local uid = rd32(tb + T.UID)
  local S = orders[t]
  if S == nil or S.uid ~= uid then
    S = { uid = uid, wait = 0, step = t % 8 }
    orders[t] = S
  end

  local owner = rd32(tb + T.OWNER)
  local target = rd16(tb + G.tribeTarget)
  local lead = F.lead(G.tribesThis, t, 0)
  if job == K.JOB_SIEGE and lead ~= nil and lead > 0 then
    siegeOrders(ai, t)
    return
  end
  if target < 1 or target > 8 or lead == nil or lead <= 0 then
    gameChoice(ai, t, nil)
    return
  end
  local lu = unit(lead)
  local ux, uy = rd16(lu + U.X), rd16(lu + U.Y)

  if job == K.JOB_PATROL and S.x ~= nil then
    if distance(ux, uy, S.x, S.y) > K.PATROL_ARRIVED and S.wait > 0 then
      S.wait = S.wait - 1
      return
    end
  elseif S.wait > 0 then
    S.wait = S.wait - 1
    return
  end

  if job == K.JOB_MOAT or job == K.JOB_WALLS then
    local moat, x, y = breach(owner, target, ux, uy)
    local tile = moat ~= nil and tileAt(x, y) or nil
    if moat and tile ~= nil then
      F.instruction(G.tribesThis, t, K.ORDER_DIG_MOAT, tile, 0, 0)
      S.wait = K.WAIT[job]
      return
    end
    if job == K.JOB_WALLS and moat == false then
      F.instruction(G.tribesThis, t, K.ORDER_ATTACK_WALL_AT, x, y, 1000)
      S.wait = K.WAIT[job]
      return
    end
    gameChoice(ai, t, nil)
    return
  end

  local lord = aliveLord(target)
  if job == K.JOB_LORD then
    if lord ~= nil and F.reach(ai, t, lord.tile) ~= 0 then
      F.instruction(G.tribesThis, t, K.ORDER_ATTACK_UNIT, lord.id, lord.uid, 0)
      S.wait = K.WAIT[job]
      return
    end
    job = K.JOB_PATROL            -- the lord is out of reach: ride round his castle instead
  end

  if job == K.JOB_PATROL then
    local cx, cy
    if lord ~= nil then
      cx, cy = lord.x, lord.y
    else
      cx, cy = rd32(player(target) + P.CAMP), rd32(player(target) + P.CAMP + 4)
    end
    local x, y, step = patrolPoint(ai, t, cx, cy, S.step)
    if x ~= nil then
      F.command(G.tribesThis, t, x, y, 1)
      S.x, S.y, S.step, S.wait = x, y, step, K.WAIT[K.JOB_PATROL]
      return
    end
    gameChoice(ai, t, nil)
    return
  end

  gameChoice(ai, t, nil)
end

---------------------------------------------------------------------------------------
-- The outpost panel: the two sliders in the live menu
---------------------------------------------------------------------------------------

-- The live menu's two outpost sliders (the ui module may have copied the item table).
local function liveSliders(each)
  if G.menu == nil then return end
  local item, limit = rd32(G.menu), 4000
  if item == 0 then return end
  while rd32(item + K.ITEM_TYPE) ~= K.TYPE_LAST and limit > 0 do
    local action = rd32(item + K.ITEM_ACTION)
    if action == G.sizeSlider or action == G.delaySlider then each(item, action) end
    item = item + K.ITEM_SIZE
    limit = limit - 1
  end
end

-- After the page switched: the size slider asks again what it shows, and the start delay
-- slider is hidden on the defender page.
local function refreshSliders()
  local mode = rd32(G.mode)
  liveSliders(function(item, action)
    if action == G.sizeSlider then
      F.sizeSlider(rd32(item + K.ITEM_PARAM), 1, item + K.ITEM_MIN, item + K.ITEM_MAX, item + K.ITEM_VALUE)
    else
      wr16(item + K.ITEM_HIDDEN, mode)
    end
  end)
end

-- With growth on, the size and start delay sliders move up to make room for the growth slider:
-- in the static item table (a menu built later) and in the live menu.
local function moveSliders()
  local function move(item, action)
    local y = action == G.sizeSlider and K.SIZE_Y or K.DELAY_Y
    if rd32(item + K.ITEM_Y) ~= y then core.writeCodeInteger(item + K.ITEM_Y, y) end
  end
  move(G.sizeItem, G.sizeSlider)
  move(G.delayItem, G.delaySlider)
  liveSliders(move)
end

---------------------------------------------------------------------------------------
-- The save: per outpost settings, their guards and the troops' jobs
---------------------------------------------------------------------------------------

local function wipe()
  core.setMemory(G.table, 0, K.MAX_BUILDINGS * K.ENTRY_SIZE)
  core.setMemory(G.slots, 0, K.MAX_BUILDINGS * K.MAX_GUARDS * 8)
  core.setMemory(G.jobs, 0, K.MAX_TRIBES)
  guardTroops = {}
  wallSpots = {}
  guardInfo = {}
  core.setMemory(G.jobUids, 0, K.MAX_TRIBES * 4)
  orders = {}
end

local function isOutpost(id)
  local kind = rd16(building(id) + B.TYPE)
  return kind == K.OUTPOST_EURO or kind == K.OUTPOST_ARAB
end

local function serialize(handle)
  local unitCount = math.min(rd32(G.unitsThis), G.unitCapacity)
  local entries = {}
  for id = 1, K.MAX_BUILDINGS - 1 do
    local entry = G.table + id * K.ENTRY_SIZE
    local uid = rd32(entry)
    if uid ~= 0 and uid == rd32(building(id) + B.UID) then
      entries[#entries + 1] = string.pack("<I2I4I2BB", id, uid, rd16(entry + 4) & 0xFFFF, rd8(entry + 6) & 0xFF,
        rd8(entry + 7) & 0xFF)
    end
  end
  handle:put(K.SAVE_BUILDINGS, table.concat(entries))
  local jobs = {}
  for id = 1, K.MAX_TRIBES - 1 do
    local job = rd8(G.jobs + id) & 0xFF
    local uid = rd32(G.jobUids + id * 4)
    if job ~= 0 and uid ~= 0 and uid == rd32(tribe(id) + T.UID) then
      jobs[#jobs + 1] = string.pack("<I2I4B", id, uid, job)
    end
  end
  handle:put(K.SAVE_JOBS, table.concat(jobs))
  local guards = {}
  for id = 1, K.MAX_BUILDINGS - 1 do
    local uid = rd32(G.table + id * K.ENTRY_SIZE)
    if uid ~= 0 and uid == rd32(building(id) + B.UID) then
      local slots = G.slots + id * K.MAX_GUARDS * 8
      for slot = 0, K.MAX_GUARDS - 1 do
        local u = rd16(slots + slot * 8) & 0xFFFF
        local unitUid = rd32(slots + slot * 8 + 4)
        if u > 0 and u < unitCount and unitUid ~= 0 and unitUid == rd32(unit(u) + U.UID) then
          guards[#guards + 1] = string.pack("<I2I2I4", id, u, unitUid)
        end
      end
    end
  end
  handle:put(K.SAVE_GUARDS, table.concat(guards))
  local waves = {}
  for id = 1, K.MAX_BUILDINGS - 1 do
    local entry = G.table + id * K.ENTRY_SIZE
    local uid = rd32(entry)
    local size = rd16(entry + 8) & 0xFFFF
    if uid ~= 0 and uid == rd32(building(id) + B.UID) and size ~= 0xFFFF then
      waves[#waves + 1] = string.pack("<I2I2", id, size)
    end
  end
  handle:put(K.SAVE_WAVES, table.concat(waves))
  local growth = {}
  for id = 1, K.MAX_BUILDINGS - 1 do
    local entry = G.table + id * K.ENTRY_SIZE
    local uid = rd32(entry)
    if uid ~= 0 and uid == rd32(building(id) + B.UID) and (rd8(entry + 7) & 0xFF) ~= 0 then
      growth[#growth + 1] = string.pack("<I2B", id, rd8(entry + 7) & 0xFF)
    end
  end
  handle:put(K.SAVE_GROWTH, table.concat(growth))
end

local function deserialize(handle)
  wipe()
  if handle:exists(K.SAVE_BUILDINGS) then
    local data = handle:get(K.SAVE_BUILDINGS)
    local size = string.packsize("<I2I4I2BB")
    for offset = 1, #data - size + 1, size do
      local id, _, mask, defenders, growth = string.unpack("<I2I4I2BB", data, offset)
      if id > 0 and id < K.MAX_BUILDINGS and isOutpost(id) then
        local entry = G.table + id * K.ENTRY_SIZE
        wr32(entry, rd32(building(id) + B.UID))
        wr16(entry + 8, 0xFFFF)
        wr16(entry + 4, mask)
        wr8(entry + 6, math.min(defenders, K.MAX_DEFENDERS))
        wr8(entry + 7, 0)          -- older saves held a speed growth: see growth.bin
      end
    end
  end
  if handle:exists(K.SAVE_GROWTH) then
    local data = handle:get(K.SAVE_GROWTH)
    local size = string.packsize("<I2B")
    for offset = 1, #data - size + 1, size do
      local id, growth = string.unpack("<I2B", data, offset)
      if id > 0 and id < K.MAX_BUILDINGS and rd32(G.table + id * K.ENTRY_SIZE) ~= 0 then
        wr8(G.table + id * K.ENTRY_SIZE + 7, math.min(growth, 100))
      end
    end
  end
  if handle:exists(K.SAVE_WAVES) then
    local data = handle:get(K.SAVE_WAVES)
    local size = string.packsize("<I2I2")
    for offset = 1, #data - size + 1, size do
      local id, wave = string.unpack("<I2I2", data, offset)
      if id > 0 and id < K.MAX_BUILDINGS and rd32(G.table + id * K.ENTRY_SIZE) ~= 0 then
        wr16(G.table + id * K.ENTRY_SIZE + 8, math.min(wave, G.waveMax or wave))
      end
    end
  end
  if handle:exists(K.SAVE_GUARDS) then
    local data = handle:get(K.SAVE_GUARDS)
    local size = string.packsize("<I2I2I4")
    local used = {}
    for offset = 1, #data - size + 1, size do
      local id, u, unitUid = string.unpack("<I2I2I4", data, offset)
      local slot = used[id] or 0
      if id > 0 and id < K.MAX_BUILDINGS and slot < K.MAX_GUARDS
          and u > 0 and u < G.unitCapacity and unitUid ~= 0
          and rd32(G.table + id * K.ENTRY_SIZE) ~= 0 then
        local at = G.slots + (id * K.MAX_GUARDS + slot) * 8
        wr16(at, u)
        wr32(at + 4, unitUid)
        used[id] = slot + 1
      end
    end
  end
  if handle:exists(K.SAVE_JOBS) then
    local data = handle:get(K.SAVE_JOBS)
    local size = string.packsize("<I2I4B")
    for offset = 1, #data - size + 1, size do
      local id, uid, job = string.unpack("<I2I4B", data, offset)
      if id > 0 and id < K.MAX_TRIBES and job <= K.JOB_LAST and uid == rd32(tribe(id) + T.UID) then
        wr8(G.jobs + id, job)
        wr32(G.jobUids + id * 4, uid)
      end
    end
  end
end

---------------------------------------------------------------------------------------
-- Enable
---------------------------------------------------------------------------------------

local function pad(callback, what)
  local address = core.allocateCode({ 0x90, 0x90, 0x90, 0x90, 0x90, 0xC3 })
  core.detourCode(function(registers)
    if not broken then
      local done, problem = pcall(callback)
      if not done then
        broken = true
        log(WARNING, MODULE_NAME .. ": " .. what .. " stopped after an error: " .. tostring(problem))
      end
    end
    return registers
  end, address, 5)
  return address
end

local function matches(address, bytes)
  for index, byte in ipairs(bytes) do
    if (rd8(address + index - 1) & 0xFF) ~= byte then return false end
  end
  return true
end

local function rangeTable(at)
  if matches(at, K.RANGE_READ) then return rd32(at + #K.RANGE_READ) end
  if (rd8(at) & 0xFF) == 0xE9 then
    local code = at + 5 + rd32(at + 1)
    for offset = 0, K.RANGE_SEARCH do
      if matches(code + offset, K.RANGE_READ) then return rd32(code + offset + #K.RANGE_READ) end
    end
  end
  error(string.format("%s: the range table at 0x%X is not read the way this module knows", MODULE_NAME, at))
end

local function resolve()
  local count = scan(K.AOB_DEFENDER_COUNT, "where an outpost checks its defender count")
  G.defenderCount = count
  G.defendersField = readOperand(count, { 0x00, { 0x80, 0xB9 } }, "the defender count")
  G.buildings = G.defendersField - K.DEFENDER_COUNT_FIELD
  G.roll = readJumpTarget(count + 7, "the defender roll")
  expectBytes(count + 0x1C, { 0x66, 0x85, 0xC0 }, "the defender timer")
  G.skip = readJumpTarget(count + 0x1F, "the end of the defender part")

  local guards = scan(K.AOB_GUARD_COUNT, "where an outpost counts its defenders")
  G.guardCount = guards + K.GUARD_COUNT_AT
  same(readOperand(guards, { K.GUARD_COUNT_AT, { 0x66, 0xC7, 0x81 } }, "the defender timer"),
    G.buildings + K.TIMER_FIELD, "the defender timer")
  G.guardRecord = scan(K.AOB_GUARD_RECORD, "where an outpost puts away a new defender")
  G.guardRecorded = G.guardRecord + K.GUARD_RECORDED
  G.area = readOperand(G.guardRecord, K.GUARD_AREA, "the area map")
  G.pathFinder = readOperand(G.guardRecord, K.GUARD_PATHS, "the path finder")
  F.navigate = core.exposeCode(readCallTarget(G.guardRecord, K.GUARD_NAVIGATE, "the area test"), 5, 1)
  F.setDestination = core.exposeCode(readCallTarget(G.guardRecord, K.GUARD_DESTINATION,
    "setDestinationForUnit"), 5, 1)
  expectBytes(G.guardRecorded, { 0x8B, 0x6C, 0x24, 0x10, 0x85, 0xED }, "the end of the defender slots")

  local wave = scan(K.AOB_WAVE_SIZE, "where an outpost sizes its waves")
  G.waveSize = wave + K.WAVE_SIZE_AT
  same(readOperand(wave, { K.WAVE_SIZE_AT, { 0x66, 0x89, 0x91 } }, "the wave size"), G.buildings + K.WAVE_FIELD,
    "the wave size")
  G.kinds = readOperand(wave, K.WAVE_SIZE_KINDS, "the outpost troop kinds") - K.KIND_BASE
  G.waveMax = 0
  for kind = 0, K.KINDS - 1 do
    local at = G.kinds + kind * K.KIND_STRIDE
    local most = (rd32(at + K.KIND_BASE) + rd32(at + K.KIND_RANGE) - 1) * (K.VANILLA_TOP + 1)
    if most > G.waveMax then G.waveMax = most end
  end
  G.waveStart = G.guardRecorded + K.WAVE_START_AT
  expectBytes(G.waveStart, { 0x85, 0xED, 0x0F, 0x85 }, "the start of the wave part")
  G.forming = G.waveStart + 8 + rd32(G.waveStart + 4)
  G.waveResume = G.waveStart + K.WAVE_START_SIZE

  G.defenderType = scan(K.AOB_DEFENDER_TYPE, "where an outpost picks its defenders")
  same(readOperand(G.defenderType, { 0x00, { 0x66, 0x83, 0xB9 } }, "the outpost type"), G.buildings + B.TYPE,
    "the building array")

  G.growth = scan(K.AOB_GROWTH, "where an outpost speeds up after a wave")
  same(readOperand(G.growth, { 0x00, { 0x66, 0x83, 0x80 } }, "the wave counter"), G.buildings + K.WAVES_FIELD,
    "the wave counter")
  same(readOperand(G.growth, { 0x08, { 0x66, 0x83, 0x80 } }, "the unit pace"), G.buildings + K.PACE_FIELD,
    "the unit pace")

  local launch = scan(K.AOB_LAUNCH, "where an outpost sends its wave")
  same(readOperand(launch, { 0x00, { 0x8B, 0x80 } }, "the wave troop"), G.buildings + B.TRIBE_UID, "the wave troop")
  G.aiState = readOperand(launch, K.LAUNCH_AI, "the AI state")
  G.launchSite = launch + K.LAUNCH_CALL
  G.register = readCallTarget(launch, K.LAUNCH_CALL, "aiRegisterTribeAndAssignTarget")
  G.setTarget = readCallTarget(G.register, K.REGISTER_SET_TARGET, "setTargetForTribeBasedOnTargetChoiceLogic")
  G.current = readOperand(launch, K.LAUNCH_CURRENT, "the current building")

  local make = scan(K.AOB_MAKE, "the outpost troops' update")
  G.tribeStride = readOperand(make, K.MAKE_STRIDE, "the troop size")
  G.decideSite = make + K.MAKE_CALL
  G.decide = readCallTarget(make, K.MAKE_CALL, "decideOnTribeAttackLocation")
  same(scan(K.AOB_DECIDE, "decideOnTribeAttackLocation"), G.decide, "decideOnTribeAttackLocation")
  local d = G.decide
  G.tribesThis = readOperand(d, K.DECIDE_TRIBES, "the troop array")
  G.tribes = G.tribesThis
  same(readOperand(make, K.MAKE_UID, "the troop uid"), G.tribes + T.UID, "the troop array")
  G.tribeTarget = readOperand(d, K.DECIDE_TARGET, "the troop's target player") - G.tribes
  G.tribeKind = readOperand(d, K.DECIDE_KIND, "the troop's kind") - G.tribes
  same(readOperand(d, K.DECIDE_OWNER, "the troop owner"), G.tribes + T.OWNER, "the troop owner")
  G.units = readOperand(d, K.DECIDE_UNIT_Y, "the unit array") - U.Y
  G.unitsThis = readOperand(d, K.DECIDE_UNITS_THIS, "the unit state")
  same(G.unitsThis, G.units - U.STATE_OFFSET, "the unit array")
  -- The reinforcement check subtracts the live unit count from the last unit index.
  local limit = scan("8D 44 38 06 B9 ? ? ? ? 2B 0D ? ? ? ? 50 51 B9 ? ? ? ? E8", "the unit limit")
  same(G.unitsThis + 4, readOperand(limit, { 9, { 0x2B, 0x0D } }, "the active unit count"),
    "the active unit count")
  local lastUnit = rd32(limit + 5)
  assert(lastUnit > 0 and lastUnit < 0xFFFF, "invalid unit table limit")
  G.unitCapacity = lastUnit + 1
  G.paths = readOperand(d, K.DECIDE_PATHS, "the path finder")
  G.rows = readOperand(d, K.DECIDE_ROWS, "the map rows")
  same(readOperand(d, K.DECIDE_BUILDING_UID, "the building uid"), G.buildings + B.UID, "the building array")
  G.players = readOperand(d, K.DECIDE_CAMP, "the player array") - P.CAMP

  F.busy = core.exposeCode(readCallTarget(d, K.DECIDE_BUSY, "checkTribeActivityPercentages"), 4, 1)
  F.lead = core.exposeCode(readCallTarget(d, K.DECIDE_LEAD, "getUnitIDForIndexInTribe"), 3, 1)
  F.path = core.exposeCode(readCallTarget(d, K.DECIDE_PATH, "pathFindingToAttackCastleIncludingMoat"), 8, 1)
  local relay = readCallTarget(d, K.DECIDE_RELAY, "relayTribeInstruction")
  F.reach = core.exposeCode(readCallTarget(d, K.DECIDE_REACH, "canNavigateUnitsFromTileToTargetTile"), 3, 1)
  F.command = core.exposeCode(readCallTarget(d, K.DECIDE_COMMAND, "commandUnitsToLocation"), 5, 1)
  F.decide = core.exposeCode(G.decide, 2, 1)
  F.register = core.exposeCode(G.register, 3, 1)

  local instruction = scan(K.AOB_INSTRUCTION, "giveTribeAnInstruction")
  expectBytes(relay, { 0xB9 }, "relayTribeInstruction")
  same(relay + 10 + rd32(relay + 6), instruction, "giveTribeAnInstruction")
  F.instruction = core.exposeCode(instruction, 6, 1)
  F.createTribe = core.exposeCode(scan(K.AOB_CREATE_TRIBE, "createTribeForPlayer"), 2, 1)
  F.addToTribe = core.exposeCode(scan(K.AOB_ADD_TO_TRIBE, "addUnitToTribe"), 3, 1)
  F.removeFromTribe = core.exposeCode(scan(K.AOB_REMOVE_FROM_TRIBE, "removeUnitFromTribe"), 3, 1)
  F.setStance = core.exposeCode(scan(K.AOB_STANCE, "setUnitStance"), 3, 1)
  G.teams = rd32(scan(K.AOB_TEAMS, "the team table") + K.TEAMS_OPERAND)
  F.move = core.exposeCode(scan(K.AOB_MOVE, "giveTribeMoveInstruction"), 7, 1)
  F.addToItsTribe = core.exposeCode(scan(K.AOB_ADD_TO_ITS_TRIBE, "addUnitToItsTribe"), 3, 1)
  F.addPoint = core.exposeCode(scan(K.AOB_ADD_POINT, "addRallyPoint"), 5, 1)
  G.tileFlags = rd32(scan(K.AOB_TILE_FLAGS, "the tile flags") + K.TILE_FLAGS_OPERAND)
  G.buildingLayer = G.tileFlags + K.FLAGS_TO_BUILDINGS
  G.wallOwner = G.tileFlags + K.FLAGS_TO_WALL_OWNER
  same(G.rows, G.tileFlags + K.FLAGS_TO_ROWS, "the map layers")
  G.ticks = rd32(scan(K.AOB_TICKS, "the game tick counter") + K.TICKS_OPERAND)
end

-- Siege engines on the way. smarter-recruits patches the 8 bytes right before the update table
-- read, so the pattern starts after them.
local function resolveSiege()
  local acquire = scan(K.AOB_ACQUIRE, "acquireShootTarget")
  G.ranges = rangeTable(acquire + K.ACQUIRE_RANGE)
  F.acquire = core.exposeCode(acquire, 2, 1)
  F.halt = core.exposeCode(scan(K.AOB_HALT, "the game's stop walking"), 2, 1)
  local call = scan(K.AOB_UPDATE_CALL, "where every unit's update function is called")
  G.updateTable = readOperand(call, K.UPDATE_TABLE, "the update function table")
  G.currentUnit = readOperand(call, K.UPDATE_CURRENT, "the current unit")
  G.ticks = rd32(scan(K.AOB_TICKS, "the game tick counter") + K.TICKS_OPERAND)
end

local function resolvePanel()
  local panel = scan(K.AOB_PANEL, "the outpost panel")
  G.panel = panel
  G.selected = readOperand(panel, K.PANEL_SELECTED, "the selected building")
  same(readOperand(panel, K.PANEL_TYPE, "the outpost type"), G.buildings + B.TYPE, "the building array")
  G.menuY = readOperand(panel, K.PANEL_MENU_Y, "the panel position")
  G.menuX = readOperand(panel, K.PANEL_MENU_X, "the panel position")
  G.textManager = readOperand(panel, K.PANEL_TEXT_MANAGER, "the text manager")
  G.renderText = readCallTarget(panel, K.PANEL_RENDER_TEXT, "renderTextToScreen")
  G.getText = readCallTarget(panel, K.PANEL_GET_TEXT, "getTextStringInGroupAtOffset")

  local render = scan(K.AOB_BUTTON_RENDER, "the outpost's troop buttons")
  G.buttonRender = render
  same(readOperand(render, K.RENDER_SELECTED, "the selected building"), G.selected, "the selected building")
  same(readOperand(render, K.RENDER_MASK, "the troop buttons"), G.buildings + B.MASK, "the troop buttons")
  G.hover = readOperand(render, K.RENDER_HOVER, "the button hover flag")
  G.button = readCallTarget(render, K.RENDER_BUTTON, "the button renderer")
  G.buttonX = readOperand(render, K.RENDER_X, "the button place")
  same(readOperand(render, K.RENDER_Y, "the button place"), G.buttonX + 4, "the button place")
  same(readOperand(render, K.RENDER_W, "the button place"), G.buttonX + 8, "the button place")
  same(readOperand(render, K.RENDER_TEXT_MANAGER, "the text manager"), G.textManager, "the text manager")
  G.shadowText = readCallTarget(render, K.RENDER_SHADOW_TEXT, "renderInGameTextWithShadow")
  G.buttonImage = readOperand(G.button, K.BUTTON_IMAGE, "the button picture")
  G.drawChoice = readOperand(G.button, K.BUTTON_DRAW_CHOICE, "the draw buffer")

  G.buttonClick = scan(K.AOB_BUTTON_CLICK, "the outpost's troop button click")
  same(readOperand(G.buttonClick, { 0x00, { 0xA1 } }, "the selected building"), G.selected, "the selected building")
  G.sizeSlider = scan(K.AOB_SIZE, "the outpost's size slider")
  G.delaySlider = scan(K.AOB_DELAY, "the outpost's start delay slider")
  same(readOperand(G.sizeSlider, K.SLIDER_SELECTED, "the selected building"), G.selected, "the selected building")
  same(readOperand(G.delaySlider, K.SLIDER_SELECTED, "the selected building"), G.selected, "the selected building")
  same(readOperand(G.sizeSlider, K.SLIDER_FIELD, "the wave size"), G.buildings + K.SIZE_FIELD, "the wave size")
  same(readOperand(G.delaySlider, K.SLIDER_FIELD, "the start delay"), G.buildings + K.DELAY_FIELD,
    "the start delay")

  local menuItem = scan(K.AOB_MENU_ITEM, "the menu item handler")
  G.mouse = readOperand(menuItem, K.MENU_ITEM_MOUSE, "the mouse")
  local toolbar = scan(K.AOB_TOOLBAR, "the toolbar key handler") - K.TOOLBAR_PATTERN_OFFSET
  G.clickSound = readOperand(toolbar, K.TOOLBAR_SOUND_ID, "the click sound")
  G.sounds = readOperand(toolbar, K.TOOLBAR_SOUNDS, "the sound player")
  G.playSound = readCallTarget(toolbar, K.TOOLBAR_PLAY_SOUND, "the sound player")

  -- The static size slider item: its group's picture, the menu's item table and the menu.
  local pattern = {}
  for _, value in ipairs({ 5, K.SLIDER_X, K.GAME_SIZE_Y, K.SLIDER_W, K.SLIDER_H, G.sizeSlider }) do
    for _, byte in ipairs(core.itob(value)) do pattern[#pattern + 1] = string.format("%02X", byte & 0xFF) end
  end
  local sizeItem = scan(table.concat(pattern, " "), "the outpost's size slider item")
  local header = sizeItem - K.SIZE_ITEM_FROM_GROUP * K.ITEM_SIZE
  if rd32(header + K.ITEM_TYPE) ~= K.TYPE_GROUP then
    error(MODULE_NAME .. ": the outpost menu is not the one this module knows")
  end
  same(rd32(header + K.ITEM_SIZE + K.ITEM_IMAGE), K.TEXT_BUTTON, "the outpost's button picture")
  G.sizeItem = sizeItem
  G.sliderRender = rd32(sizeItem + K.ITEM_RENDER)
  G.delayItem = sizeItem + K.ITEM_SIZE
  same(rd32(G.delayItem + K.ITEM_ACTION), G.delaySlider, "the outpost's start delay slider item")
  same(rd32(G.delayItem + K.ITEM_Y), K.GAME_DELAY_Y, "the outpost's start delay slider item")
  local start, limit = header, 400
  while rd32(start - K.ITEM_SIZE + K.ITEM_TYPE) ~= K.TYPE_LAST and limit > 0 do
    start = start - K.ITEM_SIZE
    limit = limit - 1
  end
  local bytes = {}
  for _, byte in ipairs(core.itob(start)) do bytes[#bytes + 1] = string.format("%02X", byte & 0xFF) end
  local ok, constructor = pcall(core.AOBScan, "68 " .. table.concat(bytes, " ") .. " B9")
  if ok and constructor ~= nil then
    G.menu = rd32(constructor + 6)
  else
    log(WARNING, MODULE_NAME .. ": could not find the building menu; switching the page may show "
      .. "the sliders of the other page until the panel is opened again")
  end
  F.sizeSlider = core.exposeCode(G.sizeSlider, 5, 0)
end

---Writes the panel's own words from the locale catalog `name` (plain one-line entries), each
---passed through `encode`.
local function writeWords(name, encode)
  local file = io.open(K.LOCALE .. name .. ".yml", "rb")
  if file == nil then error("missing locale/" .. name .. ".yml") end
  local catalog = "\n" .. file:read("a")
  file:close()
  for key, at in pairs(G.words) do
    local text = catalog:match("\n" .. key .. ": ([^\r\n]+)")
    if text == nil then error("locale/" .. name .. ".yml has no " .. key) end
    wr32(at, cString(encode(text)))
  end
end

---The panel's words in the game's language; English stays where that is unknown or fails.
local function localizeWords()
  local owner = modules.textResourceModifier
  local name = K.CATALOGS[tostring(owner:GetLanguage()):lower()]
  if name == nil then return end
  local ok, problem = pcall(writeWords, name, function(text)
    local encoded = owner:TransformText(text)
    if encoded:match("^ERROR:") then error("textResourceModifier cannot encode " .. text, 0) end
    return encoded
  end)
  if not ok then log(WARNING, "the outpost panel keeps its English words: " .. tostring(problem)) end
end

local function allocate()
  G.table = core.allocate(K.MAX_BUILDINGS * K.ENTRY_SIZE, true)
  G.slots = core.allocate(K.MAX_BUILDINGS * K.MAX_GUARDS * 8, true)
  G.drag = core.allocate(4, true)
  G.siegeUnit = core.allocate(4, true)
  G.riderUnit = core.allocate(4, true)
  G.guardUnit = core.allocate(4, true)
  G.numberText = core.allocate(16, true)
  G.jobs = core.allocate(K.MAX_TRIBES, true)
  G.jobUids = core.allocate(K.MAX_TRIBES * 4, true)
  G.mode = core.allocate(4, true)
  G.launchTribe = core.allocate(4, true)
  G.launchThis = core.allocate(4, true)
  G.decideTribe = core.allocate(4, true)
  G.decideThis = core.allocate(4, true)
  G.scratch = core.allocate(16, true)
  G.defenderTypes = core.allocate(16, true)
  for index, kind in ipairs(K.DEFENDER_TYPES) do wr8(G.defenderTypes + index - 1, kind) end
  G.defenderTexts = core.allocate(16 * 8, true)
  for index, text in ipairs(K.DEFENDER_TEXTS) do
    wr32(G.defenderTexts + (index - 1) * 8, text[1])
    wr32(G.defenderTexts + (index - 1) * 8 + 4, text[2])
  end
  G.pageTexts = core.allocate(2 * 4, true)
  -- Labels: x, y, text (0 = the game's text with that id), id.
  local function labels(list)
    local at = core.allocate(#list * 16, true)
    for index, label in ipairs(list) do
      for field = 1, 4 do wr32(at + (index - 1) * 16 + (field - 1) * 4, label[field]) end
    end
    return at, #list
  end
  G.attackLabels, G.attackLabelCount = labels({
    { K.LABEL_X, K.SIZE_Y + K.LABEL_DROP, 0, K.TEXT_SIZE }, { K.LABEL_X, K.DELAY_Y + K.LABEL_DROP, 0, K.TEXT_DELAY },
    { K.LABEL_X, K.GROWTH_Y + K.LABEL_DROP, 0, 0 },
  })
  local sizeY = O.growth and K.SIZE_Y or K.GAME_SIZE_Y
  G.defendLabels, G.defendLabelCount = labels({ { K.LABEL_X, sizeY + K.LABEL_DROP, 0, 0 } })
  -- where each of the panel's own words is read from
  G.words = { panel_attackers = G.pageTexts, panel_defenders = G.pageTexts + 4,
    panel_growth = G.attackLabels + 2 * 16 + 8, panel_amount = G.defendLabels + 8 }
  writeWords("en", function(text) return text end)
end

local function install(self)
  local values = {
    MAX_BUILDINGS = K.MAX_BUILDINGS, MAX_TRIBES = K.MAX_TRIBES, B_STRIDE = B.STRIDE,
    B_UID = G.buildings + B.UID, B_TYPE = G.buildings + B.TYPE, B_DEFENDERS = G.defendersField,
    B_WAVES = G.buildings + K.WAVES_FIELD, B_PACE = G.buildings + K.PACE_FIELD,
    TABLE = G.table, ENTRY_SHIFT = K.ENTRY_SHIFT, MAX_DEFENDERS = K.MAX_DEFENDERS, USUAL_DEFENDERS = K.USUAL_DEFENDERS,
    CURRENT_BUILDING = G.current, ARAB_OUTPOST = K.OUTPOST_ARAB, EURO_ARCHER = K.EURO_ARCHER,
    ARAB_ARCHER = K.ARAB_ARCHER, DEFENDER_TYPES = G.defenderTypes,
    SLOTS = G.slots, SLOT_BYTES = K.MAX_GUARDS * 8, SLOT_DWORDS = K.MAX_GUARDS * 2, MAX_GUARDS = K.MAX_GUARDS,
    U_STRIDE = U.STRIDE, U_UID = G.units + U.UID, UNIT_CAPACITY = G.unitCapacity,
    UNIT_COUNT = G.unitsThis, VANILLA_SLOTS = K.VANILLA_SLOTS,
  }
  self.saved = {}
  local function keep(address, size)
    self.saved[#self.saved + 1] = { address = address, bytes = core.readBytes(address, size) }
  end

  values.ENTRY_GET = assemble(templates.entryGet, values)
  values.ENTRY_MAKE = assemble(templates.entryMake, values)

  if O.defenders then
    keep(G.defenderCount, K.DEFENDER_COUNT_SIZE)
    values.SKIP, values.ROLL, values.RESUME = G.skip, G.roll, G.defenderCount + K.DEFENDER_COUNT_SIZE
    jumpTo(G.defenderCount, assemble(templates.defenderCount, values), K.DEFENDER_COUNT_SIZE)
    keep(G.guardCount, K.GUARD_COUNT_SIZE)
    values.B_TIMER, values.GUARD_PACE = G.buildings + K.TIMER_FIELD, K.GUARD_PACE
    values.LONGEST_WAIT, values.SHORTEST_WAIT = K.LONGEST_WAIT, K.SHORTEST_WAIT
    values.PICK, values.RESUME = G.defenderType, G.guardCount + K.GUARD_COUNT_SIZE
    jumpTo(G.guardCount, assemble(templates.guardCount, values), K.GUARD_COUNT_SIZE)
    keep(G.guardRecord, K.GUARD_RECORD_SIZE)
    values.DONE, values.RESUME = G.guardRecorded, G.guardRecord + K.GUARD_RECORD_SIZE
    values.GUARD_UNIT, values.PAD = G.guardUnit, pad(onGuard, "outpost guards")
    jumpTo(G.guardRecord, assemble(templates.guardRecord, values), K.GUARD_RECORD_SIZE)
    keep(G.defenderType, K.DEFENDER_TYPE_SIZE)
    values.RESUME = G.defenderType + K.DEFENDER_TYPE_SIZE
    jumpTo(G.defenderType, assemble(templates.defenderType, values), K.DEFENDER_TYPE_SIZE)
  end

  values.WAVES_ON, values.GROWTH_ON = O.waves and 1 or 0, O.growth and 1 or 0
  values.B_WAVE, values.GROWTH_CAP = G.buildings + K.WAVE_FIELD, K.GROWTH_CAP
  if O.waves or O.growth then
    keep(G.waveSize, K.WAVE_SIZE_SIZE)
    values.RESUME = G.waveSize + K.WAVE_SIZE_SIZE
    jumpTo(G.waveSize, assemble(templates.waveSize, values), K.WAVE_SIZE_SIZE)
  end
  if O.waves then
    values.KINDS, values.KIND_STRIDE = G.kinds, K.KIND_STRIDE
    values.KIND_BASE, values.KIND_RANGE = K.KIND_BASE, K.KIND_RANGE
    values.B_MASK, values.B_SIZE = G.buildings + B.MASK, G.buildings + K.SIZE_FIELD
    values.B_WAVE, values.WAVE_MAX, values.VANILLA_TOP = G.buildings + K.WAVE_FIELD, G.waveMax, K.VANILLA_TOP
    values.KIND_AVERAGE = assemble(templates.kindAverage, values)
    values.WAVE_VALUE = assemble(templates.waveValue, values)
    keep(G.waveStart, K.WAVE_START_SIZE)
    values.UPDATE_END, values.FORMING, values.RESUME = G.growth + K.GROWTH_SIZE, G.forming, G.waveResume
    expectBytes(values.UPDATE_END, { 0x5D, 0x5F, 0x5E, 0x5B }, "the end of the outpost update")
    jumpTo(G.waveStart, assemble(templates.waveStart, values), K.WAVE_START_SIZE)
  end


  if O.jobs or O.siege or O.join or O.retarget then
    values.LAUNCH_TRIBE, values.LAUNCH_THIS, values.REGISTER = G.launchTribe, G.launchThis, G.register
    values.PAD = pad(onLaunch, "splitting waves")
    keep(G.launchSite, 5)
    callTo(G.launchSite, assemble(templates.launch, values))

    values.JOBS, values.JOB_UIDS, values.TRIBE_STRIDE = G.jobs, G.jobUids, G.tribeStride
    values.TRIBE_UID, values.TRIBE_KIND = G.tribes + T.UID, G.tribes + G.tribeKind
    values.JOB_ENGAGE, values.JOB_BUILDINGS = K.JOB_ENGAGE, K.JOB_BUILDINGS
    values.KIND_RANGED, values.KIND_MELEE = K.KIND_RANGED, K.KIND_MELEE
    values.DECIDE_TRIBE, values.DECIDE_THIS, values.DECIDE = G.decideTribe, G.decideThis, G.decide
    values.RETARGET, values.SET_TARGET = O.retarget and 1 or 0, G.setTarget
    values.TRIBE_TARGET, values.TRIBE_OWNER = G.tribes + G.tribeTarget, G.tribes + T.OWNER
    values.P_STRIDE, values.P_LORD, values.P_LORD_UID = P.STRIDE, G.players + P.LORD, G.players + P.LORD_UID
    values.U_STATE, values.U_TYPE, values.LORD_TYPE = G.units + U.STATE, G.units + U.TYPE, K.LORD_TYPE
    values.PAD = pad(onDecide, "outpost troop orders")
    keep(G.decideSite, 5)
    callTo(G.decideSite, assemble(templates.decide, values))
  end

  if O.siege or O.riders then
    G.originalUpdates = core.allocate(K.UNIT_TYPES * 4, true)
    for kind = 0, K.UNIT_TYPES - 1 do wr32(G.originalUpdates + kind * 4, rd32(G.updateTable + kind * 4)) end
    values.CURRENT_UNIT, values.TICKS, values.SIEGE_EVERY = G.currentUnit, G.ticks, K.SIEGE_EVERY
    values.U_BEHAVIOUR, values.U_ACTION, values.U_TYPE = G.units + U.BEHAVIOUR, G.units + U.ACTION, G.units + U.TYPE
    values.OUTPOST_BEHAVIOUR, values.STATE_MOVING = K.OUTPOST_BEHAVIOUR, K.STATE_MOVING
    values.STATE_WALKING, values.ORIGINAL_UPDATES = K.STATE_WALKING, G.originalUpdates
  end
  if O.siege then
    values.STATE_CREEPING, values.SIEGE_UNIT = K.STATE_CREEPING, G.siegeUnit
    values.PAD = pad(onSiegeUnit, "siege engines on the way")
    local check = assemble(templates.siegeCheck, values)
    for kind in pairs(K.SIEGE) do
      keep(G.updateTable + kind * 4, 4)
      core.writeCodeInteger(G.updateTable + kind * 4, check)
    end
  end
  if O.riders then
    -- the same check for knight guards; their states 0, 1 and 0x65 only
    values.STATE_CREEPING, values.SIEGE_UNIT = K.STATE_MOVING, G.riderUnit
    values.PAD = pad(onRider, "patrolling knights")
    keep(G.updateTable + K.KNIGHT * 4, 4)
    core.writeCodeInteger(G.updateTable + K.KNIGHT * 4, assemble(templates.siegeCheck, values))
  end

  if O.defenders or O.growth or O.waves then
    values.MODE, values.SELECTED = G.mode, G.selected
    values.MENU_X, values.MENU_Y = G.menuX, G.menuY
    values.TEXT_MANAGER, values.RENDER_TEXT, values.SHADOW_TEXT = G.textManager, G.renderText, G.shadowText
    values.GET_TEXT, values.PAGE_TEXTS, values.DEFENDER_TEXTS = G.getText, G.pageTexts, G.defenderTexts
    values.MOUSE, values.MOUSE_X, values.MOUSE_Y = G.mouse, K.MOUSE_X, K.MOUSE_Y
    values.LEFT_CLICK, values.LEFT_HELD = K.LEFT_CLICK, K.LEFT_HELD
    values.CLICK_SOUND, values.SOUNDS, values.PLAY_SOUND = G.clickSound, G.sounds, G.playSound
    values.BUTTON_X, values.BUTTON_HOVER, values.BUTTON_IMAGE = G.buttonX, G.hover, G.buttonImage
    values.DRAW_CHOICE, values.BUTTON_RENDER, values.TEXT_BUTTON = G.drawChoice, G.button, K.TEXT_BUTTON
    values.TOGGLE_X, values.TOGGLE_Y, values.TOGGLE_W, values.TOGGLE_H = K.TOGGLE_X, K.TOGGLE_Y, K.TOGGLE_W, K.TOGGLE_H
    values.TOGGLE_HALF = K.TOGGLE_W // 2
    values.GROWTH_ON, values.TOGGLE_ON = O.growth and 1 or 0, O.defenders and 1 or 0
    values.NUMBER_TEXT, values.NUMBER_X, values.TICKS_PER_SECOND = G.numberText, K.NUMBER_X, K.TICKS_PER_SECOND
    values.B_SIZE, values.B_DELAY = G.buildings + K.SIZE_FIELD, G.buildings + K.DELAY_FIELD
    values.SIZE_ROW = (O.growth and K.SIZE_Y or K.GAME_SIZE_Y) + K.LABEL_DROP
    values.DELAY_ROW = (O.growth and K.DELAY_Y or K.GAME_DELAY_Y) + K.LABEL_DROP
    values.GROWTH_ROW = K.GROWTH_Y + K.LABEL_DROP
    values.NUMBERS = assemble(templates.numbers, values)

    if O.growth then
      values.LABEL_TABLE, values.LABEL_COUNT = G.attackLabels, G.attackLabelCount
      values.ATTACK_LABELS = assemble(templates.labels, values)
      values.GROWTH_X, values.GROWTH_Y, values.GROWTH_W, values.GROWTH_H = K.SLIDER_X, K.GROWTH_Y, K.SLIDER_W, K.SLIDER_H
      values.KNOB_W, values.KNOB_HALF, values.KNOB_SPAN = K.KNOB_W, K.KNOB_W // 2, K.SLIDER_W - K.KNOB_W
      values.KNOB_ABOVE, values.KNOB_H = K.KNOB_ABOVE, K.KNOB_H
      values.DRAG, values.SLIDER_RENDER = G.drag, G.sliderRender
      values.GROWTH_SLIDER = assemble(templates.growthSlider, values)
      moveSliders()
      hooks.registerHookCallback("afterInit", function() moveSliders() end)
    end

    if O.defenders then
      values.LABEL_TABLE, values.LABEL_COUNT = G.defendLabels, G.defendLabelCount
      values.DEFENDER_LABELS = assemble(templates.labels, values)
      values.PAD = pad(refreshSliders, "the outpost panel")
      values.TOGGLE = assemble(templates.toggle, values)

      keep(G.buttonRender, K.BUTTON_RENDER_SIZE)
      values.RESUME = G.buttonRender + K.BUTTON_RENDER_SIZE
      jumpTo(G.buttonRender, assemble(templates.buttonRender, values), K.BUTTON_RENDER_SIZE)
      keep(G.buttonClick, K.BUTTON_CLICK_SIZE)
      values.RESUME = G.buttonClick + K.BUTTON_CLICK_SIZE
      jumpTo(G.buttonClick, assemble(templates.buttonClick, values), K.BUTTON_CLICK_SIZE)
    end
    if O.defenders or O.waves then
      if O.waves then values.WAVE_SLIDER = assemble(templates.waveSlider, values) end
      keep(G.sizeSlider, K.SLIDER_SIZE)
      values.RESUME, values.FIELD, values.TOP, values.STEP, values.SYNC = G.sizeSlider + K.SLIDER_SIZE, 6,
        K.MAX_DEFENDERS, 1, 1
      jumpTo(G.sizeSlider, assemble(templates.slider, values), K.SLIDER_SIZE)
    end

    keep(G.panel, 5)
    values.RESUME = G.panel + 5
    jumpTo(G.panel, assemble(templates.panel, values), 5)
  end
end

local function enable(self, config)
  config = config or {}
  O.defenders = setting(config, "defenders", "enabled") == true
  O.walls = O.defenders and setting(config, "defenders", "walls") == true
  O.waves = setting(config, "waves", "exact") == true
  O.riders = O.defenders and setting(config, "defenders", "knights") == true
  O.growth = setting(config, "growth", "enabled") == true
  O.jobs = setting(config, "jobs", "enabled") == true
  O.siege = setting(config, "siege", "enabled") == true
  O.join = setting(config, "join", "enabled") == true
  O.retarget = setting(config, "retarget", "enabled") == true
  O.log = setting(config, "diagnostics", "log") == true
  O.plans = {}
  for _, plan in ipairs(K.PLANS) do
    O.plans[plan.kind] = { first = plan.first, rest = plan.rest, share = percent(setting(config, "jobs", plan.name)) }
  end
  if not O.defenders and not O.growth and not O.jobs and not O.siege and not O.join and not O.retarget
      and not O.waves then
    log(INFO, MODULE_NAME .. ": every part is off")
    return
  end

  -- A part whose code is not found (another module changed it) stays off on its own.
  local ok, problem = pcall(resolve)
  if not ok then
    log(WARNING, tostring(problem))
    return
  end
  if O.defenders or O.growth or O.waves then
    ok, problem = pcall(resolvePanel)
    if not ok then
      log(WARNING, tostring(problem) .. "; the outpost panel pages, defenders, growth and wave sizes stay off")
      O.defenders, O.growth, O.waves, O.walls, O.riders = false, false, false, false, false
    end
  end
  if O.siege or O.riders then
    ok, problem = pcall(resolveSiege)
    if not ok then
      log(WARNING, tostring(problem) .. "; siege engines on the way and knights attacking buildings stay off")
      O.siege, O.riders = false, false
    end
  end
  allocate()
  if O.defenders or O.growth or O.waves then hooks.registerHookCallback("afterInit", localizeWords) end

  modules["map-extensions"]:registerSection(K.SAVE_SECTION, {
    initialize = function(_) wipe() end,
    serialize = function(_, handle) serialize(handle) end,
    deserialize = function(_, handle) deserialize(handle) end,
  })

  install(self)
  log(INFO, string.format("%s: on (defenders %s, growth %s, jobs %s, siege engines %s, waves to the AI army %s); buildings 0x%X, "
    .. "troops 0x%X (size 0x%X), units 0x%X", MODULE_NAME, O.defenders and "on" or "off",
    O.growth and "on" or "off", O.jobs and "on" or "off", O.siege and "on" or "off", O.join and "on" or "off", G.buildings, G.tribes,
    G.tribeStride, G.units))
end

local function disable(self, config)
  if self.saved ~= nil then
    for _, saved in ipairs(self.saved) do core.writeCode(saved.address, saved.bytes) end
    self.saved = nil
  end
end

return {
  enable = enable,
  disable = disable,
}
