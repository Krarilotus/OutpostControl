# Outpost Control

**Szerző**: Monsterfish
**Verzió**: 1.0.16

Több beleszólás a térképszerkesztőben elhelyezett európai és arab előőrsök működésébe. Minden része külön kikapcsolható a beállításokban.

## Az előőrs panelje

Jelölj ki egy előőrsöt a térképszerkesztőben. A felső gomb két oldal között vált, a csúszkák mellett jobbra megjelenik az értékük.

- **Támadók** — az előőrs hullámai három csúszkával:
  - **Méret:** pontos létszám hullámonként, 0-tól (nincs hullám) a játék maximumáig (kikapcsolva a 6 véletlen lépcső). A modul nélkül a legközelebbi alapméret marad.
  - **Kezdési késleltetés:** várakozás az első hullámig (másodpercben, normál sebességen).
  - **Növekedés:** hullámonkénti növekedés az első hullám százalékában (0 = állandó, 50 = fél első hullám, 100 = teljes első hullám; maximum 999). A gyakoriság változatlan.
- **Védők** — ugyanaz a nyolc egységgomb új funkcióval és egy létszámcsúszka:
  - **Egységgombok:** az előőrs őrei (több esetén váltakoznak). Európai: íjászok, számszeríjászok, lándzsások, pikások, buzogányosok, kardforgatók, lovagok, szerzetesek; arab: arab íjászok, parittyások, lovasíjászok, arab kardforgatók, rabszolgák, orgyilkosok, tűzhajítók, számszeríjászok. Alapból íjászok.
  - **Mennyiség:** 0–50 őr; az elesettek egyesével, nagyobb létszámnál gyorsabban térnek vissza (8-nál 30 mp, 50-nél 5 mp).
  - **Harci módok:** gyalogos közelharcosok védekezőben; rabszolgák támadóban; lovagok járőröznek és 10 mezőn belüli ellenséges épületeket is támadnak; lovasíjászok 6 véletlen ponton járőröznek 7–15 mezőre; gyalogos lövészek helyből lőnek.
  - **Falakon:** a gyalogos őrök 16 mezőn belül felmennek a tulajdonos falaira, kőtornyaira és kő kapuházaira (beállítható).

## Támadók feladatai

Minden hullám egységtípus szerint szétválik induláskor:

| Egység | Első feladat (alapértelmezett) | Többiek |
| --- | --- | --- |
| Rabszolgák | árok betemetése (50%) | épületek felgyújtása és rombolása |
| Lándzsások | árok betemetése (50%) | falak és kapuk rombolása |
| Buzogányosok | árok betemetése (30%) | épületek rombolása |
| Kardforgatók | falak és kapuk rombolása (60%) | épületek rombolása |
| Arab kardforgatók | falak és kapuk rombolása (50%) | épületek rombolása |
| Lovagok | lordvadászat (40%) | vár körbelovaglása |
| Íjászok, arab íjászok | árok betemetése (30%) | előrehaladás és csapatok lövése |
| Parittyások | vár megkerülése (30%) | előrehaladás és csapatok lövése |
| Lovasíjászok | vár körbelovaglása (100%) | előrehaladás és csapatok lövése |
| Tűzhajítók | épületek felgyújtása (60%) | előrehaladás és csapatok égetése |

Minden arány állítható. A lovagok csak elérhető lordra vadásznak.

## Ostromgépek útközben

A katapultok (hajítógépek, kővetőgépek) és tűzballiszták megállnak lőni, amint ellenséges cél lőtávba kerül (katapultoknál épületek, tűzballisztáknál előbb csapatok és munkások), a saját lőtávjukkal (Rebalancerrel is), szövetségeseket sosem célozva.

## Következő ellenfél

Ha a megtámadott játékos lordja meghal, a csapat a legközelebbi élő lorddal rendelkező ellenségre megy tovább.

## Az előőrsök erősítik az MI-t (alapból ki)

Az MI előőrseinek hullámai az MI saját támadó seregéhez csatlakoznak (távolságiak a tartalékba, többiek a főseregbe) és a következő támadásban harcolnak; az ostromgépek maradnak az előőrsnél.

## Mentések és térképek

A beállítások a térképben és a mentésekben is megmaradnak (a Map Extensions modullal). A modul nélkül is játszható a térkép: az őrök száma megmarad (legalább 1 íjász), a hullámok pedig az alapméretet használják növekedés nélkül.
