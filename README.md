# 🎮 Battle Balls

Ein rasantes 2D-Multiplayer-Plattform-Duellspiel für **2–6 Spieler** in **Godot 4.6**, inspiriert von:
- **[Rounds](https://landfall.se/rounds)**: Arena-Kämpfe, physikbasiertes Gunplay und der ikonische **5-Karten-Upgrade-Draft** für die Rundenverlierer!
- **[Bapbap](https://bapbap.gg/)**: Einzigartige Hero-Klassen mit passiven Traits und aktiven Fähigkeiten.
- **Super Mario**: Dynamisch generierte Sidescroller-Arenen mit Sprungfedern, magischen Portalen, Herzblöcken, Stacheln und steigender Sudden-Death-Lava.
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
Jede Klasse besitzt eigene Waffenbasiswerte. Alle Charaktere führen einen **einhändigen Zauberstab** mit frei wählbarer Spitzenform (**Kugel, Stern, Kristall, Flamme**) und Spitzenfarbe. Der Stab wird prozedural gezeichnet und richtet sich wie zuvor die Waffe zum Ziel aus. Statt eines festen 5-Schuss-Magazins starten die meisten Helden mit **3 Munition**; **Volt** und **Klinge** haben **4**, **Phantom** nur **2**. Das Grund-Feuerintervall ist kürzer als früher (0,35 s), dafür ist die Nachladezeit länger als früher (1,0 s). Dadurch sind Bursts schneller, aber längere Kämpfe werden stärker vom Nachladen bestimmt.

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
- **Dynamische Heldenwahl**: Pro Slot erscheint eine eigene Heldenreihe mit allen **7 Klassen**. Jede Klasse besitzt ein eigenes, farblich passendes Icon; es erscheint im Helden-Grid, in der Slot-Kopfzeile und in der Charaktervorschau. Jeder menschliche Spieler wählt seinen Helden selbst; der Host kann zusätzlich die Helden der Bots festlegen.
- **Bereit-System**: Die **Bereit**-Schaltfläche sitzt unten direkt neben **Kampf starten**. Lokal meldet sie alle menschlichen Slots gemeinsam bereit, online schaltet jeder Client seinen eigenen Slot um; Bots sind automatisch bereit. Die Bereit-Anzeigen in den Heldenslots bleiben als Statusübersicht sichtbar und leuchten grün, sobald der jeweilige Slot bereit ist. Der Start ist erst möglich, wenn alle Slots bereit sind und jeder Mensch-Slot einen verbundenen Client hat.
- **Host**: Spieler 1 ist Host und darf Spielerzahl, Slot-Typen (Bot/Mensch), Match-Regeln, **Spielfeld/Map**, Draft-Konfiguration, **Kartenpools** und Kartenbans ändern sowie das Match starten.
- **Charakteranpassung**: Im Lobby-Tab **Charakter** stellt jeder Spieler Fell-, Augen- und Hosenfarbe seines Schweins, die **Form und Farbe der Zauberstabspitze** sowie die **Farbe des Basis-Schusses** ein. Lokal lässt sich der gewünschte Spieler-Slot auswählen; online bearbeitet jeder Client seinen eigenen Slot, und alle Anpassungen werden über den Host synchronisiert. Die Vorschau zeigt Charakter und Stab live. Das Profil des lokalen Nutzers wird ohne separaten Speichern-Knopf automatisch in `user://character_customization.json` gesichert und beim nächsten Start wieder geladen. Der Reiter erscheint nicht mehr während der Kartenauswahl.
- **Lobby-Loadouts**: Im Tab **Regeln** kann der Host komplette Regel-Presets unter einem Namen **speichern, laden und löschen**. Ein Loadout enthält Modus, Spielerzahl, Match-/Überlebens-/Kill-Punkte, Basis-HP-Faktor, Basis-Schaden, Draft-Konfiguration inklusive Draft-Modifier, Map, aktive Kartenpools, Kartenbans und Seltenheits-Prozente. Mitgeliefert sind **Standard**, **Schnell & Wild**, **Team 2v2** und **Chaos**; eigene Presets landen in `user://lobby_loadouts.json`. Beim Laden werden Modus und Spielerzahl zuerst gesetzt, überzählige Online-Clients sauber freigegeben und danach alle übrigen Regeln angewendet. Im Online-Modus darf nur der Host Loadouts verwalten; die angewendeten Einstellungen werden wie gewohnt an alle Clients synchronisiert.
- **Punkte für Match-Sieg**: 100–5000, Standard **500**. Wer zuerst diese Punktzahl erreicht, gewinnt das Match.
- **Weiterspielen nach dem Match-Ende**: Der Host kann im Sieger-Panel **WEITERSPIELEN** wählen. Punktestände, Decks und Match-Statistik bleiben erhalten, das Match-Ziel steigt um **30 % der bisherigen Zielpunktzahl** (mindestens auf den aktuellen Führenden plus diesen Zuschlag) und die nächste Runde startet direkt ohne neuen Draft. Im Online-Modus entscheidet nur der Host; Clients warten auf die neue Runde.
- **Punkte & Fortschrittsbalken im HUD**: Oben rechts steht nur das Match-Ziel. Jede Spielerzeile zeigt darunter einen kompakten Balken in der Heldenfarbe und den aktuellen Punktestand direkt rechts neben dem Balken; im Team-Modus füllen sich die Balken in der jeweiligen Teamfarbe (ROT/BLAU/GRÜN). Die Balkenlänge entspricht dem Anteil an der eingestellten Zielpunktzahl.
- **Punkte für Überleben**: 0–500, Standard **50** pro Runde für den letzten Überlebenden.
- **Punkte pro Kill**: 0–500, Standard **50** pro Abschuss; wird dem Schützen sofort gutgeschrieben.
- **Basis-HP-Faktor**: einstellbar von **50–300 %**, Standard **100 %** (= Heldenwert). Der Faktor skaliert die klassenabhängigen Start-HP vor allen Kartenboni; Helden behalten ihre Unterschiede.
- **Basis-Schaden pro Schuss**: einstellbar von **1–200**, Standard **22**; gilt vor Helden- und Kartenmodifikatoren.
- **Karten-Draft konfigurieren**: „Wähle **X von Y** Karten“ – Standard **1 von 5**.
- **Draft-Modifier**: Im Regeln-Tab lassen sich zwei optionale Modi aktivieren. **Blind pick** verdeckt das Kartenangebot und die gewählte Karte **nur online vor anderen menschlichen Spielern**; der aktive Spieler sieht seine Auswahl weiterhin. Lokal gegen Bots ist Blind pick ohne Wirkung und der Schalter deaktiviert. **Random pick** zieht automatisch eine zufällige Karte aus dem Angebot und deaktiviert die manuelle Auswahl; online entscheidet der Host autoritativ, damit alle Clients dieselbe Karte erhalten. Beide Modifier werden über Lobby-Sync und Loadouts verteilt.
- **Kartenpools**: Im Karten-Tab lassen sich die Pools **Kern**, **Offensive**, **Defensive**, **Bewegung** und **Chaos** einzeln aktivieren. Nur Karten aus aktiven Pools erscheinen im Draft; mindestens ein Pool bleibt aktiv. Der Button **Alle Pools** aktiviert wieder das komplette Set.
- **Seltenheits-Prozente**: Für **Common, Uncommon, Rare, Epic und Legendary** lässt sich jeweils ein Prozentwert von **0–100 %** einstellen (Standard **50 / 25 / 15 / 8 / 2**). Die Summe wird automatisch normalisiert; sind alle Werte 0 %, werden alle Seltenheiten gleich behandelt. Die Hintergrund-Statistik kann überdurchschnittliche Karten dauerhaft in eine höhere Seltenheit aufwerten (siehe Abschnitt 4).
- **Draft-Anzeige in der Lobby**: Die Lobby zeigt dauerhaft Spielerzahl, `Draft: X/Y`, aktive Draft-Modifier, Zielpunkte, Überlebens-/Kill-Punkte, den Basis-HP-Faktor, Basis-Schaden, die **Map** und den **kleinsten Kartenpool pro aktivem Helden** (`Pool min. X/Held`). Die Zahl kann kleiner als die Gesamtzahl aller Karten sein, weil klassenspezifische Karten nur für den passenden Helden zählen und Ausbaukarten erst nach ihrer Grundkarte verfügbar sind.
- **Powerup-Karten sperren**: gesperrte Karten erscheinen in keinem Draft mehr; es müssen immer genug Karten für das komplette Angebot verfügbar bleiben. Die Sperrliste ist nach Seltenheit gruppiert. Klassenspezifische Karten zählen dabei nur für den passenden Helden.
- **Start-Countdown**: Nach dem Rundenaufbau läuft ein großer **3-Sekunden-Countdown**. Erst danach werden Bewegung, Schießen, Dash, Fähigkeit, Bot-KI und Begleiter aktiv. Die Kamera beginnt nah am eigenen Charakter und zoomt während des Countdowns zur Übersicht über alle Spieler heraus; der eigene Charakter erscheint dabei sichtbar aus einem farblich zur Klasse passenden Portal. Sudden Death beginnt erst nach dem Countdown.
- **Statusanzeige am Charakter**: Über dem Helden zeigen kleine Striche die Munition bzw. ein Ring die verbleibende Nachladezeit. Unter dem Helden liegen Lebensbalken und Symbole für Schild, Dash und Fähigkeit; laufende Cooldowns werden transparent überblendet. Vergiftete Charaktere erhalten einen dezenten Grünton und lassen kleine grüne Bläschen aufsteigen; der Gift-Tick-Sound bleibt dabei leise im Hintergrund.
- **Lauf- und Trefferanimationen**: Die prozedural gezeichneten Schweine laufen mit gangabhängigem Beinschwung, Körperwippen, Vorwärtsneigung und flatternden Ohren; in der Luft werden die Beine angezogen. Treffer lösen ein kurzes Stauchen, Zittern, rotes Aufblitzen, geschlossene Augen und kleine Blutspritzer aus. Netzwerk-Clients sehen die Trefferanimation ebenfalls, sobald die HP im Snapshot sinken.
- **Todes-Sound**: Beim Tod eines Charakters erklingt ein kurzer, absteigender Sound mit Aufprallakzent. Er wird lokal und auf Netzwerk-Clients jeweils genau einmal pro Tod abgespielt; auf Clients wird dafür der Wechsel des Spieler-Snapshots von lebend zu leer ausgewertet.
- **Free-for-All mit Punkten**: Eine Runde endet, sobald höchstens noch ein Spieler lebt. Der Überlebende erhält den Überlebensbonus, jeder Kill gibt sofort Punkte. Bei Doppel-KO gibt es keinen Überlebensbonus; der zuletzt gestorbene Spieler bleibt nur für den Draft-Ablauf der Rundensieger.
- **Bot-Steuerung nur in der Lobby**: Slot-Typen werden ausschließlich in der Lobby festgelegt. Während der Runde gibt es bewusst keinen F1- oder HUD-Umschalter.
- **Zurück**: führt ohne Match-Start zurück ins Hauptmenü.

Die Auswahl liegt zentral in `Global` (Slot-Arrays für Spieleranzahl, Bot/Mensch, Helden, Ready-Status, Scores, Match-Regeln, Kartenpools, Sperrliste und Draft-Modifier). Im Online-Modus übermitteln Netzwerk-Clients ihre eigene Heldenwahl und ihren Ready-Status, während Spielerzahl, Slot-Typen, Match-Regeln, Kartenpools, Kartenbans, Draft-Modifier und der Start beim Host liegen.

---

### 3. Der 5-Karten-Draft (Rounds Roguelike Comeback)
Alle Rundenverlierer bekommen nach jeder Niederlage **Y zufällige Karten** (Common, Uncommon, Rare, Epic, Legendary) und wählen davon **X** aus. Jede Karte darf pro Spieler nur **einmal** im Deck liegen; besessene Karten werden nicht erneut angeboten. Upgrades stapeln sich über das Match:
- **Blind pick**: Nur online gegen menschliche Spieler: Andere sehen nur Kartenrückseiten und die gewählte Karte wird als **Karte verdeckt** aufgelöst. Der aktive Spieler sieht Angebot und eigene Wahl normal. In lokalen Bot-Matches wird Blind pick ignoriert.
- **Random pick**: Nach kurzer Anzeige wird automatisch eine gleichverteilte Zufallskarte aus den verbleibenden Angeboten gezogen. Bei mehreren Picks wiederholt sich das; online zieht immer der Host, damit die Clients synchron bleiben.
- **Seltenheits-Prozente**: Seltene Karten erscheinen nicht in jedem Draft. Für jede Seltenheit wird in der Lobby ein eigener Prozentanteil eingestellt (Standard **Common 50 %, Uncommon 25 %, Rare 15 %, Epic 8 %, Legendary 2 %**). Die Anteile werden automatisch normalisiert und gelten für Einzelkarten wie komplette Talentgruppen. Sind alle Werte 0 %, sind alle Seltenheiten gleich wahrscheinlich.
- **Kartenrahmen**: Im Draft und in der öffentlichen Auflösung zeigt der **äußere Rahmen die Seltenheit** (Grau/Grün/Blau/Lila/Gold) und der **innere Rahmen die Effektfarbe** der Karte.
- **Karten-Icons**: Jede Karte erhält ein kleines, prozedural gezeichnetes Icon, das zu ihrem Effekt passt (z. B. Herz für Heilung, Schneeflocke für Frost, Turm für Turmbau, Panzerplatte für Rüstung, Spiegelpfeile für Reflexion). Die Icons animieren mit **4 Frames** und laufen im Draft sowie in der öffentlichen Auflösung.
- **Mechanik-Tooltips**: Karten mit besonderen Mechaniken wie **Gift, Frost, Feuer, Blitz, Explosion, Abpraller, Durchschlag, Schild, Rüstung, Schadensreflexion, Block, Dash, Heldenfähigkeit, Turm oder Drohne** erklären diese beim Hovern. Die Texte kommen zentral aus `CardMechanics` und erscheinen im Draft, in der Lobby-Sperrliste und in der HUD-Upgrade-Leiste.
- **Projektilballistik**: Normale Projektile haben eine leichte Schwerkraft und fliegen in einem flachen Bogen. **Leichtes Geschoss** und **Präzisionsmörser** flachen die Flugbahn ab; **Schweres Geschoss**, **Mörser** und **Belagerungsmörser** verstärken den Bogen und erhöhen den Schaden.
- **Mechanik-Voraussetzungen**: Karten, die eine Mechanik nur verstärken, ohne sie selbst zu verleihen, werden nur angeboten, wenn der Spieler die Mechanik bereits besitzt. Beispiel: **Schildschnellbau** erscheint nur mit einer Schildquelle (Basisschild oder Schildkarte), **Turm-Panzerung** und **Schnellfeuer-Geschütz** nur mit der Turm-Fähigkeit. **Ausweichrolle** und **Fokuskristall** sind an Dash bzw. Heldenfähigkeit gebunden; beides besitzen aktuell alle Spieler, daher bleiben diese Karten universal verfügbar.

#### Kartenpools
Jede Karte gehört zu genau einem Pool. Bestehende Karten werden anhand ihrer Effekte automatisch zugeordnet; Ausbaukarten erben den Pool ihrer Grundkarte. Die Lobby filtert das Draft-Angebot nach den aktiven Pools:

| Pool | Inhalt | Neue Karten |
| :--- | :--- | :--- |
| **Kern** | Grundwerte, Munition, Utility | **Notvorrat** (+2 Munition, +15% Nachladegeschwindigkeit), **Fokuskristall** (-15% Ability-CD, -6% Feuerrate) |
| **Offensive** | Schaden, Projektile, Elemente | **Splittergeschoss** (+1 Schuss, +6° Streuung, -10% Schaden), **Panzerbrecher** (+30% Schaden, +1 Durchschlag), **Brandkapsel** (Feuerzone), **Kettenreaktion** (Blitz + Kettenblitz), **Leichtes Geschoss** (-35% Projektil-Schwerkraft, +10% Schaden), **Schweres Geschoss** (+45% Projektil-Schwerkraft, +20% Schaden), **Mörser** (+80% Projektil-Schwerkraft, +25% Schaden, +18px Explosionsradius) |
| **Defensive** | Leben, Schild, Rüstung, Reflexion, Block, Regeneration | **Sanitäter** (+1,2 HP/s, +15 HP), **Bollwerk** (+30 Schild, +0,15s Block), **Zweites Herz** (+50 HP, +0,5 HP/s), **Tank-Panzerung** (neunstufiger Evolutionsbaum) |
| **Bewegung** | Tempo, Sprünge, Dash, Größe | **Federstiefel** (+20% Sprung, +1 Sprung), **Windschatten** (+20% Tempo, -20% Dash-CD), **Leichtgewicht** (-15% Größe, +8% Tempo, -8% HP) |
| **Chaos** | Riskante Karten mit Nebenwirkungen | **Instabiler Kern** (Kamikaze, +15% Tempo, +20 HP), **Wandelnder Koloss** (+35% Größe, +40 HP, -10% Tempo) |

- **Common – Grundwerte**: Karten wie **Vitaler Kern** (+30 Max HP), **Leichtfüßig** (+5% Tempo, -10% Schwerkraft), **Scharfe Munition** (+20% Schaden), **Abpraller** (+1 Abpraller), **Schnellfeuer** (+18% Feuerrate) und **Rückstoßfeder** (+25% Rückstoß) verbessern die Basiswerte.
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
Zusätzlich gibt es **12 globale Talentbaum-Familien**: zehn klassische Familien mit je **1 Grundkarte + 2 Ausbaukarten**, **Leichte Schuhe** mit dem Ausbau **Windschuhe** und die **Tank-Panzerung** mit einem neunstufigen Evolutionsbaum. Eine Ausbaukarte erscheint erst im Draft, wenn die Grundkarte bereits im eigenen Deck liegt. Sind beide Zweige einer Familie noch offen, werden sie gemeinsam angeboten (z. B. **Mehr Türme** und **Folgende Türme**). Die Zweigwahl ist **exklusiv**: Sobald ein Zweig gewählt wurde, werden der andere Zweig und seine Nachfolger nicht mehr angeboten. Jede Karte ist pro Spieler nur einmal verfügbar.

Türme besitzen standardmäßig **100 Leben**, zeigen darüber einen Lebensbalken und werden als kleine, zum Ziel ausgerichtete Kanonen dargestellt. Gegnerische Treffer und Explosionen beschädigen sie; Freundschaftsfeuer nicht. Die Turm-Karten **Turm-Panzerung** (+75 Turm-Leben) und **Schnellfeuer-Geschütz** (25 % schnellere Schüsse) erscheinen nur, wenn die Turm-Fähigkeit bereits im Deck liegt.

| Familie | Grundkarte | Ausbau A | Ausbau B |
| :--- | :--- | :--- | :--- |
| **Turm** | **Turm**: Spezialfähigkeit platziert eine automatisch angreifende Kanone mit 100 Leben. | **Mehr Türme**: Alle 5 Sekunden entsteht ein weiterer Turm an der aktuellen Position. | **Folgende Türme**: Türme folgen der Spielfigur. |
| **Giftschuss** | **Giftschuss**: +2 Gift-Stapel, +25% Gift-Schaden. | **Giftwolke**: Giftwolke an jeder Einschlagstelle. | **Giftspur**: Giftspur hinter dem Charakter, ohne Selbstschaden. |
| **Blitzschuss** | **Blitzschuss**: Betäubt Gegner für 0,1 Sekunden. | **Kettenblitz**: Springt auf nahe Gegner über und betäubt erneut. | **Blitz-Orb**: Erzeugt am Einschlag eine betäubende Blitzzone. |
| **Frostschuss** | **Frostschuss**: Geschosse verlangsamen Gegner für 0,8 Sekunden. | **Eisnova**: Gefrierende Fläche am Einschlag. | **Eisbahn**: Verlangsamende Spur hinter dem Charakter. |
| **Explosivschuss** | **Explosivschuss**: +30px Explosionsradius, +5% Schaden. | **Großer Knall**: +60px Explosionsradius, +15% Schaden. | **Splitterbomben**: Explosionen zerfallen in vier Splitterbomben. |
| **Feuersturm** | **Feuersturm**: Geschosse entzünden Gegner. | **Brandherd**: Brennender Boden am Einschlag. | **Feuerspur**: Brennende Spur hinter dem Charakter, ohne Selbstschaden. |
| **Wächterdrohne** | **Wächterdrohne**: Eine Drohne umkreist und beschießt Gegner. | **Zwillingsdrohne**: Eine zweite Drohne begleitet dich. | **Regenerationsdrohne**: Drohnen regenerieren zusätzlich laufend Lebenspunkte. |
| **Schutzdrohne** | **Schutzdrohne**: Eine Drohne umkreist dich und fängt gegnerische Schüsse ab. | **Heilende Schutzdrohne**: Jeder abgefangene Schuss heilt dich um den geblockten Schaden. | **Schutzdrohnen-Schwarm**: Zwei weitere Schutzdrohnen kreisen um dich. |
| **Mörser** | **Mörser**: +80% Projektil-Schwerkraft, +25% Schaden, +18px Explosionsradius. | **Präzisionsmörser**: +30% Schaden, -45% Projektil-Schwerkraft, +20% Projektilgeschwindigkeit. | **Belagerungsmörser**: +40% Schaden, +50% Projektil-Schwerkraft, +30px Explosionsradius. |
| **Rückstoßfeder** | **Rückstoßfeder**: +25% Rückstoß. | **Druckkammer**: +35% Rückstoß, +10% Projektilgeschwindigkeit. | **Schockgeschoss**: +45% Rückstoß, +8% Schaden. |

#### Tank-Panzerung (Evolutionsbaum)
Die Tank-Familie ist ein neunstufiger Evolutionsbaum und deckt jede Seltenheit ab. **Rüstung** reduziert eingehenden Schaden prozentual, bevor Schild und Leben getroffen werden; mehrere Rüstungskarten addieren sich bis maximal **75 %**. **Schadensreflexion** wirft einen Anteil des tatsächlich erlittenen Schadens an den angreifenden Spieler zurück; der Anteil addiert sich bis maximal **60 %**. Reflektierter Schaden wird nicht erneut reflektiert.

| Seltenheit | Karte | Effekt | Voraussetzung |
| :--- | :--- | :--- | :--- |
| **Common** | **Tankplatte** | +30 Max HP, +5% Rüstung | Grundkarte |
| **Uncommon** | **Stahlhaut** | +18% Max HP, +6% Rüstung | Tankplatte (Zweig A) |
| **Uncommon** | **Dornenhaut** | +25 Max HP, +8% Rüstung, 8% Reflexion | Tankplatte (Zweig B) |
| **Rare** | **Festungspanzer** | +25% Max HP, +10% Rüstung, -5% Tempo | Stahlhaut |
| **Rare** | **Reflektorplatte** | +40 Max HP, +12% Rüstung, 12% Reflexion | Dornenhaut |
| **Epic** | **Titanenbollwerk** | +25% Max HP, +12% Rüstung, 10% Reflexion, -8% Tempo | Festungspanzer |
| **Epic** | **Spiegelpanzer** | +50 Max HP, +14% Rüstung, 18% Reflexion | Reflektorplatte |
| **Legendary** | **Ewige Bastion** | +35% Max HP, +18% Rüstung, 15% Reflexion, -10% Tempo | Titanenbollwerk |
| **Legendary** | **Spiegelkoloss** | +60 Max HP, +16% Rüstung, 22% Reflexion | Spiegelpanzer |

Der Kartenpool umfasst damit **175 Karten** (146 Grund-/Klassenkarten inkl. 11 Block-Karten + 29 Talent-Ausbaukarten), verteilt auf die fünf Draft-Pools **Kern**, **Offensive**, **Defensive**, **Bewegung** und **Chaos**. Talentbaum-Karten sind in Lobby, Draft und Auflösung mit einem **Evolution**-Banner markiert.

Treffer verursachen einen spürbaren Rückstoß. Für kurze Zeit ist die Bewegungskontrolle des getroffenen Ziels reduziert, damit der Impuls nicht sofort von Eingabe und Reibung geschluckt wird; die **Rückstoßfeder**-Familie verstärkt diesen Effekt für alle vom Spieler verursachten Treffer.

#### Block-Karten (universell)
Block-Karten verbessern die Q-Fähigkeit jedes Spielers:
- **Common**: **Blockübung** (+0,15s Dauer), **Schnelle Deckung** (-15% Cooldown).
- **Uncommon**: **Verstärkte Deckung** (+0,2s Dauer), **Schildstoß** (Block stößt Gegner weg).
- **Rare**: **Blockbombe** (Explosion beim Blocken), **Heilzone** (Heilfeld am Block-Standort), **Druckwelle** (starker Rückstoß), **Ausdauerblock** (+0,3s Dauer, -10% Cooldown).
- **Epic**: **Konterblitz** (reflektierte Projektile +50% Schaden), **Block-Experte** (-30% Cooldown, +0,2s Dauer), **Unzerbrechlich** (+0,4s Dauer, -10% Cooldown).

---

### 4. Kartenstatistik & automatische Seltenheits-Anpassung
Ein Hintergrunddienst führt eine dauerhafte Statistikdatei unter `user://card_statistics.json`. Alle abgeschlossenen Matches – lokal, mit Bots und online – fließen ein. Gespeichert wird pro Karte:

- **Pickrate** (`picks / offers`): Wie oft eine angebotene Karte tatsächlich gewählt wurde.
- **Killrate** (`kills / matches`): Kills pro Match, in dem die Karte im Deck lag. Ein Kill wird allen Karten im Deck des Schützen gutgeschrieben.
- **Winrate** (`wins / matches`): Anteil der Matches, in denen die Karte am Match-Ende im Deck lag und der Spieler bzw. das Team gewonnen hat.

Das Dokument enthält alle registrierten Karten, auch solche ohne bisherige Drafts, und zusätzlich Seltenheits-Overrides sowie ein Promotion-Log. Die Auswertung läuft automatisch nach jeweils **3 abgeschlossenen Matches** (beim Start wird eine fällige Auswertung nachgeholt). Verglichen werden Karten innerhalb ihrer aktuellen Seltenheit. Eine Karte wird um **eine Stufe** aufgewertet, wenn sie:

- mindestens **8 Match-Samples** besitzt,
- seit ihrer letzten Aufwertung mindestens **8 Matches** vergangen sind,
- eine geglättete Winrate von mindestens **55 %** erreicht und
- mindestens **15 Prozentpunkte** über dem gewichteten Durchschnitt der anderen Karten derselben Seltenheit liegt.

Pro Auswertung wird höchstens die stärkste Karte jeder Seltenheit aufgewertet; **Legendary** ist die Obergrenze. Aufwertungen werden sofort auf die `CardData`-Ressourcen angewendet und beim nächsten Start aus der Statistikdatei wiederhergestellt. Dadurch verschieben sich auch die Draft-Gewichtung und die Anzeige in Lobby, Draft und Auflösung automatisch. Es gibt bewusst keine automatische Abwertung. Wird `user://card_statistics.json` gelöscht, starten alle Karten wieder mit ihrer ursprünglichen Seltenheit.

---

### 5. Sieben feste Arenen mit eigenen Tilesets
Jede Runde spielt auf einer von sieben Arenen. Jede Map besitzt ein **festes Tileset** und ein **festes Layout-Profil**, damit die Optik nicht mehr zufällig aus allen Tile-Stilen zusammengemischt wird. Der Host wählt die Map in der Lobby unter **Regeln → Spielfeld**. **Zufällig** löst deterministisch aus dem Runden-Seed eine konkrete Map auf; Host und Clients erhalten immer dieselbe Arena. Im Online-Modus bauen Host und Client die Map aus dem gemeinsamen Seed und der übertragenen Map-ID:

| Map | Tileset | Layout | Besonderheiten |
| --- | --- | --- | --- |
| **Grasarena** | Gras/Erde, Holzplattformen, Pflanzen | Schlanke, schwebende Balken | Zentrale Luft-Wippe, Kisten, Ranken, Eisflächen |
| **Wüstenruine** | Sandstein, Holzbohlen, Kakteen | Offene schwebende Inseln | Kettenplattformen, Kisten, TNT-Fässer |
| **Eisgrotte** | Schnee, Eisblöcke, Kristalle | Drei luftige Plattform-Etagen | Schwebende Wippe, Kettenplattform, Kisten, Eis |
| **Neonfabrik** | Blaue Tech-Blöcke, Rohre, Displays | Schlanke Tech-Balken | Zentrale Luft-Wippe, Ketten, Kisten, TNT |
| **Weite Wiese** | Gras/Erde, Holzplattformen, Pflanzen | Nur wenige, weit auseinanderliegende Balken | Übersichtliche Duellfläche, ein Kistenstapel, Powerups |
| **Wolkeninsel** | Schnee, Eisblöcke, Kristalle | Wenige schwebende Eisinseln | Große Sprünge, Eisflächen, ein Kistenstapel |
| **Kistenfestung** | Sandstein, Holzkisten | Ausschließlich Holzkisten, keine festen Plattformen | Große zentrale Wippe mit Kistentürmen, zerstörbare Laufwege |

- **Keine Seiten- oder Deckenwände**: Die Arena ist nach oben und zu den Seiten offen.
- **Mehr Platz**: Die Arenen sind von 38×22 auf 44×25 Kacheln gewachsen – rund 32 % mehr Fläche für längere Wege und größere Kistenaufbauten.
- **Schlanke Plattformen statt Treppen**: Mit Ausnahme der Kistenfestung bestehen die Arenen aus ein Kachel hohen Balken und schwebenden Inseln. Zwischen den Ebenen bleiben mindestens zwei freie Kacheln (72 px) Kopfraum; die Sprungkraft der Helden ist so abgestimmt, dass jede Drei-Kachel-Stufe sicher erreichbar bleibt.
- **Sichere, verteilte Spawns**: Spawn-Kandidaten sind alle freien Standflächen auf Boden und Plattformen; in der Kistenfestung kommen exponierte Kistenoberseiten hinzu. Federn, Portale, Stacheln, Fässer, Kisten, Powerups, Eis und Spezialkacheln werden ausgeschlossen, und über der Standfläche bleiben zwei Reihen Kopfraum frei. Die Spieler werden per Farthest-Point über das ganze Level verteilt und dabei auf drei Höhenbänder (hoch, niedrig, mittel) gesetzt, statt alle am Boden zu starten. Die Auswahl ist für Host und Clients deterministisch.
- **Rundenstart ohne Altlasten**: Beim Start einer neuen Runde werden Projektile, Türme, Flächeneffekte und kurzlebige visuelle Effekte (Explosionen, Blitze, Schockwellen, Geister usw.) der Vorrunde entfernt. Status- und Powerup-Effekte starten mit den frisch erzeugten Spielern.
- **Gummiwand**: Außerhalb der Karte liegt ein viergeteilter Rahmen in der Akzentfarbe der Map. Wer ihn berührt, nimmt Schaden und wird mit Nachdruck zurück in Richtung Kartenmitte geschleudert.
- **Zerstörbare Blöcke**: Halten 3 Treffer aus und verschwinden dann dauerhaft – neue Wege und Sichtlinien entstehen.
- **Starke Ranken**: Solide grüne Rankenbrücken, die nur durch Beschuss brechen und nach 8 Sekunden nachwachsen (Grasarena).
- **Schwache Ranken**: Zerbrechen bereits beim Darübergehen und wachsen nach 4,5 Sekunden nach. Nicht zu lange stehen bleiben! (Grasarena)
- **Eisflächen**: Blau schimmernde Zonen mit deutlich reduzierter Beschleunigung und Reibung – Schwung holen, aber rechtzeitig bremsen.
- **Sprungfedern (Jump Pads)**: Katapultieren Spieler hoch in die Luft für akrobatische Ausweichmanöver.
- **Magische Portale**: Verknüpfte Portalpaare teleportieren Spieler blitzschnell über das Kampffeld. Nach einer Benutzung verschwinden beide Portale für **10 Sekunden** und erscheinen anschließend mit einer kurzen Öffnungsanimation wieder.
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
- **Kistenfestung**: Die einzige Arena ohne feste Plattformen. Stabile Kistentürme bilden die Laufwege, während die große Mittelwippe auf beiden Seiten mit Kisten beladen ist. Zerstörte Kisten verändern die Wege dauerhaft.
- **Powerups**: Schweben als farbige Orbs auf den Plattformen oder fallen aus zerstörten Kisten. Je nach Map sind Anzahl und Verteilung unterschiedlich. Effekte: **Heilung**, **kurze Unverwundbarkeit**, **Schadensboost** und **Dauerfeuer** für wenige Sekunden.

---

### 6. Bot-KI (Solo-Test & gemischte Runden)
- Jeder Slot ab 2 kann in der Lobby als **Bot** oder **Mensch** konfiguriert werden. Standardmäßig ist Slot 2 ein Bot; für ein 6-Spieler-Solo-Match einfach fünf Bots einstellen.
- Die KI sucht den **nächstgelegenen lebenden Gegner**, springt über Hindernisse, zielt mit dynamischer Streuung, feuert mit Sichtlinien-Prüfung, nutzt Dashs & Fähigkeiten und wählt nach Rundenverlusten selbstständig Synergie-Karten aus.
- Slot-Typen werden **ausschließlich in der Lobby** gewählt. Während der Runde gibt es keinen F1- oder HUD-Umschalter. Im Online-Modus simuliert der Host alle Bots; Clients steuern nur ihren eigenen Slot.

---

### 7. Spielmodi: FFA, 2v2, 3v3 & 2v2v2
Der Host wählt den Modus im Lobby-Tab **Regeln**. Die Spielerzahl wird dabei automatisch auf die benötigte Größe gesetzt; nur **FFA** erlaubt frei 2–6 Spieler.

| Modus | Spieler | Teams | Aufteilung |
| :--- | :--- | :--- | :--- |
| **FFA** | 2–6 | jeder für sich | Slot = eigenes Team |
| **2v2** | 4 | 2 | 1+2 vs. 3+4 |
| **3v3** | 6 | 2 | 1+2+3 vs. 4+5+6 |
| **2v2v2** | 6 | 3 | 1+2 / 3+4 / 5+6 |

- **Rundenende:** In Team-Modi endet die Runde erst, wenn nur noch **ein Team** lebende Mitglieder hat. Ein einzelner Tod beendet die Runde also nicht vorzeitig.
- **Kein Freundschaftsfeuer:** Schaden von Teammitgliedern wird ignoriert – das gilt auch für Flächenfähigkeiten, TNT und reflektierte Projektile. Gegnerische Projektile werden von Teammitgliedern körperlich geblockt, verursachen aber keinen Schaden. KI, Türme und Drohnen wählen ausschließlich Gegner außerhalb des eigenen Teams.
- **Halber Selbstschaden:** Eigene Explosionen und selbst ausgelöste TNT-Fässer verursachen nur **50 %** des normalen Schadens. Schaden an Teammitgliedern bleibt weiterhin deaktiviert.
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
- **Charakteranpassung**: Online-Clients senden Änderungen für ihren eigenen Slot an den Host; die Spieler-Snapshots übertragen Fell-, Augen- und Hosenfarbe, Zauberstabspitze und Schussfarbe anschließend an alle Clients. Beim Beitritt wird das lokal gespeicherte Nutzerprofil auf den zugewiesenen Slot angewendet und einmalig synchronisiert.
- Level (gemeinsamer Seed + konkrete Map-ID), Spielerpositionen aller Slots, Geschosse, Treffer, Leben/Schilde, **bewegliche Map-Objekte**, Lava und Sudden Death.
- Start-Countdown: Alle Seiten zeigen **3, 2, 1, LOS!**; der Host gibt die Steuerung nach Ablauf frei.
- Türme werden als Netzwerk-Entitäten repliziert. Flächeneffekte (Gift, Feuer, Eis, Blitz, Singularität, Heilfeld) und Spuren werden per zuverlässigem RPC erzeugt. Drohnen laufen auf den Clients visuell mit.
- Spezial-Tiles: Zerstörte Blöcke und nachwachsende Ranken werden per zuverlässigem RPC synchronisiert. Eisflächen und die Gummiwand werden host-seitig simuliert.
- Draft-Angebot und Picks (der Host bestätigt jede Wahl), Punkte, Rundensieger/Teams und Match-Ende.
- **Zuschauer** erhalten dieselben Start-, Runden- und Snapshot-Nachrichten wie Spieler, aber keinen Spieler-Slot. Lobby-Sync und Match-Broadcasts gehen an Spieler **und** Zuschauer.
- **Match-Statistiken** (Kills, Tode, Schaden, Block, Heilung, Trefferquote, Runden) werden host-seitig geführt und beim Match-Ende an alle Clients übertragen.
- Alle Clients sehen dasselbe Sieger-Panel inklusive Statistik-Tabelle und MVP; „HAUPTMENÜ“ trennt die Verbindung und führt zurück ins Menü. „WEITERSPIELEN“ ist host-exklusiv und startet mit erhöhtem Ziel eine neue Runde, ohne Punkte oder Decks zurückzusetzen.

---

### 7. Feedback, Match-Statistiken & Helden-Stats
- **Projektilballistik & -trails**: Jedes normale Geschoss fällt leicht unter Schwerkraft und zieht eine kurze, in der **konfigurierten Schussfarbe** eingefärbte Leuchtspur hinter sich her. Mörser-Karten verstärken den Bogen, Präzisionskarten flachen ihn ab. Die Spur funktioniert auch für replizierte Projektile auf Clients.
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
- **Nachladen**: `R`
- **Held-Fähigkeit**: `Rechtsklick` oder `E` (alternativ `F`)

### Spieler 2 (Tastatur / lokaler 2-Spieler-Modus)
*Gilt nur für den lokalen 2-Spieler-Modus. Der Online-Client nutzt die P1-Steuerung.*
- **Bewegen**: `Pfeiltaste Links` / `Rechts`
- **Springen**: `Pfeiltaste Hoch`
- **Zielen**: Pfeiltasten
- **Schießen**: `.` (Punkt)
- **Dash**: `/` (Schrägstrich)
- **Block**: `M`
- **Nachladen**: `L`
- **Held-Fähigkeit**: `,` (Komma)

### Globale Tasten
- `F9`: Match zurücksetzen und zurück in die Lobby (im Online-Modus deaktiviert)
