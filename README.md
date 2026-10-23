# 🎮 Battle Balls

Ein rasantes 2D-Multiplayer-Plattform-Duellspiel für **2–6 Spieler** in **Godot 4.6**, inspiriert von:
- **[Rounds](https://landfall.se/rounds)**: Arena-Kämpfe, physikbasiertes Gunplay und der ikonische **5-Karten-Upgrade-Draft** für die Rundenverlierer!
- **[Bapbap](https://bapbap.gg/)**: Einzigartige Hero-Klassen mit passiven Traits und aktiven Fähigkeiten.
- **Super Mario**: Dynamisch generierte Sidescroller-Arenen mit Sprungfedern, Warp-Pipes, Herzblöcken, Stacheln und steigender Sudden-Death-Lava.
- **Integrierte Bot-KI**: Jeder Slot kann ein Bot sein – sofortiges Solo-Testen, Koop-Training oder gemischte Online-Runden ohne zweiten Mitspieler.

---

## 🌟 Features

### 1. Bapbap Hero-Klassen
| Held | Rolle | HP / Tempo | Passive Fähigkeit | Aktive Fähigkeit |
| :--- | :--- | :--- | :--- | :--- |
| **Ignis** | Pyro Skirmisher | 100 HP / 310 Speed | **Afterburner**: Hinterlässt Feuerspur beim Dash | **Rocket Leap**: Explosiver Sprung mit AOE-Knockback |
| **Volt** | Hyper Speedster | 85 HP / 350 Speed | **Overcharge**: Permanenter Doppelsprung | **Flash Blink**: Sofortiger 220px Teleport |
| **Spore** | Toxic Alchemist | 105 HP / 295 Speed | **Spore Coat**: Angriffe vergiften Gegner (DoT) | **Spore Burst**: Hinterlässt toxische Giftgaswolke |
| **Nova** | Gravity Mage | 95 HP / 290 Speed | **Schwerelos**: Höherer Sprung | **Singularität**: Gravitationskern zieht Gegner heran und schädigt sie |
| **Klinge** | Blade Dancer | 110 HP / 315 Speed | **Klingentanz**: 15 Start-Schild und hohe Grundgeschwindigkeit | **Klingensturm**: Rundumschlag mit Rückstoß und kurzer Unverwundbarkeit |
| **Bastion** | Field Engineer | 125 HP / 270 Speed | **Aurora**: Doppelte Schild-Regeneration | **Heilfeld**: Heilt über Zeit und baut Schild auf |
| **Phantom** | Shadow Assassin | 90 HP / 325 Speed | **Nachtwind**: Höchste Grundgeschwindigkeit | **Schattensprung**: Teleport mit Treffer und Unverwundbarkeit |

Die HP-Spalte zeigt den **Heldenwert**. In der Lobby lässt sich ein **Basis-HP-Faktor von 50–300 %** einstellen (Standard **100 %**), der diese Werte vor Kartenboni skaliert. Die Klassenunterschiede bleiben dadurch erhalten (z. B. Bastion 125 HP vs. Volt 85 HP bei 100 %). Der Basis-Schaden eines Schusses liegt standardmäßig bei **22**.

#### Waffen & Munition
Jede Klasse besitzt eigene Waffenbasiswerte. Statt eines festen 5-Schuss-Magazins starten die meisten Helden mit **3 Munition**; **Volt** und **Klinge** haben **4**, **Phantom** nur **2**. Das Grund-Feuerintervall ist kürzer als früher (0,35 s), dafür ist die Nachladezeit länger als früher (1,0 s). Dadurch sind Bursts schneller, aber längere Kämpfe werden stärker vom Nachladen bestimmt.

| Held | Munition | Feuerintervall | Nachladezeit |
| :--- | ---: | ---: | ---: |
| **Ignis** | 3 | 0,22 s | 1,8 s |
| **Volt** | 4 | 0,17 s | 2,1 s |
| **Spore** | 3 | 0,28 s | 1,6 s |
| **Nova** | 3 | 0,30 s | 2,0 s |
| **Klinge** | 4 | 0,20 s | 1,9 s |
| **Bastion** | 3 | 0,30 s | 2,2 s |
| **Phantom** | 2 | 0,14 s | 1,6 s |

Munition, Feuerrate und Nachladezeit lassen sich über Karten verbessern: **Quick Draw**, **Schnelle Hände**, **Schnellfeuer** und **Gatling Surge** erhöhen die Feuerrate bzw. das Magazin; **Großes Magazin** und **Notvorrat** geben zusätzliche Munition; **Schnelllader**, **Taktisches Magazin** und **Feldwartung** verkürzen die Nachladezeit. Werte werden pro Karte addiert bzw. multipliziert und gelten für alle folgenden Runden.

**Universeller Block (Q)**: Jeder Spieler – unabhängig von der Klasse – kann mit **Q** kurz blocken. Der Block **verhindert 0,5 Sekunden lang Schaden vollständig**, **reflektiert gegnerische Projektile** und hat **4 Sekunden Cooldown**. Karten verbessern Dauer und Cooldown oder lösen beim Blocken Bomben, Heilzonen und Rückstoß aus. Die frühere Titan-Klasse mit ihrer exklusiven Barriere wurde dafür entfernt.

*Tipp: Im Hauptmenü auf „Spiel starten“ klicken – danach landet man in der Lobby.*

---

### 2. Lobby & Match-Regeln
Nach dem Start im Hauptmenü öffnet sich die **Lobby**:
- **2–6 Spieler**: Über „Spieler“ (2–6) werden die Slots festgelegt. Jeder Slot ab 2 kann als **Bot** oder **Mensch** konfiguriert werden – online übernimmt ein beitretender Client automatisch einen freien Mensch- oder Bot-Slot.
- **Dynamische Heldenwahl**: Pro Slot erscheint eine eigene Heldenreihe mit allen **7 Klassen**. Jeder menschliche Spieler wählt seinen Helden selbst; der Host kann zusätzlich die Helden der Bots festlegen.
- **Bereit-System**: jeder menschliche Spieler bestätigt mit „Bereit“; Bots sind automatisch bereit. Der Start ist erst möglich, wenn alle Slots bereit sind und jeder Mensch-Slot einen verbundenen Client hat.
- **Host**: Spieler 1 ist Host und darf Spielerzahl, Slot-Typen (Bot/Mensch), Match-Regeln, **Spielfeld/Map**, Draft-Konfiguration, **Kartenpools** und Kartenbans ändern sowie das Match starten.
- **Charakteranpassung**: Im Lobby-Tab **Charakter** stellt jeder Spieler Fell-, Augen- und Hosenfarbe seines Schweins ein. Lokal lässt sich der gewünschte Spieler-Slot auswählen; online bearbeitet jeder Client seinen eigenen Slot, und die Farben werden über den Host synchronisiert. Der Reiter erscheint nicht mehr während der Kartenauswahl.
- **Lobby-Loadouts**: Im Tab **Regeln** kann der Host komplette Regel-Presets unter einem Namen **speichern, laden und löschen**. Ein Loadout enthält Modus, Spielerzahl, Match-/Überlebens-/Kill-Punkte, Basis-HP-Faktor, Basis-Schaden, Draft-Konfiguration, Map, aktive Kartenpools, Kartenbans und Seltenheits-Prozente. Mitgeliefert sind **Standard**, **Schnell & Wild**, **Team 2v2** und **Chaos**; eigene Presets landen in `user://lobby_loadouts.json`. Beim Laden werden Modus und Spielerzahl zuerst gesetzt, überzählige Online-Clients sauber freigegeben und danach alle übrigen Regeln angewendet. Im Online-Modus darf nur der Host Loadouts verwalten; die angewendeten Einstellungen werden wie gewohnt an alle Clients synchronisiert.
- **Punkte für Match-Sieg**: 100–5000, Standard **500**. Wer zuerst diese Punktzahl erreicht, gewinnt das Match.
- **Punkte für Überleben**: 0–500, Standard **50** pro Runde für den letzten Überlebenden.
- **Punkte pro Kill**: 0–500, Standard **50** pro Abschuss; wird dem Schützen sofort gutgeschrieben.
- **Basis-HP-Faktor**: einstellbar von **50–300 %**, Standard **100 %** (= Heldenwert). Der Faktor skaliert die klassenabhängigen Start-HP vor allen Kartenboni; Helden behalten ihre Unterschiede.
- **Basis-Schaden pro Schuss**: einstellbar von **1–200**, Standard **22**; gilt vor Helden- und Kartenmodifikatoren.
- **Karten-Draft konfigurieren**: „Wähle **X von Y** Karten“ – Standard **1 von 5**.
- **Kartenpools**: Im Karten-Tab lassen sich die Pools **Kern**, **Offensive**, **Defensive**, **Bewegung** und **Chaos** einzeln aktivieren. Nur Karten aus aktiven Pools erscheinen im Draft; mindestens ein Pool bleibt aktiv. Der Button **Alle Pools** aktiviert wieder das komplette Set.
- **Seltenheits-Prozente**: Für **Common, Uncommon, Rare, Epic und Legendary** lässt sich jeweils ein Prozentwert von **0–100 %** einstellen (Standard **50 / 25 / 15 / 8 / 2**). Die Summe wird automatisch normalisiert; sind alle Werte 0 %, werden alle Seltenheiten gleich behandelt.
- **Draft-Anzeige in der Lobby**: Die Lobby zeigt dauerhaft Spielerzahl, `Draft: X/Y`, Zielpunkte, Überlebens-/Kill-Punkte, den Basis-HP-Faktor, Basis-Schaden, die **Map** und den **kleinsten Kartenpool pro aktivem Helden** (`Pool min. X/Held`). Die Zahl kann kleiner als die Gesamtzahl aller Karten sein, weil klassenspezifische Karten nur für den passenden Helden zählen und Ausbaukarten erst nach ihrer Grundkarte verfügbar sind.
- **Powerup-Karten sperren**: gesperrte Karten erscheinen in keinem Draft mehr; es müssen immer genug Karten für das komplette Angebot verfügbar bleiben. Die Sperrliste ist nach Seltenheit gruppiert. Klassenspezifische Karten zählen dabei nur für den passenden Helden.
- **Start-Countdown**: Nach dem Rundenaufbau läuft ein großer **3-Sekunden-Countdown**. Erst danach werden Bewegung, Schießen, Dash, Fähigkeit, Bot-KI und Begleiter aktiv. Der eigene Charakter blinkt zum Start kurz auf. Sudden Death beginnt erst nach dem Countdown.
- **Statusanzeige am Charakter**: Über dem Helden zeigen kleine Striche die Munition bzw. ein Ring die verbleibende Nachladezeit. Unter dem Helden liegen Lebensbalken und Symbole für Schild, Dash und Fähigkeit; laufende Cooldowns werden transparent überblendet.
- **Free-for-All mit Punkten**: Eine Runde endet, sobald höchstens noch ein Spieler lebt. Der Überlebende erhält den Überlebensbonus, jeder Kill gibt sofort Punkte. Bei Doppel-KO gibt es keinen Überlebensbonus; der zuletzt gestorbene Spieler bleibt nur für den Draft-Ablauf der Rundensieger.
- **Bot-Steuerung nur in der Lobby**: Slot-Typen werden ausschließlich in der Lobby festgelegt. Während der Runde gibt es bewusst keinen F1- oder HUD-Umschalter.
- **Zurück**: führt ohne Match-Start zurück ins Hauptmenü.

Die Auswahl liegt zentral in `Global` (Slot-Arrays für Spieleranzahl, Bot/Mensch, Helden, Ready-Status, Scores, Match-Regeln, Kartenpools, Sperrliste). Im Online-Modus übermitteln Netzwerk-Clients ihre eigene Heldenwahl und ihren Ready-Status, während Spielerzahl, Slot-Typen, Match-Regeln, Kartenpools, Kartenbans und der Start beim Host liegen.

---

### 3. Der 5-Karten-Draft (Rounds Roguelike Comeback)
Alle Rundenverlierer bekommen nach jeder Niederlage **Y zufällige Karten** (Common, Uncommon, Rare, Epic, Legendary) und wählen davon **X** aus. Jede Karte darf pro Spieler nur **einmal** im Deck liegen; besessene Karten werden nicht erneut angeboten. Upgrades stapeln sich über das Match:
- **Seltenheits-Prozente**: Seltene Karten erscheinen nicht in jedem Draft. Für jede Seltenheit wird in der Lobby ein eigener Prozentanteil eingestellt (Standard **Common 50 %, Uncommon 25 %, Rare 15 %, Epic 8 %, Legendary 2 %**). Die Anteile werden automatisch normalisiert und gelten für Einzelkarten wie komplette Talentgruppen. Sind alle Werte 0 %, sind alle Seltenheiten gleich wahrscheinlich.
- **Kartenrahmen**: Im Draft und in der öffentlichen Auflösung zeigt der **äußere Rahmen die Seltenheit** (Grau/Grün/Blau/Lila/Gold) und der **innere Rahmen die Effektfarbe** der Karte.
- **Karten-Icons**: Jede Karte erhält ein kleines, prozedural gezeichnetes Icon, das zu ihrem Effekt passt (z. B. Herz für Heilung, Schneeflocke für Frost, Turm für Turmbau). Die Icons animieren mit **4 Frames** und laufen im Draft sowie in der öffentlichen Auflösung.
- **Mechanik-Tooltips**: Karten mit besonderen Mechaniken wie **Gift, Frost, Feuer, Blitz, Explosion, Abpraller, Durchschlag, Schild, Block, Dash, Heldenfähigkeit, Turm oder Drohne** erklären diese beim Hovern. Die Texte kommen zentral aus `CardMechanics` und erscheinen im Draft, in der Lobby-Sperrliste und in der HUD-Upgrade-Leiste.
- **Projektilballistik**: Normale Projektile haben eine leichte Schwerkraft und fliegen in einem flachen Bogen. **Leichtes Geschoss** und **Präzisionsmörser** flachen die Flugbahn ab; **Schweres Geschoss**, **Mörser** und **Belagerungsmörser** verstärken den Bogen und erhöhen den Schaden.
- **Mechanik-Voraussetzungen**: Karten, die eine Mechanik nur verstärken, ohne sie selbst zu verleihen, werden nur angeboten, wenn der Spieler die Mechanik bereits besitzt. Beispiel: **Schildschnellbau** erscheint nur mit einer Schildquelle (Basisschild oder Schildkarte). **Ausweichrolle** und **Fokuskristall** sind an Dash bzw. Heldenfähigkeit gebunden; beides besitzen aktuell alle Spieler, daher bleiben diese Karten universal verfügbar.

#### Kartenpools
Jede Karte gehört zu genau einem Pool. Bestehende Karten werden anhand ihrer Effekte automatisch zugeordnet; Ausbaukarten erben den Pool ihrer Grundkarte. Die Lobby filtert das Draft-Angebot nach den aktiven Pools:

| Pool | Inhalt | Neue Karten |
| :--- | :--- | :--- |
| **Kern** | Grundwerte, Munition, Utility | **Notvorrat** (+2 Munition, +15% Nachladegeschwindigkeit), **Fokuskristall** (-15% Ability-CD, -6% Feuerrate) |
| **Offensive** | Schaden, Projektile, Elemente | **Splittergeschoss** (+1 Schuss, +6° Streuung, -10% Schaden), **Panzerbrecher** (+30% Schaden, +1 Durchschlag), **Brandkapsel** (Feuerzone), **Kettenreaktion** (Blitz + Kettenblitz), **Leichtes Geschoss** (-35% Projektil-Schwerkraft, +10% Schaden), **Schweres Geschoss** (+45% Projektil-Schwerkraft, +20% Schaden), **Mörser** (+80% Projektil-Schwerkraft, +25% Schaden, +18px Explosionsradius) |
| **Defensive** | Leben, Schild, Block, Regeneration | **Sanitäter** (+1,2 HP/s, +15 HP), **Bollwerk** (+30 Schild, +0,15s Block), **Zweites Herz** (+50 HP, +0,5 HP/s) |
| **Bewegung** | Tempo, Sprünge, Dash, Größe | **Federstiefel** (+20% Sprung, +1 Sprung), **Windschatten** (+20% Tempo, -20% Dash-CD), **Leichtgewicht** (-15% Größe, +8% Tempo, -8% HP) |
| **Chaos** | Riskante Karten mit Nebenwirkungen | **Instabiler Kern** (Kamikaze, +15% Tempo, +20 HP), **Wandelnder Koloss** (+35% Größe, +40 HP, -10% Tempo) |

- **Common – Grundwerte**: Karten wie **Vitaler Kern** (+30 Max HP), **Leichtfüßig** (+5% Tempo, -10% Schwerkraft), **Scharfe Munition** (+20% Schaden), **Abpraller** (+1 Abpraller) und **Schnellfeuer** (+18% Feuerrate) verbessern die Basiswerte.
- **Uncommon – Spezialisierung**: **Regenerationsserum** (1,5 HP/s nach 3s ohne Schaden), **Blutdurst** (+12% Lebensraub), **Kompakte Statur** (15% kleinere Spielfigur), **Zwillingsschuss** (+1 Projektil), **Flipper-Modus** (+3 Abpraller), **Leichtes Geschoss** (flache Flugbahn, +10% Schaden) und **Schweres Geschoss** (steiler Bogen, +20% Schaden).
- **Rare – Machtspitzen**: **Giftklinge** (+50% Gift-Schaden), **Schnelllader** (+35% Nachladegeschwindigkeit), **Windläufer** (+25% Tempo), **Doppelsprung** (+1 Luft-Sprung) und **Ricochet-Kern** (+5 Abpraller).
- **Bouncy Balls**: Geschosse prallen bis zu 2x von Oberflächen ab.
- **Homing Micro-Seekers**: Geschosse korrigieren ihren Flugwinkel zum Gegner.
- **Cluster Warhead**: Geschosse explodieren beim Einschlag in 3 Schrapnells.
- **Vampiric Leech**: Wandelt 25% des ausgeteilten Schadens in Lebenspunkte um.
- **Ricochet Frenzy (Epic)**: Geschosse prallen bis zu 5x ab und gewinnen mit jedem Abprall Schaden.
- **Glass Cannon (Epic)**: +130% Schaden, -40% Max HP.
- **Martyrdom Shockwave (Legendary)**: Beim K.O. explodiert der Spieler in einer gewaltigen Druckwelle.
- **Chronos Drive (Legendary)**: -50% Dash-Cooldown, +2 Extra Air Jumps.
- *...und viele weitere Synergie-Karten!*

#### Klassenspezifische Upgrade-Karten
Jeder Held hat **3 exklusive Karten**, die nur im Draft des passenden Helden auftauchen. Im Draft-Angebot und in der öffentlichen Auflösung sind sie mit einem Klassen-Badge markiert:

| Held | Klassenkarten |
| :--- | :--- |
| **Ignis** | **Nachbrenner** (+20% Tempo, -20% Dash-CD, +15% Sprung), **Sprengkern** (+45px Explosionsradius, +25% Schaden, -10% Feuerrate), **Überhitzung** (+30% Feuerrate, +25% Projektilgeschwindigkeit, -15% Ability-CD) |
| **Volt** | **Overclock** (-25% Ability-CD, +15% Tempo, +20% Feuerrate), **Statisches Feld** (+2 Abpraller, +30% Projektilgeschwindigkeit, +1 Durchschlag), **Kinetische Ladung** (-35% Dash-CD, +1 Luft-Sprung, +20% Tempo) |
| **Spore** | **Virulenter Stamm** (+4 Gift-Stapel, +15% Schaden), **Mycelnetz** (+35 Max HP, +25 Schild, +20% Schild-Regeneration), **Toxische Blüte** (+3 Gift-Stapel, +45px Explosionsradius, +15% Lebensraub) |
| **Nova** | **Schwerkraftkern** (+40px Explosionsradius, +15% Schaden), **Leerer Raum** (-20% Ability-CD, +12% Projektilgeschwindigkeit), **Supernova** (+70px Explosionsradius, +25% Schaden, -10% Tempo) |
| **Klinge** | **Wirbelklinge** (+25% Schaden, +15% Feuerrate), **Klingenreflexe** (-30% Dash-CD, +12% Tempo), **Duellklinge** (+40 Max HP, +15% Lebensraub, +10% Schaden) |
| **Bastion** | **Energieschild** (+40 Schild, +25% Schild-Regeneration), **Feldwartung** (+40% Schild-Regeneration, +15% Nachladegeschwindigkeit), **Bastionsfestung** (+60 Schild, +25 Max HP, -10% Tempo) |
| **Phantom** | **Schattenklinge** (+20% Schaden, +2 Durchschlag), **Schattensprung** (-25% Ability-CD, +1 Luft-Sprung), **Todeskuss** (+35% Schaden, +15% Lebensraub, -10% Max HP) |

#### Talentbaum-Karten
Zusätzlich gibt es **9 globale Talentbaum-Familien** mit je **1 Grundkarte + 2 Ausbaukarten** sowie **Leichte Schuhe** mit dem Ausbau **Windschuhe**. Eine Ausbaukarte erscheint erst im Draft, wenn die Grundkarte bereits im eigenen Deck liegt. Sind beide Zweige einer Familie noch offen, werden sie gemeinsam angeboten (z. B. **Mehr Türme** und **Folgende Türme**). Jede Karte ist pro Spieler nur einmal verfügbar.

| Familie | Grundkarte | Ausbau A | Ausbau B |
| :--- | :--- | :--- | :--- |
| **Turm** | **Turm**: Spezialfähigkeit platziert einen automatisch angreifenden Turm. | **Mehr Türme**: Alle 5 Sekunden entsteht ein weiterer Turm an der aktuellen Position. | **Folgende Türme**: Türme folgen der Spielfigur. |
| **Giftschuss** | **Giftschuss**: +2 Gift-Stapel, +25% Gift-Schaden. | **Giftwolke**: Giftwolke an jeder Einschlagstelle. | **Giftspur**: Giftspur hinter dem Charakter, ohne Selbstschaden. |
| **Blitzschuss** | **Blitzschuss**: Betäubt Gegner für 0,1 Sekunden. | **Kettenblitz**: Springt auf nahe Gegner über und betäubt erneut. | **Blitz-Orb**: Erzeugt am Einschlag eine betäubende Blitzzone. |
| **Frostschuss** | **Frostschuss**: Geschosse verlangsamen Gegner für 0,8 Sekunden. | **Eisnova**: Gefrierende Fläche am Einschlag. | **Eisbahn**: Verlangsamende Spur hinter dem Charakter. |
| **Explosivschuss** | **Explosivschuss**: +30px Explosionsradius, +5% Schaden. | **Großer Knall**: +60px Explosionsradius, +15% Schaden. | **Splitterbomben**: Explosionen zerfallen in vier Splitterbomben. |
| **Feuersturm** | **Feuersturm**: Geschosse entzünden Gegner. | **Brandherd**: Brennender Boden am Einschlag. | **Feuerspur**: Brennende Spur hinter dem Charakter, ohne Selbstschaden. |
| **Wächterdrohne** | **Wächterdrohne**: Eine Drohne umkreist und beschießt Gegner. | **Zwillingsdrohne**: Eine zweite Drohne begleitet dich. | **Regenerationsdrohne**: Drohnen regenerieren zusätzlich laufend Lebenspunkte. |
| **Schutzdrohne** | **Schutzdrohne**: Eine Drohne umkreist dich und fängt gegnerische Schüsse ab. | **Heilende Schutzdrohne**: Jeder abgefangene Schuss heilt dich um den geblockten Schaden. | **Schutzdrohnen-Schwarm**: Zwei weitere Schutzdrohnen kreisen um dich. |
| **Mörser** | **Mörser**: +80% Projektil-Schwerkraft, +25% Schaden, +18px Explosionsradius. | **Präzisionsmörser**: +30% Schaden, -45% Projektil-Schwerkraft, +20% Projektilgeschwindigkeit. | **Belagerungsmörser**: +40% Schaden, +50% Projektil-Schwerkraft, +30px Explosionsradius. |

Der Kartenpool umfasst damit **161 Karten** (142 Grund-/Klassenkarten inkl. 11 Block-Karten + 19 Talent-Ausbaukarten), verteilt auf die fünf Draft-Pools **Kern**, **Offensive**, **Defensive**, **Bewegung** und **Chaos**. Talentbaum-Karten sind in Lobby, Draft und Auflösung mit einem **Evolution**-Banner markiert.

#### Block-Karten (universell)
Block-Karten verbessern die Q-Fähigkeit jedes Spielers:
- **Common**: **Blockübung** (+0,15s Dauer), **Schnelle Deckung** (-15% Cooldown).
- **Uncommon**: **Verstärkte Deckung** (+0,2s Dauer), **Schildstoß** (Block stößt Gegner weg).
- **Rare**: **Blockbombe** (Explosion beim Blocken), **Heilzone** (Heilfeld am Block-Standort), **Druckwelle** (starker Rückstoß), **Ausdauerblock** (+0,3s Dauer, -10% Cooldown).
- **Epic**: **Konterblitz** (reflektierte Projektile +50% Schaden), **Block-Experte** (-30% Cooldown, +0,2s Dauer), **Unzerbrechlich** (+0,4s Dauer, -10% Cooldown).

---

### 4. Vier feste Arenen mit eigenen Tilesets
Jede Runde spielt auf einer von vier Arenen. Jede Map besitzt ein **festes Tileset** und ein **festes Layout-Profil**, damit die Optik nicht mehr zufällig aus allen Tile-Stilen zusammengemischt wird. Der Host wählt die Map in der Lobby unter **Regeln → Spielfeld**. **Zufällig** löst deterministisch aus dem Runden-Seed eine konkrete Map auf; Host und Clients erhalten immer dieselbe Arena. Im Online-Modus bauen Host und Client die Map aus dem gemeinsamen Seed und der übertragenen Map-ID:

| Map | Tileset | Layout | Besonderheiten |
| --- | --- | --- | --- |
| **Grasarena** | Gras/Erde, Holzplattformen, Pflanzen | Schlanke, schwebende Balken | Zentrale Luft-Wippe, Kisten, Ranken, Eisflächen |
| **Wüstenruine** | Sandstein, Holzbohlen, Kakteen | Offene schwebende Inseln | Kettenplattformen, Kisten, TNT-Fässer |
| **Eisgrotte** | Schnee, Eisblöcke, Kristalle | Drei luftige Plattform-Etagen | Schwebende Wippe, Kettenplattform, Kisten, Eis |
| **Neonfabrik** | Blaue Tech-Blöcke, Rohre, Displays | Schlanke Tech-Balken | Zentrale Luft-Wippe, Ketten, Kisten, TNT |

- **Keine Seiten- oder Deckenwände**: Die Arena ist nach oben und zu den Seiten offen.
- **Schlanke Plattformen statt Treppen**: Die Arenen bestehen aus ein Kachel hohen Balken und schwebenden Inseln. Zwischen den Ebenen bleiben mindestens zwei freie Kacheln (72 px) Kopfraum; die Sprungkraft der Helden ist so abgestimmt, dass jede Drei-Kachel-Stufe sicher erreichbar bleibt.
- **Sichere Spawns**: Spawn-Positionen werden gegen Plattformen, Sprungfedern, Röhren, Stacheln, Fässer, Kisten und Powerups geprüft. Bei mehreren Spielern sucht sich jeder Slot die nächste freie Fläche.
- **Gummiwand**: Außerhalb der Karte liegt ein viergeteilter Rahmen in der Akzentfarbe der Map. Wer ihn berührt, nimmt Schaden und wird mit Nachdruck zurück in Richtung Kartenmitte geschleudert.
- **Zerstörbare Blöcke**: Halten 3 Treffer aus und verschwinden dann dauerhaft – neue Wege und Sichtlinien entstehen.
- **Starke Ranken**: Solide grüne Rankenbrücken, die nur durch Beschuss brechen und nach 8 Sekunden nachwachsen (Grasarena).
- **Schwache Ranken**: Zerbrechen bereits beim Darübergehen und wachsen nach 4,5 Sekunden nach. Nicht zu lange stehen bleiben! (Grasarena)
- **Eisflächen**: Blau schimmernde Zonen mit deutlich reduzierter Beschleunigung und Reibung – Schwung holen, aber rechtzeitig bremsen.
- **Sprungfedern (Jump Pads)**: Katapultieren Spieler hoch in die Luft für akrobatische Ausweichmanöver.
- **Warp-Pipes**: Verknüpfte Röhren teleportieren Spieler blitzschnell über das Kampffeld.
- **Herz-Blöcke (Mystery Blocks)**: Von unten anspringen oder anschießen belohnt mit +30 HP Heilung!
- **Stachelfallen**: Gefährliche Zonen, die Schaden zufügen und Spieler wegschleudern.
- **Sudden-Death-Lava**: Dauert ein Duell nach dem Start-Countdown länger als 38 Sekunden, steigt von unten glühende Lava empor!

#### Bewegliche Map-Objekte
Die beweglichen Elemente sind reine Spielfeld-Objekte, keine Upgrade-Karten. Der Host simuliert ihre Physik autoritativ; Clients erhalten kompakte Transform-Snapshots und zeigen eingefrorene Replikate.

- **Wippe**: Eine zentral in der Luft aufgehängte Holzplanke. Spielergewicht kippt sie zur schwereren Seite; ohne Belastung richtet sie sich langsam wieder waagerecht aus.
- **Kettenplattform**: Eine an zwei Ketten hängende Plattform, die beim Landen und Bewegen von Spielern schwingt.
- **Fass**: Rollt und wird durch Projektiltreffer oder Explosionen weggeschleudert.
- **TNT-Fass**: Beginnt nach einem Treffer **3 Sekunden lang zu blinken** und explodiert erst danach. Die Explosion verursacht Flächenschaden mit Abstand-Falloff und zündet benachbarte TNT-Fässer in einer Kettenreaktion. Clients sehen die Explosion auch dann, wenn das Fass aus dem Host-Snapshot verschwindet.
- **Holzkisten**: Physikalische Bauklötze in drei Größen, die zu stapelbaren Türmen aufgeschichtet werden. Stapel können durch Beschuss, Explosionen oder Spielerkollisionen ins Rutschen geraten und zusammenbrechen. Eine fallende Kiste verursacht Schaden, wenn sie mit ausreichender Geschwindigkeit auf einem Spieler landet.
- **Powerups**: Schweben als farbige Orbs auf den Plattformen oder fallen aus zerstörten Kisten. Je nach Map sind Anzahl und Verteilung unterschiedlich. Effekte: **Heilung**, **kurze Unverwundbarkeit**, **Schadensboost** und **Dauerfeuer** für wenige Sekunden.

---

### 5. Bot-KI (Solo-Test & gemischte Runden)
- Jeder Slot ab 2 kann in der Lobby als **Bot** oder **Mensch** konfiguriert werden. Standardmäßig ist Slot 2 ein Bot; für ein 6-Spieler-Solo-Match einfach fünf Bots einstellen.
- Die KI sucht den **nächstgelegenen lebenden Gegner**, springt über Hindernisse, zielt mit dynamischer Streuung, feuert mit Sichtlinien-Prüfung, nutzt Dashs & Fähigkeiten und wählt nach Rundenverlusten selbstständig Synergie-Karten aus.
- Slot-Typen werden **ausschließlich in der Lobby** gewählt. Während der Runde gibt es keinen F1- oder HUD-Umschalter. Im Online-Modus simuliert der Host alle Bots; Clients steuern nur ihren eigenen Slot.

---

### 6. Spielmodi: FFA, 2v2, 3v3 & 2v2v2
Der Host wählt den Modus im Lobby-Tab **Regeln**. Die Spielerzahl wird dabei automatisch auf die benötigte Größe gesetzt; nur **FFA** erlaubt frei 2–6 Spieler.

| Modus | Spieler | Teams | Aufteilung |
| :--- | :--- | :--- | :--- |
| **FFA** | 2–6 | jeder für sich | Slot = eigenes Team |
| **2v2** | 4 | 2 | 1+2 vs. 3+4 |
| **3v3** | 6 | 2 | 1+2+3 vs. 4+5+6 |
| **2v2v2** | 6 | 3 | 1+2 / 3+4 / 5+6 |

- **Rundenende:** In Team-Modi endet die Runde erst, wenn nur noch **ein Team** lebende Mitglieder hat. Ein einzelner Tod beendet die Runde also nicht vorzeitig.
- **Kein Freundschaftsfeuer:** Schaden von Teammitgliedern wird ignoriert – das gilt auch für Flächenfähigkeiten, TNT und reflektierte Projektile. Gegnerische Projektile werden von Teammitgliedern körperlich geblockt, verursachen aber keinen Schaden. KI, Türme und Drohnen wählen ausschließlich Gegner außerhalb des eigenen Teams.
- **Team-Punkte:** Die Teamwertung ist die Summe der individuellen Punkte aller Mitglieder. Das Match endet, sobald ein Team die eingestellte Zielpunktzahl erreicht. Einzelne Punkte, Kills, Schaden und der MVP bleiben weiterhin pro Spieler sichtbar.
- **Draft:** Nach einer verlorenen Runde draften **alle Mitglieder des bzw. der Verliererteams**; das Gewinnerteam erhält keine Karten.
- **Anzeige:** HUD und Lobby zeigen Teamnamen (ROT/BLAU/GRÜN), Team-Punkte und Team-Tags. Das Match-Ende-Panel kürt das Siegerteam; die Statistik-Tabelle bleibt spielerbezogen.
- Der Modus wird in Lobby und Startkonfiguration synchronisiert. Clients berechnen dieselben Teams aus Modus und Slot-Zuordnung.

---

## 🌐 Online-Multiplayer (2–6 Spieler)

Das Spiel nutzt **ENet über UDP** (Standardport **7777**) und kommt ohne Relay-Server aus. Der Host ist Slot 1 und autoritativ: Er simuliert die Runde, zieht die Draft-Karten und entscheidet über Runden-/Match-Ende. Bis zu **5 Clients** verbinden sich als Slots 2–6, senden ihre Eingaben an den Host und sehen die Welt als Replik. Nicht belegte Slots können Bots sein.

### 1. Verbindung herstellen
1. **Alle** starten dieselbe Spielversion (idealerweise die exportierte `.exe`).
2. **Host**: Hauptmenü → **ONLINE SPIELEN** → Port stehen lassen (`7777`) → **HOST ÖFFNEN**.
3. **Mitspieler**: Hauptmenü → **ONLINE SPIELEN** → IP-Adresse des Hosts und Port eingeben → **BEITRETEN**. Jeder weitere Freund nutzt dieselbe Adresse. Für einen **Zuschauer** vor dem Beitreten **„Als Zuschauer beitreten“** aktivieren.
4. Der Host stellt in der Lobby die **Spielerzahl (2–6)** und pro Slot **Bot/Mensch** ein. Jeder Client erhält automatisch einen freien Slot; ist kein Mensch-Slot frei, übernimmt er einen Bot-Slot. **Zuschauer** belegen keinen Slot, senden keine Eingaben und sehen Lobby, Match, Draft und Snapshots wie die Spieler.
5. Jeder Mensch wählt seinen Helden und setzt **Bereit**. Der Host stellt **Spielmodus**, Regeln, **Spielfeld/Map**, Draft, **Kartenpools** und Kartenbans ein, setzt ebenfalls **Bereit** und startet.

> **Ping-Anzeige:** Lobby und HUD zeigen die gemessene Verbindungslatenz. Der Host sieht die Werte aller Mitspieler und Zuschauer (`P2 35 ms`, `Z1 48 ms`), Clients sehen ihren eigenen Ping. Die Farbe wechselt von Grün über Gelb zu Rot; die Messung läuft etwa einmal pro Sekunde über eigene, unzuverlässige Ping-RPCs.

> **Steuerung im Online-Modus:** Jeder Client spielt mit der **P1-Steuerung** (WASD + Maus). Die Pfeiltasten-Steuerung gilt nur für den lokalen 2-Spieler-Modus am selben Rechner.

### 2. Die richtige IP-Adresse finden

**Im selben WLAN (LAN):**
- Die Lobby zeigt die lokale IPv4 des Hosts an (z. B. `192.168.1.42`). Diese IP + Port `7777` gibt der Host an die Mitspieler weiter.

**Über das Internet – Weg A: UPnP (automatisch):**
- Viele Router erlauben Programmen, den UDP-Port selbst freizugeben. Das Spiel versucht das automatisch und zeigt bei Erfolg die **öffentliche IP + Port** in der Lobby an.
- Diese Adresse teilt der Host den Mitspielern mit. Fertig.

**Über das Internet – Weg B: Portfreigabe im Router (falls UPnP scheitert):**
1. Im Router eine **Portweiterleitung** für **UDP 7777** auf die lokale IPv4 des Host-Rechners einrichten.
2. Die eigene **öffentliche IPv4** ermitteln (z. B. über eine Suchmaschine „meine IP“).
3. Mitspieler tragen `öffentliche IP` + Port `7777` ein.
4. In der Windows-Firewall Godot bzw. die Spiel-`.exe` für **private Netzwerke** erlauben.

**Über das Internet – Weg C: ZeroTier oder Tailscale (empfohlen, wenn Weg A/B nicht gehen):**
- Beide installieren **ZeroTier** oder **Tailscale** (kostenlos für Privatnutzung) und treten demselben virtuellen Netzwerk bei.
- Der Host teilt seine **virtuelle IP** (bei Tailscale meist `100.x.x.x`, bei ZeroTier z. B. `10.x.x.x`).
- Die Mitspieler tragen diese IP + Port `7777` ein. Router und Firewall müssen dafür meist nicht angepasst werden.
- Das ist besonders hilfreich bei **CGNAT** (wenn die öffentliche IP vom Provider geteilt wird und Portfreigaben nicht funktionieren).

### 3. Was synchronisiert wird
- Spielerzahl, Slot-Typen (Bot/Mensch), Heldenwahl, Ready-Status, Match-Regeln, **Spielmodus (FFA/2v2/3v3/2v2v2)**, **Spielfeld/Map**, Draft-Konfiguration, **Kartenpools**, Kartenbans, **Basis-HP-Faktor**, **Basis-Schaden**, **Match-/Überlebens-/Kill-Punkte** und **Seltenheits-Prozente**.
- **Charakterfarben**: Online-Clients senden Änderungen für ihren eigenen Slot an den Host; die Spieler-Snapshots übertragen die Farben anschließend an alle Clients.
- Level (gemeinsamer Seed + konkrete Map-ID), Spielerpositionen aller Slots, Geschosse, Treffer, Leben/Schilde, **bewegliche Map-Objekte**, Lava und Sudden Death.
- Start-Countdown: Alle Seiten zeigen **3, 2, 1, LOS!**; der Host gibt die Steuerung nach Ablauf frei.
- Türme werden als Netzwerk-Entitäten repliziert. Flächeneffekte (Gift, Feuer, Eis, Blitz, Singularität, Heilfeld) und Spuren werden per zuverlässigem RPC erzeugt. Drohnen laufen auf den Clients visuell mit.
- Spezial-Tiles: Zerstörte Blöcke und nachwachsende Ranken werden per zuverlässigem RPC synchronisiert. Eisflächen und die Gummiwand werden host-seitig simuliert.
- Draft-Angebot und Picks (der Host bestätigt jede Wahl), Punkte, Rundensieger/Teams und Match-Ende.
- **Zuschauer** erhalten dieselben Start-, Runden- und Snapshot-Nachrichten wie Spieler, aber keinen Spieler-Slot. Lobby-Sync und Match-Broadcasts gehen an Spieler **und** Zuschauer.
- **Match-Statistiken** (Kills, Tode, Schaden, Block, Heilung, Trefferquote, Runden) werden host-seitig geführt und beim Match-Ende an alle Clients übertragen.
- Alle Clients sehen dasselbe Sieger-Panel inklusive Statistik-Tabelle und MVP; „HAUPTMENÜ“ trennt die Verbindung und führt zurück ins Menü.

---

### 7. Feedback, Match-Statistiken & Helden-Stats
- **Projektilballistik & -trails**: Jedes normale Geschoss fällt leicht unter Schwerkraft und zieht eine kurze, in der Heldenfarbe eingefärbte Leuchtspur hinter sich her. Mörser-Karten verstärken den Bogen, Präzisionskarten flachen ihn ab. Die Spur funktioniert auch für replizierte Projektile auf Clients.
- **Screenshake**: Treffer, geblockte Treffer, Kills, Explosionen und TNT-Fässer lösen einen kurzen, schadensabhängigen Kamera-Shake aus. Sehr kleine Effekte bleiben bewusst dezent, damit das Zielen nicht leidet.
- **Nachspiel-Statistik**: Das Match-Ende-Panel zeigt eine Tabelle mit Punkten, Kills, Toden, ausgeteiltem Schaden, blockiertem Schaden, Heilung, Trefferquote und gewonnenen Runden pro Spieler.
- **MVP & Rekorde**: Der **beste Spieler** wird aus Punkten, Kills, Schaden, Block, Heilung, Runden und Toden berechnet. Zusätzlich werden **Meister Schaden**, **meiste blockierte Treffer** und **meiste Heilung** namentlich hervorgehoben.
- **Helden-Stats-Screen**: Im Hauptmenü öffnet **HELDEN-STATS** eine Übersicht aller Charaktere mit HP (inkl. aktuellem Basis-HP-Faktor), Schild, Tempo, Sprungkraft, Schusschaden, aktiver Fähigkeit, Passiv und Kurzbeschreibung.
- Match-Statistiken werden bei jedem neuen Match zurückgesetzt und host-seitig geführt; die Werte sind damit auch im Online-Modus für alle Spieler identisch.

### 4. Bekannte Grenzen
- Bis zu **6 Spieler** (Host + 5 Spieler-Clients) plus bis zu **4 Zuschauer**; einen Relay-Modus gibt es nicht.
- Zuschauer können nur in der Lobby beitreten, nicht mitten in einem laufenden Match.
- Kein Reconnect mitten im Match: Verlässt ein **Spieler** das Spiel, kehrt der Host ins Hauptmenü zurück (und umgekehrt). Ein Zuschauer kann die Partie jederzeit verlassen, ohne das Match zu unterbrechen.
- Bots werden ausschließlich host-seitig simuliert. Ein Client kann einen Bot-Slot nicht selbst übernehmen, solange das Match läuft.
- Kern-Entitäten (Türme, Flächeneffekte, Geschosse) werden repliziert; einzelne Partikel-/Sound-Effekte werden weiterhin host-seitig berechnet und können bei Clients fehlen.
- Bei sehr hoher Latenz können Positionen leicht nachziehen – der Host bleibt aber immer die Wahrheit.

### 5. Typische Probleme
| Problem | Lösung |
| :--- | :--- |
| „Verbindung fehlgeschlagen“ | Prüfen, ob der Host wirklich im Online-Panel hosted, IP/Port stimmen und beide dieselbe Version nutzen. |
| Freund kommt nicht rein, LAN geht aber | Windows-Firewall (UDP 7777) und Router-Portfreigabe prüfen; sonst ZeroTier/Tailscale nutzen. |
| UPnP-Meldung „nicht möglich“ | Kein Fehler des Spiels – Router unterstützt es nicht. Port manuell freigeben oder ZeroTier/Tailscale verwenden. |
| Verbindung bricht ab | Host oder Client hat das Spiel beendet. Beide zurück ins Menü und neu hosten/beitreten. |
| Client steuert falsch | Im Online-Modus gilt WASD + Maus (P1-Bindings), nicht die Pfeiltasten. |

---

## 🕹️ Steuerung

### Spieler 1 (Maus & Tastatur)
- **Bewegen**: `A` / `D`
- **Springen & Wandabsprung**: `Leertaste` (gedrückt halten für höheren Sprung)
- **Zielen**: Mauszeiger
- **Schießen**: `Linksklick`
- **Dash / Ausweichen**: `Shift` (kurze Unverwundbarkeit)
- **Block**: `Q` (0,5s schadensimmun + Projektilreflexion, 4s Cooldown)
- **Held-Fähigkeit**: `Rechtsklick` oder `E` (alternativ `F`)

### Spieler 2 (Tastatur / lokaler 2-Spieler-Modus)
*Gilt nur für den lokalen 2-Spieler-Modus. Der Online-Client nutzt die P1-Steuerung.*
- **Bewegen**: `Pfeiltaste Links` / `Rechts`
- **Springen**: `Pfeiltaste Hoch`
- **Zielen**: Pfeiltasten
- **Schießen**: `.` (Punkt)
- **Dash**: `/` (Schrägstrich)
- **Block**: `M`
- **Held-Fähigkeit**: `,` (Komma)

### Globale Tasten
- `R`: Match zurücksetzen und zurück in die Lobby (im Online-Modus deaktiviert)
