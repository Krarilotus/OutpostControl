--[[
  Outpost Control

  Outposts (the European and Arabian outposts of the map editor) send waves of attackers
  and keep a handful of archers around themselves. This module adds to that:

  1. Defenders. A second page in the outpost's panel (a button over the panel's title switches
     it) uses the same eight troop buttons and the same two sliders: the buttons pick which
     troops guard the outpost (several may be picked, they take turns), the first slider how
     many (0 to 8, the game's own slots). The game's own defender count field gets the same
     number (at least 1), so the map still means about the same without the module.
  2. Growth. The second slider of that page: how fast the waves get bigger and come quicker
     over the game. The game shortens the wait between waves by 100 ticks and the wait
     between units by 4 after every wave; this scales both, 0 to 100 percent (100 = the game).
  3. Jobs. When a wave leaves, its troops are split by unit type into troops with a job of
     their own: filling the moat, hacking at walls and gates, burning or wrecking buildings,
     fighting the troops they meet, riding round the castle, or hunting the lord. Each troop
     is registered with the AI like the wave was, so the outpost's own attack logic keeps
     looking after it; this module only changes what it is told to do.

  The per-outpost settings and the jobs live in the save (and in the map) through the
  map-extensions module. Without this module the game ignores that data.
]]

local MODULE_NAME = "outpost-control"
local SAVE_SECTION = "outpost-control"
local SAVE_BUILDINGS = "buildings.bin"
local SAVE_JOBS = "jobs.bin"

local templates = require("templates")

-- Jobs.
local JOB_NONE, JOB_ENGAGE, JOB_BUILDINGS, JOB_MOAT, JOB_WALLS, JOB_LORD, JOB_PATROL = 0, 1, 2, 3, 4, 5, 6
local JOB_NAMES = { [0] = "as the game does", "fight troops", "attack buildings", "fill the moat",
  "attack walls and gates", "hunt the lord", "ride round the castle" }

-- Each unit type an outpost sends: the first job, its default share in percent, the job of the
-- rest, and the setting that holds the share.
local PLANS = {
  { kind = 71, name = "slaves", first = JOB_MOAT, rest = JOB_BUILDINGS, share = 50 },
  { kind = 24, name = "spearmen", first = JOB_MOAT, rest = JOB_WALLS, share = 50 },
  { kind = 26, name = "macemen", first = JOB_MOAT, rest = JOB_BUILDINGS, share = 30 },
  { kind = 27, name = "swordsmen", first = JOB_WALLS, rest = JOB_BUILDINGS, share = 60 },
  { kind = 75, name = "arab_swordsmen", first = JOB_WALLS, rest = JOB_BUILDINGS, share = 50 },
  { kind = 28, name = "knights", first = JOB_LORD, rest = JOB_PATROL, share = 40 },
  { kind = 22, name = "archers", first = JOB_MOAT, rest = JOB_ENGAGE, share = 30 },
  { kind = 70, name = "arab_archers", first = JOB_MOAT, rest = JOB_ENGAGE, share = 30 },
  { kind = 72, name = "slingers", first = JOB_PATROL, rest = JOB_ENGAGE, share = 30 },
  { kind = 74, name = "horse_archers", first = JOB_PATROL, rest = JOB_ENGAGE, share = 100 },
  { kind = 76, name = "fire_throwers", first = JOB_BUILDINGS, rest = JOB_ENGAGE, share = 60 },
}

local DEFAULTS = {
  defenders = { enabled = true },
  growth = { enabled = true },
  jobs = { enabled = true },
  diagnostics = { log = false },
}
for _, plan in ipairs(PLANS) do DEFAULTS.jobs[plan.name] = plan.share end

-- Defender troops per button, European outpost then Arabian outpost.
local DEFENDER_TYPES = {
  22, 23, 24, 25, 26, 27, 28, 37,
  70, 72, 74, 75, 71, 73, 76, 23,
}
local DEFENDER_NAMES = {
  "Archers", "Crossbowmen", "Spearmen", "Pikemen", "Macemen", "Swordsmen", "Knights", "Black Monks",
  "Archers", "Slingers", "Horse Archers", "Swordsmen", "Slaves", "Assassins", "Fire Throwers",
  "Crossbowmen",
}
local PAGE_NAMES = { "Attackers", "Defenders" }
-- The defender page's slider labels, at the places of the game's own (x, y from the panel).
local LABELS = {
  { 0x19, 0x205, "Amount" }, { 0x73, 0x1E9, "None" }, { 0xCB, 0x1E9, "8" },
  { 0x19, 0x23F, "Growth" }, { 0x73, 0x223, "None" }, { 0xCB, 0x223, "Full" },
}

local MAX_DEFENDERS = 8           -- the outpost's own defender slots
local USUAL_DEFENDERS = 7         -- the game rolls 6 or 7 when the field is unset
local GROWTH_STEP = 5
local MAX_BUILDINGS = 2000         -- the building array, both exes
local MAX_TRIBES = 1250            -- the troop array, both exes
local EURO_ARCHER, ARAB_ARCHER = 22, 70
local OUTPOST_EURO, OUTPOST_ARAB = 106, 107
local KIND_RANGED, KIND_MELEE = 0xB6, 0xB8
local STANCE_AGGRESSIVE = 2
local ORDER_ATTACK_UNIT, ORDER_ATTACK_WALL_AT, ORDER_DIG_MOAT = 4, 7, 0x23
local TEXT_BUTTON = 332           -- the outpost's own text button picture
-- The page button, over the panel's title (the title is drawn at 25, 463).
local TOGGLE_X, TOGGLE_Y, TOGGLE_W, TOGGLE_H = 18, 456, 125, 30

local PATROL_RADIUS = 25          -- tiles round the lord
local PATROL_ARRIVED = 4
local WAIT = { [JOB_MOAT] = 3, [JOB_WALLS] = 3, [JOB_LORD] = 2, [JOB_PATROL] = 10 }

---------------------------------------------------------------------------------------
-- What the game's code looks like where this module reads it (the same in both exes)
---------------------------------------------------------------------------------------

-- UpdateOutpostBuilding: is the defender count set (cmp byte [ecx+field],0 / jle roll).
local AOB_DEFENDER_COUNT = "80 B9 ? ? ? ? 00 0F 8E ? ? ? ? 66 83 81 ? ? ? ? FF 0F B7 81 ? ? ? ? 66 85 C0 0F 8D"
local DEFENDER_COUNT_SIZE = 13
local DEFENDER_COUNT_FIELD = 0x2A7
-- UpdateOutpostBuilding: the defender's type (archer, or Arab archer at an Arabian outpost).
local AOB_DEFENDER_TYPE = "66 83 B9 ? ? ? ? 6B BA 16 00 00 00 75 05 BA 46 00 00 00"
local DEFENDER_TYPE_SIZE = 20
-- UpdateOutpostBuilding, after a wave: add 100 to the wave counter, 4 to the unit pace.
local AOB_GROWTH = "66 83 80 ? ? ? ? 64 66 83 80 ? ? ? ? 04 5D 5F 5E 5B 83 C4 1C C3"
local GROWTH_SIZE = 16
local WAVES_FIELD, PACE_FIELD = 0x316, 0x318
-- UpdateOutpostBuilding: aiRegisterTribeAndAssignTarget(tribe, uid) sends the wave.
local AOB_LAUNCH = "8B 80 ? ? ? ? 50 56 B9 ? ? ? ? E8 ? ? ? ? A1 ? ? ? ? 69 C0 2C 03 00 00 66 C7 80 ? ? ? ? 00 00 66 83"
local LAUNCH_AI = { 0x08, { 0xB9 } }
local LAUNCH_CALL = 0x0D
local LAUNCH_CURRENT = { 0x12, { 0xA1 } }
-- makeOutpostTribesAttack: every registered outpost troop -> decideOnTribeAttackLocation.
local AOB_MAKE = "53 55 56 8B E9 57 8D ? ? ? ? 00 8D ? ? ? ? 00 BB E8 03 00 00 0F BF 06 85 C0 74 ? 8B C8 "
  .. "69 C9 ? ? 00 00 8B 91 ? ? ? ? 3B 17 75 ? 50 8B CD E8"
local MAKE_STRIDE = { 0x20, { 0x69, 0xC9 } }
local MAKE_UID = { 0x26, { 0x8B, 0x91 } }
local MAKE_CALL = 0x33
-- decideOnTribeAttackLocation(tribe): the outpost troops' own order logic.
local AOB_DECIDE = "83 EC 0C 57 8B 7C 24 14 6A 01 6A 00 57 89 4C 24 10 E8 ? ? ? ? 85 C0"
local DECIDE_BUSY = 0x11
local DECIDE_TARGET = { 0x41, { 0x0F, 0xBF, 0xAE } }
local DECIDE_TRIBES = { 0x91, { 0xB9 } }
local DECIDE_LEAD = 0xA9
local DECIDE_UNIT_Y = { 0xC6, { 0x0F, 0xBF, 0x88 } }
local DECIDE_OWNER = { 0xD9, { 0x8B, 0x86 } }
local DECIDE_PATHS = { 0xE3, { 0xB9 } }
local DECIDE_PATH = 0xE8
local DECIDE_ROWS = { 0xFE, { 0x8B, 0x14, 0x8D } }
local DECIDE_UNITS_THIS = { 0x10F, { 0xB9 } }
local DECIDE_RELAY = 0x114
local DECIDE_KIND = { 0x145, { 0x0F, 0xB7, 0x86 } }
local DECIDE_BUILDING_UID = { 0x187, { 0x8B, 0x90 } }
local DECIDE_CAMP = { 0x229, { 0x8B, 0x98 } }
local DECIDE_REACH = 0x24C
local DECIDE_COMMAND = 0x263

-- The outpost panel: its text, the troop buttons, their click, the two sliders.
local AOB_PANEL = "A1 ? ? ? ? 69 C0 2C 03 00 00 33 D2 66 83 B8 ? ? ? ? 6B 75 05 BA 09 00 00 00 A1 ?"
local PANEL_SELECTED = { 0x00, { 0xA1 } }
local PANEL_TYPE = { 0x0D, { 0x66, 0x83, 0xB8 } }
local PANEL_MENU_Y = { 0x1C, { 0xA1 } }
local PANEL_MENU_X = { 0x21, { 0x8B, 0x0D } }
local PANEL_TEXT_MANAGER = { 0x3E, { 0xB9 } }
local PANEL_RENDER_TEXT = 0x4E
local AOB_BUTTON_RENDER = "56 57 8B 7C 24 0C 8B CF BA 01 00 00 00 D3 E2 8B 0D ? ? ? ? 8B C1 69 C0 2C 03 00 00 "
  .. "33 F6 66 83 B8 ? ? ? ? 6B 75"
local BUTTON_RENDER_SIZE = 8
local RENDER_SELECTED = { 0x0F, { 0x8B, 0x0D } }
local RENDER_HOVER = { 0x2E, { 0x83, 0x3D } }
local RENDER_MASK = { 0x3B, { 0x0F, 0xBF, 0x80 } }
local RENDER_BUTTON = 0x5A
local RENDER_W = { 0xA6, { 0xA1 } }
local RENDER_Y = { 0xAB, { 0x8B, 0x0D } }
local RENDER_X = { 0xBC, { 0x03, 0x05 } }
local RENDER_TEXT_MANAGER = { 0xCA, { 0xB9 } }
local RENDER_SHADOW_TEXT = 0xDA
local AOB_BUTTON_CLICK = "A1 ? ? ? ? 8B 4C 24 04 69 C0 2C 03 00 00 BA 01 00 00 00 D3 E2 8D 80 ? ? ? ? 66 31 10"
local BUTTON_CLICK_SIZE = 5
local AOB_SLIDER = "8B 4C 24 08 A1 ? ? ? ? 83 C1 FF 83 F9 05 0F 87 ? ? ? ? FF 24 8D ? ? ? ? 8B 4C 24 0C "
  .. "69 C0 2C 03 00 00 8B 54 24 10 C7 01 00 00 00 00 8B 4C 24 14 C7 02 "
local AOB_SIZE = AOB_SLIDER .. "05 00 00 00"
local AOB_DELAY = AOB_SLIDER .. "C0 5D 00 00"
local SLIDER_SIZE = 9
local SLIDER_SELECTED = { 0x04, { 0xA1 } }
-- The game's button picture renderer: the picture index and the draw buffer choice.
local BUTTON_IMAGE = { 0x00, { 0x8B, 0x0D } }
local BUTTON_DRAW_CHOICE = { 0x1A, { 0xC7, 0x05 } }

-- handleMenuElementsCallbacks: the mouse (+0x10 x, +0x14 y, +0x34 left click this frame).
local AOB_MENU_ITEM = "8B 56 10 8B 46 4C 8B 4E 0C 52 8B 50 08 03 56 08 8B 40 04 03 46 04 51 52 50 B9 ? ? ? ? E8"
local MENU_ITEM_MOUSE = { 0x19, { 0xB9 } }
local MOUSE_X, MOUSE_Y, LEFT_CLICK = 0x10, 0x14, 0x34
-- ToolbarButtonPressed (found 0x1B in, improved-tunnelers jumps over its start): the click sound.
local AOB_TOOLBAR = "A1 ? ? ? ? 8B C8 69 C9 F4 39 00 00 39 99 ? ? ? ? 74 18 39 1D ?"
local TOOLBAR_PATTERN_OFFSET = 0x1B
local TOOLBAR_SOUND_ID = { 0x227, { 0x68 } }
local TOOLBAR_SOUNDS = { 0x22C, { 0xB9 } }
local TOOLBAR_PLAY_SOUND = 0x23D

-- Troop functions (the same patterns lord-hunt uses).
local AOB_ADD_TO_TRIBE = "53 8B 5C 24 08 56 57 8B 7C 24 14 8B C7 69 C0 ? ? 00 00 66 83"
local AOB_REMOVE_FROM_TRIBE = "53 55 56 8B 74 24 10 8B D9 8B CE 69 C9 90 04 00 00 66 83 B9 ? ? ? ? 00 57 8B 7C 24 18"
local AOB_CREATE_TRIBE = "53 55 8B 6C 24 0C 56 57 BF ? ? 00 00 2B FD 33 DB 3B FB 7E"
local AOB_INSTRUCTION = "83 EC 1C 8B 44 24 20 69 C0 ? ? 00 00 53 8B 5C 24 30 55 8D 2C 08 33 D2 56 0F BF 75 5C"
local AOB_STANCE = "8B 44 24 04 66 8B 54 24 08 69 C0 ? ? 00 00 66 89 94 08 ? ? 00 00 C7 05"

-- MenuItem layout (0x50 bytes) and the outpost's static size slider item, which leads to the
-- building menu's item table and its constructor.
local ITEM_SIZE, ITEM_TYPE, ITEM_ACTION, ITEM_PARAM, ITEM_IMAGE = 0x50, 0x00, 0x14, 0x18, 0x20
local ITEM_MIN, ITEM_MAX, ITEM_VALUE = 0x3C, 0x40, 0x44
local TYPE_GROUP, TYPE_LAST = 0x01000000, 0x66
local SIZE_ITEM_FROM_GROUP = 9    -- group header, eight buttons, then the size slider

---------------------------------------------------------------------------------------
-- Layouts (read from the code above where they differ between the exes)
---------------------------------------------------------------------------------------

local U = { STRIDE = 0x490, STATE = 0x8C, TYPE = 0x8E, OWNER = 0x96, UID = 0x98, X = 0xC4, Y = 0xC6,
  TILE = 0xD4, TRIBE = 0x2D8, STATE_OFFSET = 0x614 }
local T = { OWNER = 0x2C, UID = 0x34, STATE = 0x40, SIZE = 0x5C }
local B = { STRIDE = 0x32C, TYPE = 0xD2, UID = 0xD8, TRIBE_UID = 0x304, MASK = 0x300 }
local P = { STRIDE = 0x39F4, CAMP = 0x1D8, LORD = 0x21F8, LORD_UID = 0x21FC }
local LORD_TYPE = 55
local MAP_SIZE = 400

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
  return DEFAULTS[group][name]
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
  if x < 0 or y < 0 or x >= MAP_SIZE or y >= MAP_SIZE then return nil end
  return rd32(G.rows + y * 12) + x
end

local function distance(ax, ay, bx, by)
  local dx, dy = math.abs(ax - bx), math.abs(ay - by)
  return dx > dy and dx or dy
end

local function setJob(id, job)
  if id <= 0 or id >= MAX_TRIBES then return end
  wr8(G.jobs + id, job)
  wr32(G.jobUids + id * 4, job ~= 0 and rd32(tribe(id) + T.UID) or 0)
  orders[id] = nil
end

local function aliveLord(p)
  if p < 1 or p > 8 then return nil end
  local id = rd32(player(p) + P.LORD)
  if id <= 0 then return nil end
  local u = unit(id)
  if rd16(u + U.STATE) ~= 2 or rd16(u + U.TYPE) ~= LORD_TYPE then return nil end
  if rd32(u + U.UID) ~= rd32(player(p) + P.LORD_UID) then return nil end
  return { id = id, uid = rd32(u + U.UID), x = rd16(u + U.X), y = rd16(u + U.Y), tile = rd32(u + U.TILE) }
end

---------------------------------------------------------------------------------------
-- Jobs: splitting a wave when it leaves
---------------------------------------------------------------------------------------

local function newTribe(owner, units, from, kind)
  local id = F.createTribe(G.tribesThis, owner)
  if id == nil or id <= 0 or id >= MAX_TRIBES then return nil end
  for _, u in ipairs(units) do
    F.removeFromTribe(G.tribesThis, u, from)
    F.addToTribe(G.tribesThis, u, id)
  end
  F.setStance(G.tribesThis, id, STANCE_AGGRESSIVE)
  wr16(tribe(id) + G.tribeKind, kind)
  return id
end

local function onLaunch()
  local t, ai = rd32(G.launchTribe), rd32(G.launchThis)
  if t <= 0 or t >= MAX_TRIBES then return end
  local tb = tribe(t)
  if rd16(tb + T.STATE) ~= 2 then return end
  setJob(t, JOB_NONE)
  local owner = rd32(tb + T.OWNER)

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
    local plan = O.plans[kind]
    if plan == nil then
      for _, id in ipairs(list) do put(JOB_NONE, id) end
    else
      local first = (#list * plan.share + 50) // 100
      for index, id in ipairs(list) do put(index <= first and plan.first or plan.rest, id) end
    end
  end

  -- The wave's own troop keeps whatever the game handles itself (siege engines), else its
  -- largest group.
  local keeper = groups[JOB_NONE] and JOB_NONE or nil
  for job = JOB_ENGAGE, JOB_PATROL do
    if keeper == nil and groups[job] then keeper = job end
    if groups[job] and keeper ~= JOB_NONE and #groups[job] > #groups[keeper] then keeper = job end
  end
  if keeper == nil then return end

  local kind = rd16(tb + G.tribeKind)
  local made = {}
  for job = JOB_ENGAGE, JOB_PATROL do
    if groups[job] and job ~= keeper then
      local id = newTribe(owner, groups[job], t, kind)
      if id ~= nil then
        F.register(ai, id, rd32(tribe(id) + T.UID))
        setJob(id, job)
        made[#made + 1] = string.format("%d %s (troop %d)", #groups[job], JOB_NAMES[job], id)
      end
    end
  end
  setJob(t, keeper)
  diag("player %d wave (troop %d): %d %s%s", owner, t, #groups[keeper], JOB_NAMES[keeper],
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
    local x = math.floor(cx + PATROL_RADIUS * math.cos(angle) + 0.5)
    local y = math.floor(cy + PATROL_RADIUS * math.sin(angle) + 0.5)
    x = math.max(1, math.min(MAP_SIZE - 2, x))
    y = math.max(1, math.min(MAP_SIZE - 2, y))
    local tile = tileAt(x, y)
    if tile ~= nil and F.reach(ai, t, tile) ~= 0 then return x, y, step + try + 1 end
  end
  return nil
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
  if target < 1 or target > 8 or lead == nil or lead <= 0 then
    gameChoice(ai, t, nil)
    return
  end
  local lu = unit(lead)
  local ux, uy = rd16(lu + U.X), rd16(lu + U.Y)

  if job == JOB_PATROL and S.x ~= nil then
    if distance(ux, uy, S.x, S.y) > PATROL_ARRIVED and S.wait > 0 then
      S.wait = S.wait - 1
      return
    end
  elseif S.wait > 0 then
    S.wait = S.wait - 1
    return
  end

  if job == JOB_MOAT or job == JOB_WALLS then
    local moat, x, y = breach(owner, target, ux, uy)
    local tile = moat ~= nil and tileAt(x, y) or nil
    if moat and tile ~= nil then
      F.instruction(G.tribesThis, t, ORDER_DIG_MOAT, tile, 0, 0)
      S.wait = WAIT[job]
      return
    end
    if job == JOB_WALLS and moat == false then
      F.instruction(G.tribesThis, t, ORDER_ATTACK_WALL_AT, x, y, 1000)
      S.wait = WAIT[job]
      return
    end
    gameChoice(ai, t, nil)
    return
  end

  local lord = aliveLord(target)
  if job == JOB_LORD then
    if lord ~= nil and F.reach(ai, t, lord.tile) ~= 0 then
      F.instruction(G.tribesThis, t, ORDER_ATTACK_UNIT, lord.id, lord.uid, 0)
      S.wait = WAIT[job]
      return
    end
    job = JOB_PATROL            -- the lord is out of reach: ride round his castle instead
  end

  if job == JOB_PATROL then
    local cx, cy
    if lord ~= nil then
      cx, cy = lord.x, lord.y
    else
      cx, cy = rd32(player(target) + P.CAMP), rd32(player(target) + P.CAMP + 4)
    end
    local x, y, step = patrolPoint(ai, t, cx, cy, S.step)
    if x ~= nil then
      F.command(G.tribesThis, t, x, y, 1)
      S.x, S.y, S.step, S.wait = x, y, step, WAIT[JOB_PATROL]
      return
    end
    gameChoice(ai, t, nil)
    return
  end

  gameChoice(ai, t, nil)
end

---------------------------------------------------------------------------------------
-- The outpost panel: switching the page refreshes the two sliders
---------------------------------------------------------------------------------------

local function refreshSliders()
  if G.menu == nil then return end
  local item, limit = rd32(G.menu), 4000
  if item == 0 then return end
  while rd32(item + ITEM_TYPE) ~= TYPE_LAST and limit > 0 do
    local action = rd32(item + ITEM_ACTION)
    if action == G.sizeSlider or action == G.delaySlider then
      F.slider(action, rd32(item + ITEM_PARAM), 1, item + ITEM_MIN, item + ITEM_MAX, item + ITEM_VALUE)
    end
    item = item + ITEM_SIZE
    limit = limit - 1
  end
end

---------------------------------------------------------------------------------------
-- The save: per outpost settings and the troops' jobs
---------------------------------------------------------------------------------------

local function wipe()
  core.setMemory(G.table, 0, MAX_BUILDINGS * 8)
  core.setMemory(G.jobs, 0, MAX_TRIBES)
  core.setMemory(G.jobUids, 0, MAX_TRIBES * 4)
  orders = {}
end

local function isOutpost(id)
  local kind = rd16(building(id) + B.TYPE)
  return kind == OUTPOST_EURO or kind == OUTPOST_ARAB
end

local function serialize(handle)
  local entries = {}
  for id = 1, MAX_BUILDINGS - 1 do
    local entry = G.table + id * 8
    local uid = rd32(entry)
    if uid ~= 0 and uid == rd32(building(id) + B.UID) then
      entries[#entries + 1] = string.pack("<I2I4I2BB", id, uid, rd16(entry + 4) & 0xFFFF, rd8(entry + 6) & 0xFF,
        rd8(entry + 7) & 0xFF)
    end
  end
  handle:put(SAVE_BUILDINGS, table.concat(entries))
  local jobs = {}
  for id = 1, MAX_TRIBES - 1 do
    local job = rd8(G.jobs + id) & 0xFF
    local uid = rd32(G.jobUids + id * 4)
    if job ~= 0 and uid ~= 0 and uid == rd32(tribe(id) + T.UID) then
      jobs[#jobs + 1] = string.pack("<I2I4B", id, uid, job)
    end
  end
  handle:put(SAVE_JOBS, table.concat(jobs))
end

local function deserialize(handle)
  wipe()
  if handle:exists(SAVE_BUILDINGS) then
    local data = handle:get(SAVE_BUILDINGS)
    local size = string.packsize("<I2I4I2BB")
    for offset = 1, #data - size + 1, size do
      local id, _, mask, defenders, growth = string.unpack("<I2I4I2BB", data, offset)
      if id > 0 and id < MAX_BUILDINGS and isOutpost(id) then
        local entry = G.table + id * 8
        wr32(entry, rd32(building(id) + B.UID))
        wr16(entry + 4, mask)
        wr8(entry + 6, math.min(defenders, MAX_DEFENDERS))
        wr8(entry + 7, math.min(growth, 100))
      end
    end
  end
  if handle:exists(SAVE_JOBS) then
    local data = handle:get(SAVE_JOBS)
    local size = string.packsize("<I2I4B")
    for offset = 1, #data - size + 1, size do
      local id, uid, job = string.unpack("<I2I4B", data, offset)
      if id > 0 and id < MAX_TRIBES and job <= JOB_PATROL and uid == rd32(tribe(id) + T.UID) then
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

local function resolve()
  local count = scan(AOB_DEFENDER_COUNT, "where an outpost checks its defender count")
  G.defenderCount = count
  G.defendersField = readOperand(count, { 0x00, { 0x80, 0xB9 } }, "the defender count")
  G.buildings = G.defendersField - DEFENDER_COUNT_FIELD
  G.roll = readJumpTarget(count + 7, "the defender roll")
  expectBytes(count + 0x1C, { 0x66, 0x85, 0xC0 }, "the defender timer")
  G.skip = readJumpTarget(count + 0x1F, "the end of the defender part")

  G.defenderType = scan(AOB_DEFENDER_TYPE, "where an outpost picks its defenders")
  same(readOperand(G.defenderType, { 0x00, { 0x66, 0x83, 0xB9 } }, "the outpost type"), G.buildings + B.TYPE,
    "the building array")

  G.growth = scan(AOB_GROWTH, "where an outpost speeds up after a wave")
  same(readOperand(G.growth, { 0x00, { 0x66, 0x83, 0x80 } }, "the wave counter"), G.buildings + WAVES_FIELD,
    "the wave counter")
  same(readOperand(G.growth, { 0x08, { 0x66, 0x83, 0x80 } }, "the unit pace"), G.buildings + PACE_FIELD,
    "the unit pace")

  local launch = scan(AOB_LAUNCH, "where an outpost sends its wave")
  same(readOperand(launch, { 0x00, { 0x8B, 0x80 } }, "the wave troop"), G.buildings + B.TRIBE_UID, "the wave troop")
  G.aiState = readOperand(launch, LAUNCH_AI, "the AI state")
  G.launchSite = launch + LAUNCH_CALL
  G.register = readCallTarget(launch, LAUNCH_CALL, "aiRegisterTribeAndAssignTarget")
  G.current = readOperand(launch, LAUNCH_CURRENT, "the current building")

  local make = scan(AOB_MAKE, "the outpost troops' update")
  G.tribeStride = readOperand(make, MAKE_STRIDE, "the troop size")
  G.decideSite = make + MAKE_CALL
  G.decide = readCallTarget(make, MAKE_CALL, "decideOnTribeAttackLocation")
  same(scan(AOB_DECIDE, "decideOnTribeAttackLocation"), G.decide, "decideOnTribeAttackLocation")
  local d = G.decide
  G.tribesThis = readOperand(d, DECIDE_TRIBES, "the troop array")
  G.tribes = G.tribesThis
  same(readOperand(make, MAKE_UID, "the troop uid"), G.tribes + T.UID, "the troop array")
  G.tribeTarget = readOperand(d, DECIDE_TARGET, "the troop's target player") - G.tribes
  G.tribeKind = readOperand(d, DECIDE_KIND, "the troop's kind") - G.tribes
  same(readOperand(d, DECIDE_OWNER, "the troop owner"), G.tribes + T.OWNER, "the troop owner")
  G.units = readOperand(d, DECIDE_UNIT_Y, "the unit array") - U.Y
  G.unitsThis = readOperand(d, DECIDE_UNITS_THIS, "the unit state")
  same(G.unitsThis, G.units - U.STATE_OFFSET, "the unit array")
  G.paths = readOperand(d, DECIDE_PATHS, "the path finder")
  G.rows = readOperand(d, DECIDE_ROWS, "the map rows")
  same(readOperand(d, DECIDE_BUILDING_UID, "the building uid"), G.buildings + B.UID, "the building array")
  G.players = readOperand(d, DECIDE_CAMP, "the player array") - P.CAMP

  F.busy = core.exposeCode(readCallTarget(d, DECIDE_BUSY, "checkTribeActivityPercentages"), 4, 1)
  F.lead = core.exposeCode(readCallTarget(d, DECIDE_LEAD, "getUnitIDForIndexInTribe"), 3, 1)
  F.path = core.exposeCode(readCallTarget(d, DECIDE_PATH, "pathFindingToAttackCastleIncludingMoat"), 8, 1)
  local relay = readCallTarget(d, DECIDE_RELAY, "relayTribeInstruction")
  F.reach = core.exposeCode(readCallTarget(d, DECIDE_REACH, "canNavigateUnitsFromTileToTargetTile"), 3, 1)
  F.command = core.exposeCode(readCallTarget(d, DECIDE_COMMAND, "commandUnitsToLocation"), 5, 1)
  F.decide = core.exposeCode(G.decide, 2, 1)
  F.register = core.exposeCode(G.register, 3, 1)

  local instruction = scan(AOB_INSTRUCTION, "giveTribeAnInstruction")
  expectBytes(relay, { 0xB9 }, "relayTribeInstruction")
  same(relay + 10 + rd32(relay + 6), instruction, "giveTribeAnInstruction")
  F.instruction = core.exposeCode(instruction, 6, 1)
  F.createTribe = core.exposeCode(scan(AOB_CREATE_TRIBE, "createTribeForPlayer"), 2, 1)
  F.addToTribe = core.exposeCode(scan(AOB_ADD_TO_TRIBE, "addUnitToTribe"), 3, 1)
  F.removeFromTribe = core.exposeCode(scan(AOB_REMOVE_FROM_TRIBE, "removeUnitFromTribe"), 3, 1)
  F.setStance = core.exposeCode(scan(AOB_STANCE, "setUnitStance"), 3, 1)
end

local function resolvePanel()
  local panel = scan(AOB_PANEL, "the outpost panel")
  G.panel = panel
  G.selected = readOperand(panel, PANEL_SELECTED, "the selected building")
  same(readOperand(panel, PANEL_TYPE, "the outpost type"), G.buildings + B.TYPE, "the building array")
  G.menuY = readOperand(panel, PANEL_MENU_Y, "the panel position")
  G.menuX = readOperand(panel, PANEL_MENU_X, "the panel position")
  G.textManager = readOperand(panel, PANEL_TEXT_MANAGER, "the text manager")
  G.renderText = readCallTarget(panel, PANEL_RENDER_TEXT, "renderTextToScreen")

  local render = scan(AOB_BUTTON_RENDER, "the outpost's troop buttons")
  G.buttonRender = render
  same(readOperand(render, RENDER_SELECTED, "the selected building"), G.selected, "the selected building")
  same(readOperand(render, RENDER_MASK, "the troop buttons"), G.buildings + B.MASK, "the troop buttons")
  G.hover = readOperand(render, RENDER_HOVER, "the button hover flag")
  G.button = readCallTarget(render, RENDER_BUTTON, "the button renderer")
  G.buttonX = readOperand(render, RENDER_X, "the button place")
  same(readOperand(render, RENDER_Y, "the button place"), G.buttonX + 4, "the button place")
  same(readOperand(render, RENDER_W, "the button place"), G.buttonX + 8, "the button place")
  same(readOperand(render, RENDER_TEXT_MANAGER, "the text manager"), G.textManager, "the text manager")
  G.shadowText = readCallTarget(render, RENDER_SHADOW_TEXT, "renderInGameTextWithShadow")
  G.buttonImage = readOperand(G.button, BUTTON_IMAGE, "the button picture")
  G.drawChoice = readOperand(G.button, BUTTON_DRAW_CHOICE, "the draw buffer")

  G.buttonClick = scan(AOB_BUTTON_CLICK, "the outpost's troop button click")
  same(readOperand(G.buttonClick, { 0x00, { 0xA1 } }, "the selected building"), G.selected, "the selected building")
  G.sizeSlider = scan(AOB_SIZE, "the outpost's size slider")
  G.delaySlider = scan(AOB_DELAY, "the outpost's start delay slider")
  same(readOperand(G.sizeSlider, SLIDER_SELECTED, "the selected building"), G.selected, "the selected building")
  same(readOperand(G.delaySlider, SLIDER_SELECTED, "the selected building"), G.selected, "the selected building")

  local menuItem = scan(AOB_MENU_ITEM, "the menu item handler")
  G.mouse = readOperand(menuItem, MENU_ITEM_MOUSE, "the mouse")
  local toolbar = scan(AOB_TOOLBAR, "the toolbar key handler") - TOOLBAR_PATTERN_OFFSET
  G.clickSound = readOperand(toolbar, TOOLBAR_SOUND_ID, "the click sound")
  G.sounds = readOperand(toolbar, TOOLBAR_SOUNDS, "the sound player")
  G.playSound = readCallTarget(toolbar, TOOLBAR_PLAY_SOUND, "the sound player")

  -- The static size slider item: its group's picture, the menu's item table and the menu.
  local pattern = {}
  for _, value in ipairs({ 5, 130, 510, 104, 26, G.sizeSlider }) do
    for _, byte in ipairs(core.itob(value)) do pattern[#pattern + 1] = string.format("%02X", byte & 0xFF) end
  end
  local sizeItem = scan(table.concat(pattern, " "), "the outpost's size slider item")
  local header = sizeItem - SIZE_ITEM_FROM_GROUP * ITEM_SIZE
  if rd32(header + ITEM_TYPE) ~= TYPE_GROUP then
    error(MODULE_NAME .. ": the outpost menu is not the one this module knows")
  end
  same(rd32(header + ITEM_SIZE + ITEM_IMAGE), TEXT_BUTTON, "the outpost's button picture")
  local start, limit = header, 400
  while rd32(start - ITEM_SIZE + ITEM_TYPE) ~= TYPE_LAST and limit > 0 do
    start = start - ITEM_SIZE
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
  F.sliders = {
    [G.sizeSlider] = core.exposeCode(G.sizeSlider, 5, 0),
    [G.delaySlider] = core.exposeCode(G.delaySlider, 5, 0),
  }
  F.slider = function(action, ...) return F.sliders[action](...) end
end

local function allocate()
  G.table = core.allocate(MAX_BUILDINGS * 8, true)
  G.jobs = core.allocate(MAX_TRIBES, true)
  G.jobUids = core.allocate(MAX_TRIBES * 4, true)
  G.mode = core.allocate(4, true)
  G.launchTribe = core.allocate(4, true)
  G.launchThis = core.allocate(4, true)
  G.decideTribe = core.allocate(4, true)
  G.decideThis = core.allocate(4, true)
  G.scratch = core.allocate(16, true)
  G.defenderTypes = core.allocate(16, true)
  for index, kind in ipairs(DEFENDER_TYPES) do wr8(G.defenderTypes + index - 1, kind) end
  G.defenderNames = core.allocate(16 * 4, true)
  for index, name in ipairs(DEFENDER_NAMES) do wr32(G.defenderNames + (index - 1) * 4, cString(name)) end
  G.pageTexts = core.allocate(2 * 4, true)
  for index, name in ipairs(PAGE_NAMES) do wr32(G.pageTexts + (index - 1) * 4, cString(name)) end
  G.labelPlaces = core.allocate(#LABELS * 8, true)
  G.labelTexts = core.allocate(#LABELS * 4, true)
  for index, label in ipairs(LABELS) do
    wr32(G.labelPlaces + (index - 1) * 8, label[1])
    wr32(G.labelPlaces + (index - 1) * 8 + 4, label[2])
    wr32(G.labelTexts + (index - 1) * 4, cString(label[3]))
  end
end

local function install(self)
  local values = {
    MAX_BUILDINGS = MAX_BUILDINGS, MAX_TRIBES = MAX_TRIBES, B_STRIDE = B.STRIDE,
    B_UID = G.buildings + B.UID, B_TYPE = G.buildings + B.TYPE, B_DEFENDERS = G.defendersField,
    B_WAVES = G.buildings + WAVES_FIELD, B_PACE = G.buildings + PACE_FIELD,
    TABLE = G.table, MAX_DEFENDERS = MAX_DEFENDERS, USUAL_DEFENDERS = USUAL_DEFENDERS,
    CURRENT_BUILDING = G.current, ARAB_OUTPOST = OUTPOST_ARAB, EURO_ARCHER = EURO_ARCHER,
    ARAB_ARCHER = ARAB_ARCHER, DEFENDER_TYPES = G.defenderTypes,
  }
  self.saved = {}
  local function keep(address, size)
    self.saved[#self.saved + 1] = { address = address, bytes = core.readBytes(address, size) }
  end

  values.ENTRY_GET = assemble(templates.entryGet, values)
  values.ENTRY_MAKE = assemble(templates.entryMake, values)

  if O.defenders then
    keep(G.defenderCount, DEFENDER_COUNT_SIZE)
    values.SKIP, values.ROLL, values.RESUME = G.skip, G.roll, G.defenderCount + DEFENDER_COUNT_SIZE
    jumpTo(G.defenderCount, assemble(templates.defenderCount, values), DEFENDER_COUNT_SIZE)
    keep(G.defenderType, DEFENDER_TYPE_SIZE)
    values.RESUME = G.defenderType + DEFENDER_TYPE_SIZE
    jumpTo(G.defenderType, assemble(templates.defenderType, values), DEFENDER_TYPE_SIZE)
  end

  if O.growth then
    keep(G.growth, GROWTH_SIZE)
    values.RESUME = G.growth + GROWTH_SIZE
    jumpTo(G.growth, assemble(templates.growth, values), GROWTH_SIZE)
  end

  if O.jobs then
    values.LAUNCH_TRIBE, values.LAUNCH_THIS, values.REGISTER = G.launchTribe, G.launchThis, G.register
    values.PAD = pad(onLaunch, "splitting waves")
    keep(G.launchSite, 5)
    callTo(G.launchSite, assemble(templates.launch, values))

    values.JOBS, values.JOB_UIDS, values.TRIBE_STRIDE = G.jobs, G.jobUids, G.tribeStride
    values.TRIBE_UID, values.TRIBE_KIND = G.tribes + T.UID, G.tribes + G.tribeKind
    values.JOB_ENGAGE, values.JOB_BUILDINGS = JOB_ENGAGE, JOB_BUILDINGS
    values.KIND_RANGED, values.KIND_MELEE = KIND_RANGED, KIND_MELEE
    values.DECIDE_TRIBE, values.DECIDE_THIS, values.DECIDE = G.decideTribe, G.decideThis, G.decide
    values.PAD = pad(onDecide, "outpost troop orders")
    keep(G.decideSite, 5)
    callTo(G.decideSite, assemble(templates.decide, values))
  end

  if O.defenders or O.growth then
    values.MODE, values.SELECTED = G.mode, G.selected
    values.MENU_X, values.MENU_Y = G.menuX, G.menuY
    values.TEXT_MANAGER, values.RENDER_TEXT, values.SHADOW_TEXT = G.textManager, G.renderText, G.shadowText
    values.LABEL_PLACES, values.LABEL_TEXTS, values.PAGE_TEXTS = G.labelPlaces, G.labelTexts, G.pageTexts
    values.DEFENDER_NAMES = G.defenderNames
    values.MOUSE, values.MOUSE_X, values.MOUSE_Y, values.LEFT_CLICK = G.mouse, MOUSE_X, MOUSE_Y, LEFT_CLICK
    values.CLICK_SOUND, values.SOUNDS, values.PLAY_SOUND = G.clickSound, G.sounds, G.playSound
    values.BUTTON_X, values.BUTTON_HOVER, values.BUTTON_IMAGE = G.buttonX, G.hover, G.buttonImage
    values.DRAW_CHOICE, values.BUTTON_RENDER, values.TEXT_BUTTON = G.drawChoice, G.button, TEXT_BUTTON
    values.TOGGLE_X, values.TOGGLE_Y, values.TOGGLE_W, values.TOGGLE_H = TOGGLE_X, TOGGLE_Y, TOGGLE_W, TOGGLE_H
    values.TOGGLE_HALF = TOGGLE_W // 2
    values.PAD = pad(refreshSliders, "the outpost panel")
    values.LABELS = assemble(templates.labels, values)
    values.TOGGLE = assemble(templates.toggle, values)

    keep(G.panel, 5)
    values.RESUME = G.panel + 5
    jumpTo(G.panel, assemble(templates.panel, values), 5)
    keep(G.buttonRender, BUTTON_RENDER_SIZE)
    values.RESUME = G.buttonRender + BUTTON_RENDER_SIZE
    jumpTo(G.buttonRender, assemble(templates.buttonRender, values), BUTTON_RENDER_SIZE)
    keep(G.buttonClick, BUTTON_CLICK_SIZE)
    values.RESUME = G.buttonClick + BUTTON_CLICK_SIZE
    jumpTo(G.buttonClick, assemble(templates.buttonClick, values), BUTTON_CLICK_SIZE)

    keep(G.sizeSlider, SLIDER_SIZE)
    values.RESUME, values.FIELD, values.TOP, values.STEP, values.SYNC = G.sizeSlider + SLIDER_SIZE, 6,
      MAX_DEFENDERS, 1, 1
    jumpTo(G.sizeSlider, assemble(templates.slider, values), SLIDER_SIZE)
    keep(G.delaySlider, SLIDER_SIZE)
    values.RESUME, values.FIELD, values.TOP, values.STEP, values.SYNC = G.delaySlider + SLIDER_SIZE, 7, 100,
      GROWTH_STEP, 0
    jumpTo(G.delaySlider, assemble(templates.slider, values), SLIDER_SIZE)
  end
end

local function enable(self, config)
  config = config or {}
  O.defenders = setting(config, "defenders", "enabled") == true
  O.growth = setting(config, "growth", "enabled") == true
  O.jobs = setting(config, "jobs", "enabled") == true
  O.log = setting(config, "diagnostics", "log") == true
  O.plans = {}
  for _, plan in ipairs(PLANS) do
    O.plans[plan.kind] = { first = plan.first, rest = plan.rest, share = percent(setting(config, "jobs", plan.name)) }
  end
  if not O.defenders and not O.growth and not O.jobs then
    log(INFO, MODULE_NAME .. ": every part is off")
    return
  end

  local ok, problem = pcall(function()
    resolve()
    if O.defenders or O.growth then resolvePanel() end
    allocate()
  end)
  if not ok then
    log(WARNING, tostring(problem))
    return
  end

  modules["map-extensions"]:registerSection(SAVE_SECTION, {
    initialize = function(_) wipe() end,
    serialize = function(_, handle) serialize(handle) end,
    deserialize = function(_, handle) deserialize(handle) end,
  })

  install(self)
  log(INFO, string.format("%s: on (defenders %s, growth %s, jobs %s); buildings 0x%X, troops 0x%X (size 0x%X), "
    .. "units 0x%X", MODULE_NAME, O.defenders and "on" or "off", O.growth and "on" or "off",
    O.jobs and "on" or "off", G.buildings, G.tribes, G.tribeStride, G.units))
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
