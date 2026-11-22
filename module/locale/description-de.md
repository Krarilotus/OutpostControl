# Outpost Control

**Autor**: Monsterfish
**Version**: 1.0.16

Mehr Kontrolle über die europäischen und arabischen Außenposten, die du im Karteneditor platzierst. Jeder Teil lässt sich in den Einstellungen abschalten.

## Das Außenposten-Fenster

Wähle einen Außenposten im Karteneditor aus. Der Knopf oben im Fenster schaltet nun zwischen zwei Seiten um; jeder Regler zeigt rechts seinen Wert.

- **Angreifer** – welche Truppen der Außenposten entsendet, mit drei Reglern:
  - **Größe:** exakte Truppenzahl pro Welle, von 0 (keine Wellen) bis zur größten im Spiel selbst entsandten Menge (mit deaktivierter Option wieder die 6 Zufallsstufen des Spiels). Ohne das Modul behält die Karte die nächstgelegene Standardgröße.
  - **Startverzögerung:** Wartezeit bis zur ersten Welle (in Sekunden bei normaler Geschwindigkeit).
  - **Wachstum:** Zuwachs je Welle in Prozent der ersten Welle (0 = konstante Größe, 50 = jeweils halbe erste Welle hinzu, 100 = jeweils ganze erste Welle hinzu; Obergrenze 999 Truppen). Das Wellentempo bleibt wie im Spiel.
- **Verteidiger** – dieselben acht Truppenknöpfe mit neuer Bedeutung und ein Regler:
  - **Truppenknöpfe:** welche Truppen den Außenposten bewachen (bei mehreren im Wechsel). Europäische Außenposten bieten Bogenschützen, Armbrustschützen, Lanzenträger, Pikeniere, Streitkolbenkämpfer, Schwertkämpfer, Ritter und Mönche; arabische bieten arabische Bogenschützen, Steinschleuderer, berittene Bogenschützen, arabische Schwertkämpfer, Sklaven, Assassinen, Feuerwerfer und Armbrustschützen. Ohne Auswahl gelten Bogenschützen.
  - **Anzahl:** wie viele Wachen um den Außenposten stehen (0 bis 50). Gefallene erscheinen einzeln schneller nach, je höher die Zahl (alle 30 s bei 8, alle 5 s bei 50).
  - **Haltungen:** Nahkämpfer zu Fuß stehen defensiv; Sklaven sind aggressiv; Ritter patrouillieren aggressiv und greifen auch feindliche Gebäude innerhalb von 10 Feldern an; berittene Bogenschützen patrouillieren aggressiv über sechs zufällige Punkte 7–15 Felder entfernt; Fernkämpfer stehen und schießen wie gewohnt.
  - **Auf den Mauern:** Fußwachen besetzen Mauern, Steintürme und steinerne Torhäuser des Besitzers im Umkreis von 16 Feldern und verteilen sich gleichmäßig (einstellbar).

## Aufgaben der Angreifer

Jede Welle teilt sich beim Ausmarsch nach Einheitentyp auf passende Aufgaben auf:

| Einheit | Erste Aufgabe (Standardanteil) | Rest |
| --- | --- | --- |
| Sklaven | Burggraben füllen (50 %) | Gebäude niederbrennen und zerstören |
| Lanzenträger | Burggraben füllen (50 %) | Mauern und Tore einschlagen |
| Streitkolbenkämpfer | Burggraben füllen (30 %) | Gebäude zerstören |
| Schwertkämpfer | Mauern und Tore einschlagen (60 %) | Gebäude zerstören |
| Arabische Schwertkämpfer | Mauern und Tore einschlagen (50 %) | Gebäude zerstören |
| Ritter | Lord jagen (40 %) | Um die Burg reiten |
| Bogenschützen, arab. Bogenschützen | Burggraben füllen (30 %) | Vorrücken und Truppen beschießen |
| Steinschleuderer | Um die Burg laufen (30 %) | Vorrücken und Truppen beschießen |
| Berittene Bogenschützen | Um die Burg reiten (100 %) | Vorrücken und Truppen beschießen |
| Feuerwerfer | Gebäude anzünden (60 %) | Vorrücken und Truppen verbrennen |

Um die Burg reiten bedeutet, weit außen herumzuziehen und Arbeiter sowie Truppen außerhalb der Mauern anzugreifen. Ritter jagen den Lord nur, wenn er erreichbar ist; sonst reiten sie ebenfalls um die Burg. Alle Anteile sind einstellbar.

## Belagerungsgeräte unterwegs

Katapulte und Feuerballisten eines Außenpostens halten unterwegs sofort an, wenn ein feindliches Ziel in Reichweite liegt:

- **Katapulte** (und Triboke/Mangen) beschießen das nächste feindliche Gebäude in Reichweite.
- **Feuerballisten** beschießen zuerst feindliche Truppen und Arbeiter, danach Gebäude.

Die Reichweite richtet sich nach dem Spiel (inkl. Rebalancer) und gilt nur für feindliche Teams.

## Nächster Gegner

Ist der Lord des angegriffenen Spielers tot, wählt jede Außenposten-Truppe den nächsten Feind mit lebendem Lord, statt stehen zu bleiben.

## Außenposten verstärken die KI (standardmäßig aus)

Ist dies aktiviert, schließen sich Wellen aus KI-Außenposten der eigenen Angriffsarmee der KI an (Fernkämpfer zu den Reservetruppen, alle anderen zur Hauptarmee) und kämpfen beim nächsten Angriff mit. Belagerungsgeräte bleiben beim Außenposten.

## Spielstände und Karten

Die Einstellungen jedes Außenpostens werden in Karte und Spielstand gespeichert (über das Modul Map Extensions). Ohne dieses Modul bleibt die Karte spielbar: Die Anzahl der Wachen bleibt erhalten (mindestens 1 Bogenschütze), und die Wellen nutzen wieder die Standardgröße ohne Wachstum.
