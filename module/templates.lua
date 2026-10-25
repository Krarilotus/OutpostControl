-- Injected code. Every script is assembled on its own (fasm has a small fixed buffer), and
-- the scripts reach each other by address. Building entries are 8 bytes, one per building id:
-- +0 the building's uid (the entry only counts while it matches), +4 the defender troop
-- buttons (bit per button), +6 the number of defenders, +7 the growth in percent.

local templates = {}

-- eax = building id -> eax = its entry, or 0 when it has none. Changes edx.
templates.entryGet = [[
cmp eax,MAX_BUILDINGS
jae none
mov edx,eax
imul edx,edx,B_STRIDE
mov edx,[edx+B_UID]
shl eax,3
add eax,TABLE
test edx,edx
jz none
cmp edx,[eax]
jne none
ret
none:
xor eax,eax
ret
]]

-- eax = building id -> eax = its entry, made with the game's own values if it had none (0 for
-- a bad id), its guard list emptied. Changes edx.
templates.entryMake = [[
push ecx
push ebx
mov ecx,eax
call ENTRY_GET
test eax,eax
jnz done
cmp ecx,MAX_BUILDINGS
jae done
mov edx,ecx
imul edx,edx,B_STRIDE
mov ebx,[edx+B_UID]
xor eax,eax
test ebx,ebx
jz done
push edi
push ecx
mov eax,ecx
imul eax,eax,SLOT_BYTES
lea edi,[SLOTS+eax]
mov ecx,SLOT_DWORDS
xor eax,eax
rep stosd
pop ecx
pop edi
mov eax,ecx
shl eax,3
add eax,TABLE
mov [eax],ebx
mov word [eax+4],1
movsx ebx,byte [edx+B_DEFENDERS]
cmp ebx,1
jl usual
cmp ebx,MAX_DEFENDERS
jle keep
usual:
mov ebx,USUAL_DEFENDERS
keep:
mov [eax+6],bl
mov byte [eax+7],100
done:
pop ebx
pop ecx
ret
]]

-- UpdateOutpostBuilding, where it asks whether the defender count is set yet (cmp/jle, 13
-- bytes). An outpost set to no defenders skips the defender part.
templates.defenderCount = [[
push edx
mov eax,[CURRENT_BUILDING]
call ENTRY_GET
pop edx
test eax,eax
jz usual
cmp byte [eax+6],0
jne usual
jmp SKIP
usual:
cmp byte [ecx+B_DEFENDERS],0
jle ROLL
jmp RESUME
]]

-- UpdateOutpostBuilding, every defender check (mov word [ecx+timer],1200, 9 bytes, eax and edi
-- in use). An outpost with an entry counts its guards in its own list of MAX_GUARDS, waits
-- GUARD_PACE / amount ticks between guards (so a full refill takes as long as the game's 8)
-- and goes on to pick the guard's type, or skips the defender part when it has enough.
templates.guardCount = [[
push eax
push edx
mov eax,[CURRENT_BUILDING]
call ENTRY_GET
pop edx
test eax,eax
jz usual
add esp,4
push ebx
push edi
movzx ebx,byte [eax+6]
test ebx,ebx
jnz wanted
inc ebx
wanted:
mov eax,[CURRENT_BUILDING]
imul eax,eax,SLOT_BYTES
lea edi,[SLOTS+eax]
xor esi,esi
mov edx,MAX_GUARDS
alive:
movzx eax,word [edi]
test eax,eax
jz next_slot
imul eax,eax,U_STRIDE
mov eax,[eax+U_UID]
cmp eax,[edi+4]
jne next_slot
inc esi
next_slot:
add edi,8
dec edx
jnz alive
mov eax,GUARD_PACE
xor edx,edx
div ebx
cmp eax,LONGEST_WAIT
jbe short_enough
mov eax,LONGEST_WAIT
short_enough:
cmp eax,SHORTEST_WAIT
jae long_enough
mov eax,SHORTEST_WAIT
long_enough:
mov word [ecx+B_TIMER],ax
cmp esi,ebx
pop edi
pop ebx
jge SKIP
jmp PICK
usual:
pop eax
mov word [ecx+B_TIMER],LONGEST_WAIT
jmp RESUME
]]

-- UpdateOutpostBuilding, where it puts a new guard in a free slot (mov ebp,[current], 6 bytes;
-- ebx = the unit). An outpost with an entry keeps it in its own list instead, and lua puts the
-- guard in its outpost's troop for its stance.
templates.guardRecord = [[
push eax
push edx
mov eax,[CURRENT_BUILDING]
call ENTRY_GET
test eax,eax
jz usual
push esi
push ecx
mov eax,[CURRENT_BUILDING]
imul eax,eax,SLOT_BYTES
lea esi,[SLOTS+eax]
mov ecx,MAX_GUARDS
find_slot:
movzx eax,word [esi]
test eax,eax
jz take
imul eax,eax,U_STRIDE
mov eax,[eax+U_UID]
cmp eax,[esi+4]
jne take
add esi,8
dec ecx
jnz find_slot
jmp recorded
take:
mov [esi],bx
mov eax,ebx
imul eax,eax,U_STRIDE
mov eax,[eax+U_UID]
mov [esi+4],eax
recorded:
mov [GUARD_UNIT],ebx
pushad
call PAD
popad
pop ecx
pop esi
pop edx
pop eax
jmp DONE
usual:
pop edx
pop eax
mov ebp,[CURRENT_BUILDING]
jmp RESUME
]]

-- UpdateOutpostBuilding, where it picks the defender's unit type (20 bytes, edx = the type).
-- esi = how many defenders are alive, so the picked troops take turns.
templates.defenderType = [[
mov eax,[CURRENT_BUILDING]
push edx
call ENTRY_GET
pop edx
test eax,eax
jz usual
movzx eax,word [eax+4]
and eax,0xFF
jz usual
push ebx
push edi
xor ebx,ebx
mov edx,eax
count:
test edx,edx
jz counted
mov edi,edx
and edi,1
add ebx,edi
shr edx,1
jmp count
counted:
push eax
mov eax,esi
xor edx,edx
div ebx
pop eax
xor edi,edi
find:
bt eax,edi
jnc next
test edx,edx
jz found
dec edx
next:
inc edi
cmp edi,8
jb find
xor edi,edi
found:
cmp word [ecx+B_TYPE],ARAB_OUTPOST
jne euro
add edi,8
euro:
movzx edx,byte [DEFENDER_TYPES+edi]
pop edi
pop ebx
jmp RESUME
usual:
mov edx,EURO_ARCHER
cmp word [ecx+B_TYPE],ARAB_OUTPOST
jne go
mov edx,ARAB_ARCHER
go:
jmp RESUME
]]

-- UpdateOutpostBuilding, after a wave has left (16 bytes, eax = building id * stride). The
-- game shortens the wave wait by 100 and the unit wait by 4 each time; this scales both.
templates.growth = [[
push ecx
push edx
mov ecx,eax
mov eax,[CURRENT_BUILDING]
call ENTRY_GET
mov edx,100
test eax,eax
jz grow
movzx edx,byte [eax+7]
grow:
add word [ecx+B_WAVES],dx
movzx eax,word [ecx+B_WAVES]
xor edx,edx
push ecx
mov ecx,25
div ecx
pop ecx
mov word [ecx+B_PACE],ax
mov eax,ecx
pop edx
pop ecx
jmp RESUME
]]

-- Replaces UpdateOutpostBuilding's call of aiRegisterTribeAndAssignTarget(tribe, uid): the
-- wave is sent as before, then lua splits it into jobs.
templates.launch = [[
mov eax,[esp+4]
mov [LAUNCH_TRIBE],eax
mov [LAUNCH_THIS],ecx
push dword [esp+8]
push dword [esp+8]
call REGISTER
call PAD
ret 8
]]

-- Replaces makeOutpostTribesAttack's call of decideOnTribeAttackLocation(tribe). Troops
-- with a job "fight troops" or "attack buildings" take the game's own ranged or melee choice;
-- the others are lua's.
templates.decide = [[
mov eax,[esp+4]
cmp eax,MAX_TRIBES
jae original
movzx edx,byte [JOBS+eax]
test edx,edx
jz original
push ecx
mov ecx,eax
imul ecx,ecx,TRIBE_STRIDE
mov ecx,[ecx+TRIBE_UID]
cmp ecx,[JOB_UIDS+eax*4]
pop ecx
jne original
cmp edx,JOB_ENGAGE
jne not_engage
imul eax,eax,TRIBE_STRIDE
mov word [eax+TRIBE_KIND],KIND_RANGED
jmp original
not_engage:
cmp edx,JOB_BUILDINGS
jne own
imul eax,eax,TRIBE_STRIDE
mov word [eax+TRIBE_KIND],KIND_MELEE
jmp original
own:
mov [DECIDE_TRIBE],eax
mov [DECIDE_THIS],ecx
call PAD
ret 4
original:
jmp DECIDE
]]

-- Put in the unit update table for the siege engine types: every 16 ticks (staggered by unit)
-- an outpost unit standing (state 0), walking (1 or 0x65 - siege engines use both) or creeping
-- forward in the AI's siege steps (9) goes to lua, which may set it shooting. Then whatever update function the table held runs, by the unit's type.
templates.siegeCheck = [[
mov eax,[CURRENT_UNIT]
mov edx,[TICKS]
add edx,eax
test edx,SIEGE_EVERY
jnz go
imul ecx,eax,U_STRIDE
cmp word [ecx+U_BEHAVIOUR],OUTPOST_BEHAVIOUR
jne go
movzx edx,word [ecx+U_ACTION]
test edx,edx
jz check
cmp edx,STATE_WALKING
je check
cmp edx,STATE_MOVING
je check
cmp edx,STATE_CREEPING
jne go
check:
mov [SIEGE_UNIT],eax
pushad
call PAD
popad
go:
mov eax,[CURRENT_UNIT]
imul eax,eax,U_STRIDE
movsx eax,word [eax+U_TYPE]
jmp dword [ORIGINAL_UPDATES+eax*4]
]]

-- The outpost panel's text (prologue: mov eax,[selected], 5 bytes). With growth on, the
-- attacker page gets its own labels for the moved sliders and the growth slider; the defender
-- page always has its own labels. Then the page button, when there is a defender page.
templates.panel = [[
cmp dword [MODE],0
jne own
if GROWTH_ON <> 0
call ATTACK_LABELS
call GROWTH_SLIDER
else
call usual
end if
call NUMBERS
if TOGGLE_ON <> 0
jmp TOGGLE
else
ret
end if
usual:
mov eax,[SELECTED]
jmp RESUME
own:
if TOGGLE_ON <> 0
call DEFENDER_LABELS
call NUMBERS
jmp TOGGLE
else
ret
end if
]]

-- Each slider's value, right of it: size as set, start delay in seconds at normal speed, growth
-- in percent; on the defender page the amount of guards.
templates.numbers = [[
push ebx
push esi
mov esi,[SELECTED]
cmp dword [MODE],0
jne defenders
imul esi,esi,B_STRIDE
movsx eax,word [esi+B_SIZE]
xor ecx,ecx
mov ebx,SIZE_ROW
call show
movsx eax,word [esi+B_DELAY]
cmp eax,0
jge delay_ok
xor eax,eax
delay_ok:
xor edx,edx
mov ecx,TICKS_PER_SECOND
div ecx
mov ecx,'s'
mov ebx,DELAY_ROW
call show
if GROWTH_ON <> 0
mov eax,[SELECTED]
call ENTRY_GET
mov edx,100
test eax,eax
jz growth_known
movzx edx,byte [eax+7]
growth_known:
mov eax,edx
mov ecx,'%'
mov ebx,GROWTH_ROW
call show
end if
jmp done
defenders:
if TOGGLE_ON <> 0
mov eax,esi
call ENTRY_MAKE
test eax,eax
jz done
movzx eax,byte [eax+6]
xor ecx,ecx
mov ebx,SIZE_ROW
call show
end if
done:
pop esi
pop ebx
ret
show:
push edi
mov edi,NUMBER_TEXT+15
mov byte [edi],0
test ecx,ecx
jz digits
dec edi
mov [edi],cl
digits:
mov ecx,10
digit:
xor edx,edx
div ecx
add dl,'0'
dec edi
mov [edi],dl
test eax,eax
jnz digit
push 0
push 0
push 0x12
push 0
push 0
mov eax,[MENU_Y]
add eax,ebx
push eax
mov eax,[MENU_X]
add eax,NUMBER_X
push eax
push edi
mov ecx,TEXT_MANAGER
call RENDER_TEXT
pop edi
ret
]]

-- Slider labels: LABEL_COUNT entries of x, y (from the panel), text, game text id (used when
-- the text is 0, group 0x40, so the game's own words stay in its language).
templates.labels = [[
push ebx
push esi
mov esi,LABEL_TABLE
mov ebx,LABEL_COUNT
again:
mov eax,[esi+8]
test eax,eax
jnz have_text
push dword [esi+12]
push 0x40
mov ecx,TEXT_MANAGER
call GET_TEXT
have_text:
push 0
push 0
push 0x12
push 0
push 0
mov ecx,[MENU_Y]
add ecx,[esi+4]
push ecx
mov ecx,[MENU_X]
add ecx,[esi]
push ecx
push eax
mov ecx,TEXT_MANAGER
call RENDER_TEXT
add esi,16
dec ebx
jnz again
pop esi
pop ebx
ret
]]

-- The growth slider on the attacker page, drawn by the game's slider renderer. A left click on
-- it starts a drag that lasts while the button is held; the value is 0 to 100.
templates.growthSlider = [[
push ebx
push esi
push edi
mov eax,[SELECTED]
call ENTRY_GET
mov edi,100
test eax,eax
jz have
movzx edi,byte [eax+7]
have:
mov ebx,[MENU_X]
add ebx,GROWTH_X
mov esi,[MENU_Y]
add esi,GROWTH_Y
cmp dword [MOUSE+LEFT_CLICK],0
je no_start
mov eax,[MOUSE+MOUSE_X]
sub eax,ebx
cmp eax,GROWTH_W
jae no_start
mov eax,[MOUSE+MOUSE_Y]
sub eax,esi
add eax,KNOB_ABOVE
cmp eax,KNOB_H
jae no_start
mov dword [DRAG],1
no_start:
cmp dword [MOUSE+LEFT_HELD],0
jne held
mov dword [DRAG],0
held:
cmp dword [DRAG],0
je draw
mov eax,[MOUSE+MOUSE_X]
sub eax,ebx
sub eax,KNOB_HALF
imul eax,eax,100
cdq
mov ecx,KNOB_SPAN
idiv ecx
cmp eax,0
jge low_ok
xor eax,eax
low_ok:
cmp eax,100
jle high_ok
mov eax,100
high_ok:
cmp eax,edi
je draw
mov edi,eax
mov eax,[SELECTED]
call ENTRY_MAKE
test eax,eax
jz draw
mov ecx,edi
mov [eax+7],cl
draw:
push dword [BUTTON_X]
push dword [BUTTON_X+4]
push dword [BUTTON_X+8]
push dword [BUTTON_X+12]
push dword [DRAW_CHOICE]
mov [BUTTON_X],ebx
mov [BUTTON_X+4],esi
mov dword [BUTTON_X+8],GROWTH_W
mov dword [BUTTON_X+12],GROWTH_H
mov eax,edi
imul eax,eax,KNOB_SPAN
cdq
mov ecx,100
idiv ecx
push 0
push KNOB_W
push edi
push eax
push 0
call SLIDER_RENDER
add esp,20
pop dword [DRAW_CHOICE]
pop dword [BUTTON_X+12]
pop dword [BUTTON_X+8]
pop dword [BUTTON_X+4]
pop dword [BUTTON_X]
pop edi
pop esi
pop ebx
ret
]]

-- The page button over the panel's title: drawn like the outpost's own troop buttons, and a
-- left click on it switches the page.
templates.toggle = [[
push ebx
push esi
mov ebx,[MENU_X]
add ebx,TOGGLE_X
mov esi,[MENU_Y]
add esi,TOGGLE_Y
xor ecx,ecx
mov eax,[MOUSE+MOUSE_X]
sub eax,ebx
cmp eax,TOGGLE_W
jae draw
mov eax,[MOUSE+MOUSE_Y]
sub eax,esi
cmp eax,TOGGLE_H
jae draw
mov ecx,1
cmp dword [MOUSE+LEFT_CLICK],0
je draw
mov dword [MOUSE+LEFT_CLICK],0
xor dword [MODE],1
push ecx
push CLICK_SOUND
mov ecx,SOUNDS
call PLAY_SOUND
call PAD
pop ecx
draw:
push dword [BUTTON_X]
push dword [BUTTON_X+4]
push dword [BUTTON_X+8]
push dword [BUTTON_X+12]
push dword [BUTTON_HOVER]
push dword [BUTTON_IMAGE]
push dword [DRAW_CHOICE]
mov [BUTTON_X],ebx
mov [BUTTON_X+4],esi
mov dword [BUTTON_X+8],TOGGLE_W
mov dword [BUTTON_X+12],TOGGLE_H
mov [BUTTON_HOVER],ecx
mov dword [BUTTON_IMAGE],TEXT_BUTTON
push ecx
call BUTTON_RENDER
pop ecx
push 0
push 0
push 0x12
test ecx,ecx
jnz hot
push 0x3E66
push 0xC2F0EB
jmp words
hot:
push 0
push 0xCCFAFF
words:
push 1
lea eax,[esi+7]
push eax
lea eax,[ebx+TOGGLE_HALF]
push eax
mov eax,[MODE]
push dword [PAGE_TEXTS+eax*4]
mov ecx,TEXT_MANAGER
call SHADOW_TEXT
pop dword [DRAW_CHOICE]
pop dword [BUTTON_IMAGE]
pop dword [BUTTON_HOVER]
pop dword [BUTTON_X+12]
pop dword [BUTTON_X+8]
pop dword [BUTTON_X+4]
pop dword [BUTTON_X]
pop esi
pop ebx
ret
]]

-- The troop button renderer (prologue: push esi / push edi / mov edi,[esp+0xC] / mov ecx,edi,
-- 8 bytes). On the defender page: lit when the troop is picked, named after it.
templates.buttonRender = [[
cmp dword [MODE],0
jne own
push esi
push edi
mov edi,[esp+0xC]
mov ecx,edi
jmp RESUME
own:
push esi
push edi
mov edi,[esp+0xC]
mov eax,[SELECTED]
call ENTRY_GET
mov esi,1
test eax,eax
jz have
movzx esi,word [eax+4]
have:
mov edx,[BUTTON_HOVER]
xor eax,eax
bt esi,edi
setc al
mov [BUTTON_HOVER],eax
push edx
call BUTTON_RENDER
pop edx
push 0
push 0
push 0x12
test edx,edx
jnz hot
push 0x3E66
push 0xC2F0EB
jmp words
hot:
push 0
push 0xCCFAFF
words:
push 1
mov ecx,[BUTTON_X+4]
add ecx,7
push ecx
mov eax,[BUTTON_X+8]
cdq
sub eax,edx
sar eax,1
add eax,[BUTTON_X]
push eax
mov eax,[SELECTED]
imul eax,eax,B_STRIDE
mov ecx,edi
and ecx,7
cmp word [eax+B_TYPE],ARAB_OUTPOST
jne euro
add ecx,8
euro:
push dword [DEFENDER_NAMES+ecx*4]
mov ecx,TEXT_MANAGER
call SHADOW_TEXT
pop edi
pop esi
ret
]]

-- The troop button click (prologue: mov eax,[selected], 5 bytes). On the defender page it
-- picks or drops that troop.
templates.buttonClick = [[
cmp dword [MODE],0
jne own
mov eax,[SELECTED]
jmp RESUME
own:
mov eax,[SELECTED]
call ENTRY_MAKE
test eax,eax
jz done
mov ecx,[esp+4]
cmp ecx,8
jae done
mov edx,1
shl edx,cl
xor word [eax+4],dx
done:
ret
]]

-- The size slider, which is the amount on the defender page (prologue: mov ecx,[esp+8] / mov
-- eax,[selected], 9 bytes). Messages: 1 set up (min, max, value), 2 and 3 set the value, 4 read
-- it, 5 one step less, 6 one more. FIELD is the entry byte (6 defenders); SYNC 1 also writes the
-- game's own defender count (1 to its 8 slots).
templates.slider = [[
cmp dword [MODE],0
jne own
mov ecx,[esp+8]
mov eax,[SELECTED]
jmp RESUME
own:
mov eax,[SELECTED]
call ENTRY_MAKE
test eax,eax
jz done
mov ecx,[esp+8]
cmp ecx,1
jne not_setup
mov edx,[esp+0xC]
mov dword [edx],0
mov edx,[esp+0x10]
mov dword [edx],TOP
jmp report
not_setup:
cmp ecx,2
je take
cmp ecx,3
je take
cmp ecx,5
je less
cmp ecx,6
je more
jmp report
take:
mov edx,[esp+0x14]
mov ecx,[edx]
cmp ecx,0
jge low_ok
xor ecx,ecx
low_ok:
cmp ecx,TOP
jle high_ok
mov ecx,TOP
high_ok:
mov [eax+FIELD],cl
jmp changed
less:
movzx ecx,byte [eax+FIELD]
sub ecx,STEP
jge less_ok
xor ecx,ecx
less_ok:
mov [eax+FIELD],cl
jmp changed
more:
movzx ecx,byte [eax+FIELD]
add ecx,STEP
cmp ecx,TOP
jle more_ok
mov ecx,TOP
more_ok:
mov [eax+FIELD],cl
changed:
if SYNC <> 0
movzx ecx,byte [eax+FIELD]
test ecx,ecx
jnz some
mov ecx,1
some:
cmp ecx,VANILLA_SLOTS
jbe fits
mov ecx,VANILLA_SLOTS
fits:
mov edx,[SELECTED]
imul edx,edx,B_STRIDE
mov [edx+B_DEFENDERS],cl
end if
report:
movzx ecx,byte [eax+FIELD]
mov edx,[esp+0x14]
mov [edx],ecx
done:
ret
]]

return templates
