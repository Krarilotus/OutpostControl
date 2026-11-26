# Outpost Control

A UCP3 module for Stronghold Crusader (Extreme and vanilla) that gives map makers a Defenders
page in the outpost panel (which troops guard an outpost, up to 50), a Growth slider on its
Attackers page (how fast its waves speed up) and
splits each outpost wave into troops with jobs by unit type (fill the moat, attack walls and
gates, burn buildings, fight troops, ride round the castle, hunt the lord). Per-outpost settings
and jobs are stored in maps and saves through `map-extensions`. Player-facing description:
[module/locale/description-en.md](module/locale/description-en.md).

## What is in here

| Path | What |
| --- | --- |
| `module/` | the module (source of truth) |
| `tools/publish.py` | copy `module/` to `<game>\ucp\modules\outpost-control-<version>` (`--bump`, `--keep`) |
| `tools/check_resolve.py` | runs `enable()` on both exe images: every AOB unique, every operand check, dumps the asm |
| `tools/fasm_all.ps1` | assembles the dumped scripts with UCP's fasm.dll (run with 32-bit PowerShell) |

## Working on it

1. Edit `module/`.
2. `python tools/check_resolve.py`, then the 32-bit PowerShell on `tools/fasm_all.ps1`.
3. Game closed: `python tools/publish.py --bump`, F5 and apply in the UCP3 GUI.

## How it works

* `UpdateOutpostBuilding`: the defender count test (skip the defender part at 0), the defender
  check (an outpost with settings counts its guards in its own 50-slot list, waits 9600/amount
  ticks, and keeps new guards in that list instead of the game's 8 slots), the defender
  type (`mov edx,0x16/0x46` -> the picked troops, taking turns by the number alive), and the
  post-wave speed-up (`+100` wave counter, `+4` unit pace -> `+growth`, pace = counter / 25).
* The wave's `aiRegisterTribeAndAssignTarget` call -> lua splits the troop by unit type into new
  troops (`createTribeForPlayer`, `addUnitToTribe`...), each registered the same way.
* `makeOutpostTribesAttack`'s call of `decideOnTribeAttackLocation`: job troops "fight troops" /
  "attack buildings" get the game's ranged / melee branch by their kind field; moat, walls, lord
  and patrol jobs are decided in lua with the game's path-to-castle search and tribe orders.
* Outpost panel: prologue hooks on the panel text, the troop button render/click and the size
  slider handler; a page button drawn with the game's button renderer over the title. With
  growth on, the size and start delay slider items move up (y 494/530) and a growth slider is
  drawn below (y 566) with the game's slider renderer, dragged by its own mouse test; the start
  delay item is hidden (item +0x36) on the Defenders page.
* Per-building entries (uid, troop bits, amount, growth) and the job table go into the
  `outpost-control` map-extensions section.

## Vanilla and Recommended

Every option of the module is off by default, so the module alone plays like the original
game. Two plugins in this repository form the Outpost Control family in the launcher:
`outpost-control-recommended` (offered first) switches on the recommended settings, `outpost-control-vanilla`
keeps everything off. Plugins that build on the module set the options they need themselves.
