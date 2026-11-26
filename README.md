# 🐗 Lötkolbeneber – Spiel-Wiki

Lötkolbeneber ist ein schnelles 2D-Plattform-Duellspiel für **2–6 Spieler** (lokal, LAN oder übers Internet), gebaut mit **Godot 4.6**. Schweine mit glühenden Lötkolben kämpfen in Arenen, wer eine Runde verliert, darf sich eine neue Upgrade-Karte aussuchen.

Vorbilder:
- **[Rounds](https://landfall.se/rounds)**: Arena-Kämpfe, Gunplay mit Physik und der Karten-Draft für die Rundenverlierer.
- **[Bapbap](https://bapbap.gg/)**: Helden-Klassen mit Passiv und aktiver Fähigkeit.
- **Super Mario**: Sprungfedern, Portale, Herzblöcke, Stacheln und steigende Lava.

> Dieses Wiki öffnet sich auch direkt aus dem Spiel: Hauptmenü → **WIKI**. Früher hieß das Spiel **Battle Balls** bzw. DopDop.

---

## 📑 Inhalt

1. [Schnellstart](#-schnellstart)
2. [Steuerung](#-steuerung)
3. [Helden](#-helden)
4. [Kampf-Mechaniken](#-kampf-mechaniken)
5. [Nahkampf](#-nahkampf)
6. [Lobby & Match-Regeln](#-lobby--match-regeln)
7. [Spielmodi](#-spielmodi)
8. [Karten-Draft](#-karten-draft)
9. [Karten-Übersicht](#-karten-übersicht)
10. [Maps & Spielfeld-Objekte](#-maps--spielfeld-objekte)
11. [Runden-Modifier](#-runden-modifier)
12. [Bots](#-bots)
13. [Online & LAN](#-online--lan)
14. [Hauptmenü & Optionen](#-hauptmenü--optionen)
15. [Erfolge, Titel & Freischaltungen](#-erfolge-titel--freischaltungen)
16. [Statistiken, HUD & Feedback](#-statistiken-hud--feedback)
17. [Dateien & Speicherorte](#-dateien--speicherorte)
18. [Für Entwickler](#-für-entwickler)

---

## 🚀 Schnellstart

1. Spiel starten → Hauptmenü → **SPIEL STARTEN**. Du landest in der **Lobby**.
2. Spielerzahl wählen, freie Slots als **Bot** oder **Mensch** einstellen, Helden aussuchen.
3. Im Tab **Charakter** Name, Farben, Hauer, Lötspitze und Nahkampfwaffe einstellen.
4. **Bereit** drücken und **Kampf starten**.
5. Wer eine Runde verliert, wählt eine Karte. Wer zuerst die Zielpunktzahl erreicht (Standard **500**), gewinnt das Match.

Online mit Freunden: Hauptmenü → **ONLINE SPIELEN** → **Online hosten** und den 6-stelligen Code weitergeben (siehe [Online & LAN](#-online--lan)).

---

## 🎮 Steuerung

Alle Tasten lassen sich unter **Optionen → Steuerung** neu belegen. Hier steht die Standardbelegung.

### Spieler 1 (Maus & Tastatur, auch online)

| Aktion | Taste |
| :--- | :--- |
| Bewegen | `A` / `D` |
| Durchfallen (Einweg-Steg) | `S` |
| Springen, Wandsprung | `Leertaste` (gedrückt halten = höher) |
| Zielen | Mauszeiger |
| Angriff (Schuss oder Nahkampf, je nach Held) | `Linksklick` |
| Dash (je nach Held verschieden) | `Shift` (kurz unverwundbar) |
| Barriere | `Q` |
| Nachladen | `R` |
| Ulti | `E` |
| Heldenfähigkeit | `Rechtsklick` |

**Fähigkeiten zielen:** Alle gerichteten Fähigkeiten zielen auf den Mauszeiger: Schwarzes Loch (Nova), Wurzelwall (Druide) und Raketensprung (Ignis, nur die Flugrichtung). Fähigkeitstaste **halten** zeigt die Vorschau (Reichweitenring, Form am Ziel bzw. Flugbahn), **Loslassen** zaubert. Der Zeiger wird auf die Reichweite begrenzt. Liegt er in einer Wand, landet der Zauber an der nächsten freien Stelle; die Vorschau zeigt sie mit einer gestrichelten Linie an. `Esc` bricht ab (auch Rechtsklick, wenn die Fähigkeit auf einer anderen Taste liegt). Der Wurzelwall steht immer mit der breiten Seite zum Druiden. Unter *Optionen → Steuerung → Fähigkeit zielen* lässt sich auf **Sofort am Mauszeiger** umstellen (ohne Vorschau). Bots und Spieler 2 nutzen weiter die feste Entfernung in Zielrichtung. Giftwolke, Klingensturm und Heilfeld wirken weiter an der eigenen Position.

### Spieler 2 (nur lokaler 2-Spieler-Modus am selben PC)

| Aktion | Taste |
| :--- | :--- |
| Bewegen | `←` / `→` |
| Springen | `↑` |
| Durchfallen (Einweg-Steg) | `↓` |
| Zielen | Pfeiltasten |
| Schießen | `.` (Punkt) |
| Dash | `/` |
| Barriere | `M` |
| Nachladen | `L` |
| Ulti | `K` |
| Heldenfähigkeit | `,` (Komma) |

### Allgemeine Tasten

| Taste | Wirkung |
| :--- | :--- |
| `Tab` (halten) | Charakterblatt mit allen Werten, Karten-Boni und Netzdiagrammen der eigenen Kartenverteilung, auch während der Kartenwahl |
| `Esc` | Optionen öffnen. Lokal pausiert das Spiel, online läuft die Runde weiter |
| `F9` | Match zurücksetzen und zurück in die Lobby (nur lokal) |

---

## 🐷 Helden

Es gibt **10 Klassen**. Jede hat eigene Werte, ein Passiv, eine aktive Fähigkeit (Rechtsklick) und ein festes Outfit am Kopf. Jeder Held ist entweder **Fernkämpfer** (Linksklick schießt) oder **Nahkämpfer** (Linksklick schlägt mit seiner festen Waffe): Klinge (Schwert), Bastion (Hammer), Phantom (Lötkolben-Stich) und Zeitschläger (Uhrenpendel) sind Nahkämpfer, alle anderen schießen. Im Draft erscheinen nur Karten, die zur Angriffsart passen.

**Helden-Kits:** Jeder Held hat einen eigenen Dash (`Shift`), eine Fähigkeit (Rechtsklick) und eine **Ulti** (`E`). Meteorschauer (Ignis), Singularität (Nova) und Blizzard (Flocke) werden wie gezielte Fähigkeiten mit der Maus gezielt: `E` halten zeigt die Vorschau, Loslassen löst aus (oder sofort, je nach Option „Fähigkeit auslösen“).

| Held | Dash (`Shift`) | Fähigkeit (Rechtsklick) | Ulti (`E`) |
| :--- | :--- | :--- | :--- |
| **Volt** | **Blitzschritt**: Teleport 130 px, 2 Ladungen, jede lädt einzeln nach | **Kugelblitz**: langsame Blitzkugel (3,5 s), schockt alle 0,4 s Gegner im Radius 85 px mit 6 Schaden und verlangsamt sie | **Überladung** (26 s): 5 s lang +40 % Tempo, +50 % Feuerrate, kein Munitionsverbrauch, jeder Schuss springt als Kettenblitz weiter |
| **Phantom** | **Schattenschritt**: Dash, danach 0,8 s unsichtbar | **Köder**: Doppelgänger (40 HP, 3,5 s) läuft weiter, Phantom ist 1,5 s unsichtbar. Bots, Türme und Zielsuche nehmen den Köder ins Visier | **Nachtjagd** (28 s): 6 s unsichtbar und +30 % Tempo, Angriffe lassen nur kurz aufflackern, der erste Treffer macht doppelten Schaden |
| **Ignis** | **Nachbrenner**: Dash mit Feuerspur | **Rocket Leap**: explosiver Sprung (unverändert) | **Meteorschauer** (28 s, gezielt bis 460 px): nach 0,8 s Warnung schlagen 5 Meteore nebeneinander ein (je Radius 72 px, bis 22 Schaden) und hinterlassen 3 s Feuer |
| **Spore** | **Sporenstoß**: Dash, am Start bleibt eine Giftwolke | **Giftpilz** (gezielt bis 230 px): Falle am Boden, nach 0,6 s scharf. Platzt bei Gegnern in 55 px oder bei Kugeltreffern zu einer Giftwolke (75 px, 3,5 s, 11 Schaden/s). Höchstens 3 Pilze | **Seuchennebel** (30 s): 6 s lang wandert ein Giftnebel (Radius 260 px) mit Spore, vergiftet und bremst Gegner, Spore heilt 8 HP/s |
| **Nova** | **Phasengleiten**: 0,6 s frei lenkbar schweben, unverwundbar | **Gravitationsstoß**: Kegel (80°, 175 px) stößt Gegner weg und lenkt Kugeln ab. Nach unten gezielt schleudert er Nova hoch | **Singularität** (30 s, gezielt): Kern zieht Gegner im Radius 300 px heran und implodiert nach 2,6 s (Radius 170 px, 38 Schaden) |
| **Klinge** | **Durchstoß**: Dash durch Gegner hindurch, trifft jeden einmal (70 % Schwertschaden). Ein Treffer halbiert die Dash-Abklingzeit | **Klingenbumerang**: Schwert fliegt 280 px und zurück, trifft hin und zurück. Solange es fliegt, kein Hieb | **Klingensturm** (24 s): 3 s lang frei beweglicher Wirbel (145 px), alle 0,3 s Schaden, großer Schlusswirbel, schlägt Kugeln zurück |
| **Bastion** | **Rammbock**: nicht unverwundbar, Kugeln von vorn prallen ab, Gegner nehmen 25 Schaden, werden mitgeschoben und am Ende weggestoßen | **Magnethaken**: Haken bis 440 px, betäubt den ersten Gegner kurz und zieht ihn heran. Trifft alles, dessen Körper die Kette streift (große Eber leichter) | **Festung** (32 s): 5 s Kuppel (140 px), gegnerische Kugeln prallen von außen ab, innen heilen Bastion und Verbündete |
| **Druide** | **Rankenschwung**: Ranke bis 220 px zieht den Druiden an Wände und Decken. Ohne Halt normaler Dash | **Wurzelwall** (unverändert) | **Urkeiler** (35 s): 7 s riesiger Keiler, +60 % Leben, Hammer-Nahkampf, der Dash wird zum Ansturm (schleudert weg, bricht Kisten) |
| **Flocke** | **Schlitterschritt**: Dash, hinterlässt eine 3 s lange Eisbahn, auf der Gegner verlangsamt werden | **Gletscherlanze** (7 s): Eisstrahl in Zielrichtung bis zur ersten Wand (480 px), 26 Schaden an jedem Gegner auf der Linie, 1,6 s verlangsamt, am Ende eine Eisnova | **Blizzard** (28 s, gezielt bis 520 px): 5 s Schneesturm (Radius 120 px), 10 Schaden/s und starke Verlangsamung. Wer 2 s am Stück darin steht, friert 0,8 s ein |
| **Zeitschläger** | **Rückspul** (6 s Abklingzeit): springt an die Stelle von vor 2 s zurück und bekommt den Schaden aus dieser Zeit als Leben zurück. Ein blasses Nachbild zeigt dir die Stelle | **Zeitblase** (10 s): Kuppel an deiner Position (Radius 150 px, 4 s), Gegner darin 60 % langsamer, gegnerische Kugeln fliegen nur mit 25 % Tempo | **Zeitstopp** (32 s): 2 s lang frieren alle Gegner und ihre Kugeln ein. Deine Treffer an ihnen stauen sich und schlagen am Ende gesammelt ein |

Klinge schlägt in Kombos: Jeder **dritte Hieb** in Folge (innerhalb 1,6 s) ist ein starker Stoß mit 160 % Schaden.

Die **Ulti** lädt über eine Abklingzeit, nicht über Schaden. Sie läuft über Rundenwechsel weiter und startet im Match halb geladen. Fähigkeits-Abklingzeit-Karten wirken zur Hälfte auch auf die Ulti. Phantoms Passiv **Hinterhalt**: +50 % Nahkampfschaden aus der Unsichtbarkeit oder von hinten.

| Held | Rolle | HP | Tempo | Schild | Passiv | Fähigkeit | Outfit |
| :--- | :--- | ---: | ---: | ---: | :--- | :--- | :--- |
| **Ignis** | Pyro Skirmisher | 100 | 310 | 0 | **Afterburner**: Dash hinterlässt eine echte Feuerspur, Gegner darin brennen | **Rocket Leap**: Explosiver Sprung bis zum Zielpunkt (50 bis ca. 304 px), 35 Schaden im Einschlag (Radius 140) | Schweißerbrille |
| **Volt** | Hyper Speedster | 85 | 350 | 0 | **Overcharge**: Doppelsprung von Anfang an | **Kugelblitz**: wandernde Blitzkugel, schockt und verlangsamt | Gelbe Kappe mit Blitz |
| **Spore** | Toxic Alchemist | 105 | 295 | 10 | **Spore Coat**: Treffer vergiften (2 Stapel) | **Giftpilz**: Falle, platzt zu einer Giftwolke | Pilzhut |
| **Nova** | Gravity Mage | 95 | 290 | 10 | **Schwerelos**: Höchste Sprungkraft | **Gravitationsstoß**: stößt Gegner und Kugeln im Kegel weg | Zauberhut mit Mini-Planet |
| **Klinge** | Blade Dancer | 125 | 315 | 15 | **Klingentanz**: Start-Schild und hohes Tempo | **Klingenbumerang**: Schwert fliegt hin und zurück | Roter Schal |
| **Bastion** | Field Engineer | 145 | 270 | 20 | **Aurora**: Doppelte Schild-Regeneration, Schild-Cooldown nur 4 s | **Magnethaken**: zieht den ersten Gegner heran | Bauhelm mit Lampe |
| **Phantom** | Shadow Assassin | 100 | 325 | 5 | **Hinterhalt**: +50 % Nahkampfschaden aus der Unsichtbarkeit oder von hinten | **Köder**: Doppelgänger läuft weiter, Phantom wird unsichtbar | Ninja-Stirnband |
| **Druide** | Grove Warden | 105 | 295 | 10 | **Wurzelkraft**: Regeneriert ständig 2 HP/s | **Wurzelwall**: Rankenwand am Zielpunkt, breite Seite zum Druiden (108 px, 5 s, 150 HP), blockt Bewegung und Kugeln | Blätterkranz mit Geweih |
| **Blutritter** | Blood Knight (Nahkampf-Vampir, Schwert) | 110 | 300 | 0 | **Blutschild**: Jeder 3. Treffer an einem Gegner (Eber oder Horden-Gegner, auch verschiedene; Kisten und Objekte zählen nicht) lässt eine Blutkugel fallen; jede Kugel gibt +25 Schild, bis 200 % der Max-HP (zweite, rote Lage auf der Lebensleiste) | **Blutbersten**: der ganze Schild explodiert, 1 Schaden pro Schildpunkt im Radius 150. Dash **Blutsturm**: legt eine Blutkugel ab, stürmt 40 % weiter und durch Gegner. Ulti **Blutruf** (24 s): bis zu 6 Kugeln im Umkreis 520 px fliegen zu ihm, treffen sie unterwegs einen Gegner: 30 Schaden und +30 HP | Hoher Dracula-Kragen mit rotem Edelstein |
| **Flocke** | Frost Mage (Grundelement Frost) | 95 | 300 | 10 | **Kältehauch**: Jeder Treffer verlangsamt 0,8 s. Jeder 4. Schuss ist ein Eissplitter (+20 % Schaden, durchschlägt einen Gegner) | **Gletscherlanze**: durchbohrender Eisstrahl mit Eisnova | Türkiser Strickschal und Eiskristall-Diadem |
| **Zeitschläger** | Chrono Brawler | 120 | 300 | 10 | **Taktschlag**: Jeder 3. Pendeltreffer verlangsamt den Gegner 1,5 s um 30 % | **Zeitblase**: Kuppel, in der Gegner und ihre Kugeln stark verlangsamt sind | Wecker mit zwei Glocken |

Die genauen Zahlen der Fähigkeiten stehen im Spiel unter **HELDEN** im Hauptmenü und im Tooltip der Heldenwahl. Sie kommen direkt aus den Konstanten in `player.gd`, stimmen also immer.

### Waffe & Munition

Fernkämpfer schießen mit einem **Lötkolben**. Basis-Schaden pro Schuss ist **22** (in der Lobby einstellbar).

| Held | Munition | Feuerintervall | Nachladezeit |
| :--- | ---: | ---: | ---: |
| Ignis | 3 | 0,22 s | 1,2 s |
| Volt | 4 | 0,17 s | 1,4 s |
| Spore | 3 | 0,28 s | 1,05 s |
| Nova | 3 | 0,30 s | 1,35 s |
| Druide | 3 | 0,24 s | 1,2 s |

Die HP-Werte gelten bei **Basis-HP-Faktor 100 %**. In der Lobby lässt sich der Faktor von 50–300 % einstellen, die Unterschiede zwischen den Klassen bleiben dabei erhalten.

---

## 🥊 Kampf-Mechaniken

### Schüsse

- **Ballistik**: Schüsse fallen unter Schwerkraft und fliegen in einem Bogen. Karten wie **Leichtes Geschoss** machen die Bahn flacher, **Schweres Geschoss** und **Mörser** steiler und stärker. Drohnenschüsse fliegen flacher. Solange eine Kugel steigt, bremst die Schwerkraft doppelt so stark: Ein Schuss senkrecht nach oben kommt etwa 12 Kacheln hoch und fällt dir nach gut 3 s wieder auf den Kopf.
- **Leuchtspur**: Jeder Schuss zieht eine Spur in deiner gewählten **Schussfarbe**. Blitz-Schüsse knistern.
- **Zielsuche** (Homing): Weit weg lenken Geschosse kaum, nah am Gegner sehr stark. Weite Schüsse fliegen also erst im Bogen und korrigieren kurz vor dem Ziel.
- **Durchschlag**: Jeder Punkt Durchschlag geht durch einen weiteren Gegner **und** durch eine halbe Kachel feste Wand oder eine ganze Kachel zerstörbaren Block. Diagonale Schüsse kosten gleich viel. Die Rand-Felswand, Fässer, Herzblöcke und Türme lassen sich nicht durchschießen.
- **Eigene Schüsse**: Sobald eine Kugel deinen Körper verlassen hat, kann sie dich selbst treffen, etwa wenn ein Schuss nach oben auf deinen Kopf zurückfällt, vom Wind zurückgeweht wird oder abprallt. Selbstschaden ist halbiert.
- **Abpraller**: Geschosse prallen von Oberflächen ab. Wer schon Abpraller hat, bekommt drei Ausbaukarten angeboten:
  - **Gummiwand** (legendär): Kugeln prallen auch am Kartenrand ab, ohne einen Abpraller zu verbrauchen.
  - **Gummipuffer** (episch): 50 % weniger Selbstschaden durch eigene Kugeln, Explosionen und Flächen.
  - **Zellteilung** (episch): Bei jedem Abprall teilt sich die Kugel in zwei kleinere mit je 60 % Schaden. Höchstens 3 Teilungen pro Schuss (also maximal 8 Teile).
- **Projektil-Kollision**: Schüsse von Gegnern stoßen in der Luft zusammen. Stärke = Schaden × Größe. Sind beide ähnlich stark (Verhältnis ab 0,7), löschen sie sich aus. Sonst fliegt der stärkere geschrumpft weiter.
- **Rückstoß**: Treffer schubsen spürbar. Kurz danach ist die Steuerung des Ziels gedämpft, damit der Stoß wirkt.

### Barriere (`Q`)

Jeder Held hat die Barriere (früher „Block“): **0,5 s kein Schaden**, gegnerische Projektile werden **zurückgeworfen**, **4 s Abklingzeit**. Eine aktive Barriere fängt auch Nahkampfschläge ab. Sie hält **2 Treffer** aus (abgewehrte Kugeln zählen mit, eine Schrotsalve oder Rakete samt Explosion zählt als ein Treffer, Gift-Ticks gar nicht) und zerbricht danach mit Scherben und Glasklirren; die Abklingzeit beginnt dann sofort. Jeder Treffer hinterlässt einen Riss. Barriere-Karten verlängern sie oder lösen Bomben, Heilzonen, Minen und Rückstoß aus. Die Barriere ist **nicht** der Schild: Barriere-Karten verbessern nie den Schild und Schild-Karten nie die Barriere.

### Dash (`Shift`)

Kurzer Sprint mit kurzer Unverwundbarkeit. Ignis hinterlässt dabei Feuer.

### Leben, Schild & Regeneration

- **HP-Regeneration** (durch Karten) läuft sofort, auch direkt nach einem Treffer.
- **Schild** lädt sich erst **5 s nach dem letzten Schaden** wieder auf (**Schild-Cooldown**, Bastion **4 s**). Jeder Schaden aus jeder Quelle (Schüsse, Explosionen, Flächen, Gift, Eigenschaden) startet die Wartezeit neu. Karten (Schildkondensator −0,75 s, Schnellstart-Generator −1,25 s, Bollwerk −0,5 s) verkürzen sie, nie unter 0,5 s. Nur Bastions Heilfeld baut Schild auch während des Cooldowns auf. Schild-Upgrade-Karten erscheinen erst, wenn man mindestens **25 Schild** hat.
- Über der HP-Leiste zeigt ein **blauer Balken** den aktuellen Schild.
- **Rüstung** senkt jeden eingehenden Schaden prozentual, höchstens **75 %**.
- **Schadensreflexion** wirft einen Teil des erlittenen Schadens auf den Angreifer zurück, höchstens **60 %**. Reflektierter Schaden wird nicht noch einmal reflektiert.

### Statuseffekte

| Effekt | Wirkung |
| :--- | :--- |
| Gift | Schaden in Ticks, das Schwein wird grünlich und blubbert |
| Brand | Feuerschaden in Ticks |
| Frost | Verlangsamt |
| Betäubung | Keine Bewegung für kurze Zeit |
| Wand-Betäubung | Nach einem Hammerschlag: wer gegen Wand oder Decke prallt, ist betäubt |

### Flächeneffekte

Feuerböden, Giftwolken, Eisflächen, Blitzzonen, Singularität und Heilfelder werden als Zonen gezeichnet. Feuer landet immer auf dem Boden darunter und fährt auf beweglichen Plattformen, Wippen und Kisten mit.

---

## 🔨 Nahkampf

Nahkampf gehört fest zum Helden und liegt auf **Linksklick**: Klinge schlägt mit dem **Schwert** (30 Schaden alle 0,68 s), Bastion mit dem **Hammer** (30 Schaden alle 0,88 s, 1,5 Felder Reichweite statt 1), Phantom sticht mit dem **Lötkolben** (27 Schaden alle 0,77 s). Fernkämpfer haben keinen Nahkampf mehr, die Waffenwahl im Tab Charakter und die Lobby-Regel „Nahkampfwaffen“ entfallen. Die Tabelle zeigt die Grundwerte der Waffen vor den Helden-Faktoren. Allgemeine Karten für Schaden, Feuerrate, Lebensraub und Elemente wirken bei Nahkämpfern auf die Schläge (Feuerrate = Angriffstempo, Feuer = 3 Brandstapel, Blitz = 0,1 s Betäubung). Reine Projektil-Karten (Munition, Abpraller, Durchschlag, Zielsuche, Explosionen, Multishot) bekommen nur Fernkämpfer, Nahkampf-Karten nur Nahkämpfer. Auch die Schuss-Karten, für die es eine eigene Nahkampf-Karte gibt, sehen Nahkämpfer im Draft nicht mehr: Toxic Spores, Giftschuss, Frostschuss, Feuersturm, Blitzschuss (je mit Ausbau), Schnellfeuer, Scharfe Munition, Schlagkraft I–III und Blutdurst samt Ausbauten. Stattdessen gibt es Giftzahn, Frostklinge, Glühende Spitze, Elektroschocker, Leichter Griff, Schleifstein und Blutklinge. **Kettenblitz** (mit Ausbau Kettenreaktion) bleibt für alle, im 1-gegen-1 springt der Blitz aufs getroffene Ziel zurück. Reichweite wird in Feldern (36 px) ab dem Körperrand gemessen. Wände blockieren den Schlag. Der Schlag trifft auch Blöcke, Kisten, Fässer und Türme.

| Waffe | Form | Schaden | Reichweite | Rückstoß | Abklingzeit | Besonderheit |
| :--- | :--- | ---: | ---: | :--- | ---: | :--- |
| **Lötkolben** | gerader Stich | 50 | 3 Felder | stark | 1,4 s | |
| **Schwert** | 60°-Bogen | 30 | 3 Felder | wenig | 0,9 s | |
| **Hammer** | 90°-Bogen | 20 | 1 Feld | sehr stark | 1,1 s | Prallt das Ziel danach an Wand oder Decke: 0,8 s betäubt |
| **Flegel** | 360° rundum | 30 | 2 Felder | mittel | 1,2 s | |

**Parade** (Legendary): Ist der Schlag bereit (nicht auf Abklingzeit), schlägt die Waffe von selbst in Richtung eines gegnerischen Projektils, sobald es in Reichweite ist und auf dich zufliegt, und wirft es zurück. Der Schlag trifft dabei normal und startet die Abklingzeit. Ein manueller Schlag pariert ebenfalls. Gilt auch für Bots und online.

Das Powerup **Auto-Angriff** lässt Nahkämpfer von selbst zuschlagen und verkürzt bei Fernkämpfern das Feuerintervall um 35 %. Der Runden-Modifier **Brawl** verstärkt den Nahkampf und erscheint nur, wenn ein Nahkämpfer mitspielt.

Nahkampf-Karten (Pool **Nahkampf**, 19 Karten) wirken nur auf die Schläge der Nahkämpfer, siehe [Karten-Übersicht](#nahkampf-karten).

---

## 🏆 Lobby & Match-Regeln

Die Lobby hat mehrere Tabs. **Spieler 1 ist Host** und stellt Regeln, Map und Karten ein.

### Slots & Helden

- **2–6 Spieler**. Jeder Slot ab 2 ist **Bot** oder **Mensch**.
- Pro Slot gibt es eine Heldenreihe mit allen 7 Klassen und farbigen Icons. Menschen wählen selbst, der Host wählt für Bots.
- **Bereit**: Lokal meldet der Knopf alle Menschen bereit, online jeder Client sich selbst. Bots sind automatisch bereit. Gestartet wird erst, wenn alle bereit sind.

### Tab Charakter

- **Name** (bis 16 Zeichen), erscheint in Lobby, HUD und Statistik.
- **Fell-, Augen- und Hosenfarbe**.
- **Hauer**: Klein, Lang, Säbel, Doppelt, Stummel.
- **Lötspitze**: 8 Formen (Kegel, Meißel, Messer, Huf, Kugel, Diamant, Stern, Flamme) plus Glutfarbe.
- **Schussfarbe**.
- **Nahkampfwaffe**.
- **Körperbau** (unter Aussehen): Männlich oder Weiblich, für jede Klasse. Weiblich hat schmalere Schultern, Taille und breitere Hüfte, eine runde Oberweite mit Top und rundem Ausschnitt sowie Wimpern. Ohne gewähltes Oberteil trägt sie automatisch ein Top in der Oberteil-Farbe. ZUFÄLLIG lässt den Körperbau stehen.
- **Minirock** wird beim Voxel-Eber als ausgestellter Rock gezeigt.
- Die Vorschau zeigt alles live. Das Profil wird automatisch gespeichert und online an alle verteilt.

### Tab Regeln

Ganz oben stehen **Spielart**, **Modus** und **Map**, darunter Loadouts, Bot-Test und die übrigen Regeln.

| Einstellung | Bereich | Standard |
| :--- | :--- | :--- |
| Spielmodus | FFA, 2v2, 3v3, 2v2v2 | FFA |
| Punkte für Match-Sieg | 100–5000 | 500 |
| Punkte für Überleben (pro Runde) | 0–500 | 50 |
| Punkte pro Kill | 0–500 | 50 |
| Basis-HP-Faktor | 50–300 % | 100 % |
| Basis-Schaden pro Schuss | 1–200 | 22 |
| Karten-Draft | Wähle X von Y | 1 von 5 |
| Draft-Modifier | Blind pick, Random pick, Gamble | aus |
| Pre-Draft | 0–10 Picks vor Matchbeginn, optional zufällig | 0 (aus) |
| Spielfeld | eine der 23 Maps oder Zufällig | Zufällig |
| Runden-Modifier | Auswahl + Rate 0–200 % | alle, 100 % |

**Loadouts**: Der Host kann komplette Regel-Sets speichern, laden und löschen. Mitgeliefert sind **Standard**, **Schnell & Wild**, **Team 2v2** und **Chaos**.

### Tab Karten

- **Kartenpools** (Haupt-Tags) einzeln an- und ausschalten: Offensive, Defensive, Bewegung, Nahkampf. Mindestens einer bleibt aktiv. Die früheren Pools Kern und Chaos sind in Offensive bzw. Defensive aufgegangen.
- **Netzdiagramme** unter den Pools zeigen, wie sich alle verfügbaren Karten verteilen: auf die Haupt-Tags, je Haupt-Tag auf seine Sub-Tags und auf die Seltenheiten. So sieht man, ob es für alle Werte ähnlich viele Karten gibt.
- **Seltenheits-Prozente** für Common/Uncommon/Rare/Epic/Legendary (Standard 51,5 / 25 / 15 / 8 / 0,5), mit einer Nachkommastelle einstellbar. Die Summe wird automatisch normalisiert.
- **Karten sperren**: Gesperrte Karten kommen in keinem Draft mehr, nach Seltenheit sortiert. Karten aus abgeschalteten Pools stehen dort abgedunkelt als gesperrt („Pool aus“). Der Host kann sie einzeln wieder freigeben („freigegeben“); Ausbaukarten einer freigegebenen Grundkarte sind dann ebenfalls frei. Wird der Pool wieder eingeschaltet, verfallen die Einzelfreigaben.
- **Filter ▾** filtert die Kartenliste nach Haupt-Tags und Sub-Tags. Innerhalb einer Gruppe reicht ein Treffer (oder), Haupt- und Sub-Tags zusammen müssen beide passen (und).
- Die Lobby zeigt `Pool min. X/Held`, also wie viele Karten der kleinste Helden-Pool noch hat.

### Tab Levels

- Zeigt **die Maps, die zur Einstellung passen**, mit Vorschaubild: bei Spielart *Seitenansicht* die Seitenansicht-Level, bei *Draufsicht* die Arena-Karten, bei *Beides* beide (Kachel-Markierung SEITE / DRAUFSICHT), im Modus *Horde* die Horden-Gebiete in Spielreihenfolge (GEBIET 1–4, nur zum Ansehen, nicht abschaltbar). Seitenansicht-Bilder rendert das Spiel beim ersten Öffnen des Reiters aus dem Level-Generator, Arena-Karten werden aus ihrem Raster von oben gemalt. Neue Maps tauchen automatisch auf.
- **Klick aufs Bild** öffnet die Großansicht mit Beschreibung. Mit `←`/`→` blättern, mit `Esc` oder Klick daneben schließen.
- Der Schalter neben dem Namen **schaltet ein Level ab**. Abgeschaltete Levels kommen bei **Zufällig** nicht mehr dran und sind unter Regeln → Spielfeld ausgegraut. Das gilt auch für Arena-Karten. **ALLE AN** / **ALLE AUS** schalten alle gerade angezeigten Karten auf einmal, die der anderen Ansicht bleiben, wie sie sind. Ist kein Level aktiv, lässt sich das Match nicht starten.
- Die Auswahl gehört zu den Lobby-Regeln: Sie landet im Preset **Last** und in gespeicherten Loadouts, und der Host überträgt sie an alle Clients.
- Die Vorschau zeigt einen Beispiel-Aufbau. Zusätzliche Plattformen und Objekte werden jede Runde neu verteilt.

### Tab Powerups

- Zeigt **alle Powerups** (Heilung, Schutz, Schaden, Dauerfeuer, Auto-Angriff, Multishot, Unsterblichkeit, Rache, Unsichtbar) so, wie sie in der Arena liegen, mit ihrer Wirkung.
- Der Schalter **schaltet ein Powerup ab**. Abgeschaltete Powerups erscheinen weder zufällig in der Arena noch aus Kisten noch beim Modifier **Powerup-Regen**. **ALLE AN** / **ALLE AUS** schalten alles auf einmal.
- Sind alle aus, laufen die Runden ohne Powerups: Der Modifier Powerup-Regen wird nicht gezogen und die Powerup-Karten (Powerup-Verstärker, Powerup-Magnet) kommen nicht in den Draft. Auto-Angriff erscheint zusätzlich nur, wenn Nahkampf an ist.
- Die Auswahl gehört zu den Lobby-Regeln: Sie landet im Preset **Last** und in gespeicherten Loadouts, und der Host überträgt sie an alle Clients. Alte Loadouts haben alle Powerups an.

### Ablauf einer Runde

0. **Pre-Draft** (nur wenn eingestellt): Vor der ersten Runde draftet jeder Spieler seine Startkarten.
1. **3-Sekunden-Countdown**. Die Kamera startet nah an deinem Eber, der aus einem Portal in Klassenfarbe kommt, und zoomt dann heraus.
2. Kämpfen, bis nur noch ein Spieler (bzw. ein Team) lebt. Kills geben sofort Punkte, der Überlebende den Überlebensbonus.
3. Beim entscheidenden Tod läuft eine kurze **Kill-Cam** in Zeitlupe.
4. Die Verlierer wählen Karten, dann startet die nächste Runde.
5. **Sudden Death**: Dauert eine Runde nach dem Countdown länger als **38 s**, steigt Lava auf. Der Zähler startet bei jedem Tod neu. Die Lava hält knapp unter der höchsten Plattform an.

**Weiterspielen**: Nach dem Match-Sieg kann der Host **WEITERSPIELEN** wählen. Punkte und Decks bleiben, das Ziel steigt um 30 %.

### MVP-Ehrungen

Am Matchende zeigt der Win-Screen unter der Match-Statistik bis zu **8 Ehrungen**. Pro Spieler gibt es höchstens 2 (bei 2 bis 3 Spielern etwas mehr), der MVP-Titel zählt nicht mit. Spaß-Ehrungen erscheinen höchstens zwei.

| Ehrung | Wer bekommt sie |
|---|---|
| **MVP** | Bester Gesamtwert aus Punkten, Kills, Schaden, Barriere, Heilung, Rundensiegen und Toden |
| **Schadenskönig** | Meister Schaden |
| **Serienkiller** | Längste Kill-Serie ohne eigenen Tod (ab 3) |
| **Beste Karte** | Karte, mit der ihr Besitzer am stärksten war: Schadensanteil und Rundensiege in den Runden mit der Karte, plus die Verbesserung gegenüber den Runden davor |
| **Scharfschütze** | Beste Trefferquote (ab 20 Schüssen und 25 %) |
| **Erstes Blut** | Am häufigsten den ersten Kill einer Runde (ab 2) |
| **Fähigkeiten-Ass** | Meister Fähigkeitsschaden (ab 100) |
| **Nahkampf-Metzger** | Meister Nahkampfschaden (ab 60) |
| **Bollwerk** | Meister Barriere-Schaden (ab 60) |
| **Sanitäter** | Meiste Heilung (ab 60) |
| **Überlebenskünstler** | Am häufigsten bis zum Rundenende überlebt (ab 2) |
| **Haarscharf** | Runde mit höchstens 20 % Leben gewonnen |
| **Größter Pechvogel** *(Spaß)* | Meiste Tode (ab 2), bei Gleichstand mehr eingesteckter Schaden |
| **Tollpatsch** *(Spaß)* | Tode ohne gegnerischen Schützen (Lava, Absturz, eigene Schüsse) |
| **Kugelfang** *(Spaß)* | Am meisten Schaden eingesteckt |

Online berechnet der Host die Ehrungen und schickt sie mit dem Match-Ende an alle Clients.

---

## 👥 Spielmodi

| Modus | Spieler | Teams | Aufteilung |
| :--- | :--- | :--- | :--- |
| **FFA** | 2–6 | jeder für sich | jeder Slot ist ein Team |
| **2v2** | 4 | 2 | 1+2 gegen 3+4 |
| **3v3** | 6 | 2 | 1+2+3 gegen 4+5+6 |
| **2v2v2** | 6 | 3 | 1+2 / 3+4 / 5+6 |

- Eine Team-Runde endet erst, wenn nur noch **ein Team** lebt.
- **Kein Freundschaftsfeuer**, auch nicht durch Flächen, TNT oder reflektierte Schüsse. Teamkollegen blocken gegnerische Schüsse körperlich.
- **Eigene Explosionen** machen nur 50 % Schaden an dir selbst.
- Team-Punkte sind die Summe der Spielerpunkte. Nach einer verlorenen Runde draften alle Mitglieder der Verliererteams.
- Teamfarben: ROT, BLAU, GRÜN.

### Spielart: Seitenansicht, Draufsicht (Arena, Beta) oder Beides

Im Tab **Regeln** unter *Spielmodus & Spielfeld* wählt der Host die **Spielart**: *Seitenansicht* (klassisch), *Draufsicht* (Arena) oder *Beides*. Die Spielart gilt für FFA und alle Teammodi, wird online übertragen und im Loadout gespeichert. Die Horde spielt immer in der Draufsicht.

- **Beides:** Jede Runde wird zufällig (50/50) Seitenansicht oder Draufsicht gewürfelt, höchstens zwei Runden in Folge in derselben Ansicht. Die Karte kommt aus den aktiven Leveln der gewürfelten Ansicht (Reiter **Levels**); ist eine Ansicht dort ganz abgeschaltet, kommt nur die andere dran. Eine feste Map gilt in ihrer Ansicht, Runden der anderen Ansicht nehmen eine zufällige Karte. Level-Modifier richten sich nach der Ansicht der Runde.

- **Ansicht:** schräg von oben in einfachem Voxel-3D. Effekte, Zonen, Powerups und Kugeln liegen als 2D-Ebene passgenau auf dem Boden.
- **Steuerung:** `W` `A` `S` `D` laufen in alle Richtungen, die Maus zielt, `Leertaste` springt. Alle anderen Tasten bleiben gleich.
- **Höhe:** Springen ist ein echter Sprung in die Höhe. Niedrige Deckung (eine Schicht) kann man überspringen und darauf stehen, halbhohe und hohe Mauern nur mit viel Sprungkraft. Kugeln fliegen in Schusshöhe und fliegen über Deckung, wenn der Schütze höher steht. Hinter Mauern sieht man die Schweine als Umriss in Teamfarbe.
- **Karten:** Alle Karten bleiben gleich. Sprungkraft, Luftsprünge und Schwerkraft wirken auf die Sprunghöhe. *Projektil-Schwerkraft* (Leichtes/Schweres Geschoss, Mörser) hat in der Arena noch keine Wirkung, Kugeln fliegen flach.
- **Kamera:** fester Zoom, sie zoomt nicht heraus. Sie folgt dem eigenen Schwein (lokal zu zweit: beiden) und bleibt innerhalb der Karte. Gegner außerhalb des Bildes zeigt ein Randpfeil in Teamfarbe.
- **Erhöhungen, Rampen, Stege:** Erhöhungen haben oben Boden und seitlich Felswände. Rampen führen ohne Sprung hinauf, ihre höheren Teile kann man von der Seite nicht betreten. Unter Holzstegen läuft man durch, oben läuft man darüber. Wer von einer Kante läuft, fällt herunter.
- **Maps:** zufällig eine von zwölf Arenen. Autoscroll-Strecken (siehe Autoscroll unten): *Rennstrecke* (Insel, Slalom, drei Spuren) und *Bergrennen* (Hügel mit Rampen, Turmbrücke, Felsbuckel-Slalom). Dazu *Hafen* (Holzstege zwischen sechs Türmen, Kistenstapel) und *Festung* (Wehrgang mit Toren und Rampen, Bergfried mit Stegen zu den Mauern). Kompakt: *Burghof*, *Kistenlager*, *Ruinen*. Groß und offen (etwa die vierfache Fläche): *Weite Steppe*, *Marktplatz*, *Canyon*, *Hochplateau* (große Erhöhung in der Mitte mit vier Rampen, erhöhte Randplattform), *Stegwerk* (fünf Türme mit Holzstegen). Wände gibt es gerade und schräg, Boden und Mauern haben 32×32-Pixeltexturen. Im Reiter **Levels** lassen sich einzelne Arenen abschalten, unter Regeln → Map auch eine feste Arena wählen.
- **Karteneditor:** *Optionen → KARTENEDITOR*. Links malen, rechts radieren, Mausrad zoomt, mittlere Maustaste oder Leertaste + Ziehen verschiebt. Werkzeuge: Pinsel (B, 1×1 bis 5×5), Rechteck (R), Füllen (F), schräge Wand (W, von Ecke zu Ecke ziehen, Rechtsklick löscht). Kacheln: Boden, Deckung, Halbmauer, Mauer, Kiste, Spawn, Erhöhung 1 bis 3, Steg, Rampe (Richtung wählen; eine Reihe gleicher Pfeile endet an der Erhöhung). Symmetrie spiegelt links/rechts, oben/unten, vierfach oder um den Mittelpunkt, Rampen drehen mit. Strg+Z / Strg+Y, Strg+S speichert. Die Prüfung zeigt, ob alle Spawns erreichbar sind. Vorlagen laden eine eingebaute Arena als Kopie. Gespeichert wird unter `user://arena_maps/`. Mit *Im Zufallspool* kommt die Karte in die Arena-Auswahl, online schickt der Host sie an alle. **TESTEN** speichert und startet eine Runde auf der Karte mit den Spielern und Bots der letzten Lobby; ESC → Hauptmenü beendet den Test.
- **Seitenansicht-Level im Editor:** Im Karteneditor führt *Zum Seitenansicht-Editor* zu den klassischen Leveln. Jedes Level lässt sich laden und ändern: Plattformen, Einweg-Stege, Kistenblöcke und Gruben waagrecht ziehen, Wände als Rechteck, Stacheln, Sprungfedern und Mystery-Blöcke anklicken, Röhrenpaare mit zwei Klicks. Mit *Objekt setzen* kommen Wippen, Kettenplattformen, Fahrplattformen, Drehbalken, Häuser, Pyramiden, Treppen, Kistenketten, Gitterzäune, Schrägen, Kugel-Objekte sowie Schalter, Türen/Falltüren, Laser und Orbitalschläge dazu (verbunden über die Kanalnummer; die gespiegelte Seite bekommt Kanal + 100). Ein ausgewähltes Objekt zeigt unter *Eigenschaften* alle Werte (z. B. Kettenlänge, Wippenbreite, Drehtempo und Stil, Kistengrößen); Verschieben per Ziehen, Löschen per Rechtsklick oder Entf. Gespiegelte Level zeigen die automatische Spiegelung blass. *Speichern* legt eine geänderte Fassung an, die das Spiel statt des eingebauten Bauplans nutzt; *Original* stellt ihn wieder her. *Als neues Level* legt ein eigenes Level an, das im Levels-Tab der Lobby erscheint. *Zufällige Extras* schaltet die zufälligen Zusatzplattformen, Kistenhaufen und Eisflächen des Levels ab. Gespeichert wird unter `user://side_levels/`, online schickt der Host den Bauplan vor jeder Runde an alle.
- **Runden-Modifier:** nur Sturmwind, Mondgravitation, Schwerewelt, Mini-Chaos, Schadensrausch, Turboschweine, Luftakrobatik, Regeneration, Startschild und Zone. Die übrigen sind in der Arena vorerst aus.

### Challenge-Runden

Lobby-Regel **Challenge-Runden** (Regeln-Tab, unter Spielmodus & Spielfeld): *Aus*, *Selten* (25 % pro Runde) oder *Oft* (45 %). Einzelne Challenges lassen sich abschalten. Nie in der ersten Runde, nie zweimal hintereinander, nie im Stechen und nicht in der Horde. Der Sieger (bzw. sein Team) bekommt die normalen Rundenpunkte, die Verlierer draften wie immer. **Kills zählen in jeder Challenge normal.** Challenge-Runden laufen ohne Level-Modifier und ohne Sudden Death.

| Challenge | Karte | Ziel | Tod |
| :--- | :--- | :--- | :--- |
| **Wettrennen** | Rundkurs (Draufsicht) | 3 Runden im Uhrzeigersinn, alle Tore der Reihe nach. Zeitlimit 3:00 | nach 2 s am letzten Tor |
| **König des Hügels** | normale Karte | Zone halten, nur wer allein drin ist, füllt seine Leiste (20 s). Zeitlimit 1:30 | nach 2 s am Spawn |
| **Bällebad** | Bällebad (Draufsicht) | Jeder startet in einer Ecke, die Karte wird mit Bällen geflutet. Nach 60 s gewinnt, wer die meisten Bälle in seiner Ecke hat | nach 2 s in der eigenen Ecke |
| **Münzjagd** | normale Karte | 60 s Münzen sammeln, 7 liegen immer bereit | nach 2 s, verliert die Hälfte (liegt 14 s herum) |
| **Lava-Aufstieg** | Lavaturm | Die Lava hält nicht an. Wer zuerst die Flagge auf dem Gipfel berührt, gewinnt | raus (normales Ausscheiden) |
| **Hordenwelle** | Arena-Karte (Draufsicht) | 75 s gegen die Horde, wer die meisten Gegner erlegt (Riese = 3), gewinnt | nach 2 s am Spawn |

Code: `scripts/challenge/` (ChallengeDefs, ChallengeDirector, ChallengeHud). Laufzeit-Test mit Bots: `godot --headless res://tools/challenge_runtime_test.tscn` (optional `-- race hill ...`).

---

## 🃏 Karten-Draft

Nach jeder verlorenen Runde bekommt jeder Verlierer **Y zufällige Karten** und wählt **X** davon. Bei mehreren Picks wird nach jeder Wahl ein **komplett neues Angebot** gezogen, ohne die Karten der vorherigen Angebote (reicht der Pool nicht, dürfen sie wieder kommen). Online zieht der Host jedes Angebot. Karten stapeln sich über das ganze Match. Jede Karte gibt es pro Spieler nur einmal.

- **Seltenheit**: Common (grau), Uncommon (grün), Rare (blau), Epic (lila), Legendary (gold). Der **äußere Rahmen** zeigt die Seltenheit, der **innere** die Effektfarbe.
- **Icons**: Jede Karte hat ein kleines animiertes Icon passend zum Effekt.
- **Werte-Zeilen**: Jeder Effekt einer Karte steht in einer eigenen Zeile.
- **Mechanik-Tooltips**: Beim Hovern erklärt die Karte Begriffe wie Gift, Frost, Durchschlag, Rüstung, Reflexion, Turm oder Drohne.
- **Klassen-Badge**: Klassenkarten sind markiert und erscheinen nur beim passenden Helden.
- **Evolution-Banner**: Talentbaum-Karten sind als Evolution markiert.
- **Voraussetzungen**: Karten, die eine Mechanik nur verstärken, erscheinen erst, wenn du sie schon hast (z. B. Turm-Panzerung nur mit Turm, Schild-Upgrades erst ab 25 Schild). Solche Karten tragen im Draft, in der Lobby und im Tab-Blatt die orange Zeile **BENÖTIGT: …**; der Tooltip listet unter **FREISCHALTUNG** alle Bedingungen (Klasse, Grundkarte und Zweig bei Evolutionen, Mechanik mit Beispielkarten).
- **Tab halten** zeigt während der Wahl dein Charakterblatt mit den Werten der nächsten Runde.

### Pre-Draft

Lobby-Regel unter **Tab Regeln → Karten-Draft**. Steht **Pre-Draft** auf mehr als 0, draften alle Spieler (auch Bots) direkt nach dem Start nacheinander so viele Karten, bevor die erste Runde beginnt. Jeder Pick bekommt wie sonst ein neues Angebot mit Y Karten, die Draft-Modifier gelten auch hier. Mit dem Schalter **Pre-Draft-Karten zufällig wählen** werden diese Picks automatisch zufällig gezogen (online zieht der Host), die Drafts nach den Runden bleiben normal. Die Regel landet in **Last**, in Loadouts und wird online an alle übertragen. **Weiterspielen** startet keinen neuen Pre-Draft.

### Draft-Modifier

- **Draft-Steuerung**: A/D (oder Pfeiltasten) markiert eine Karte, die Leertaste wählt sie. Maus und Zifferntasten gehen weiterhin.
- **Blind pick**: Nur online gegen Menschen. Die anderen sehen nur Kartenrückseiten, die Wahl wird als „Karte verdeckt“ gezeigt. Lokal gegen Bots ohne Wirkung.
- **Random pick**: Es wird automatisch eine Zufallskarte gezogen. Online zieht der Host.
- **Gamble**: Die Karten liegen verdeckt, die Rückseite zeigt die Farbe der Seltenheit. Von links nach rechts wird einzeln aufgedeckt: Entweder nimmt man die offene Karte oder dreht die nächste um. Dann läuft ein Feuerbalken von unten nach oben über die offene Karte, danach ist sie verkohlt und weg. Die letzte Karte muss man nehmen. Steuerung: Mit A/D markiert man die offene Karte oder die nächste Rückseite, die Leertaste nimmt bzw. dreht um. Enter nimmt direkt die offene Karte, Klick und Zifferntasten gehen auch. Nach dem Pick werden kurz alle übrigen Karten aufgedeckt. Bots sehen die Rückseiten auch und drehen weiter, wenn rechts eine seltenere Karte liegt. Mit Random pick ohne Wirkung. Bei mehreren Picks gilt das für jedes neue Angebot.

### Elemente & Synergien

Es gibt vier Elemente: **Feuer**, **Gift** (Gift-Ticks und Giftwolken), **Frost** und **Blitz**. Jeder Eber hat **2 Element-Slots**. Ignis (Feuer), Volt (Blitz) und Spore (Gift) haben ihr Grundelement schon in Slot 1.

- **Karte „Element“**: Solange ein Slot frei ist, liegt im Draft zusätzlich eine 4. Karte „Element“. Sie öffnet einen Unter-Draft mit den vier Elementkarten. Jede Karte zeigt unten, was sie ergibt (**ERSTES ELEMENT**, **ERGIBT: Plasma**, **REIN: Lauffeuer**). Die Wahl zählt als Pick. Im Gamble-Modus gibt es die Element-Karte nicht.
- **Grundkarte**: Die erste Karte eines Elements bringt die passende Schusskarte mit (Feuersturm, Giftschuss, Frostschuss, Blitzschuss), Nahkämpfer bekommen das Nahkampf-Gegenstück.
- **Element-Boni**: Kleine Elementkarten (z. B. Giftklinge, Frostartig) erscheinen erst, wenn du das Element hast (orange **BENÖTIGT**-Zeile).

| Kombination | Elemente | Wirkung im eigenen Build |
| :--- | :--- | :--- |
| Gasbrand | Feuer + Gift | Giftwolken brennen mit, Feuer auf Vergiftete lässt das Gift explodieren |
| Dampf | Feuer + Frost | Brand verlangsamt kurz, Thermoschock wird stärker |
| Plasma | Feuer + Blitz | Kettenblitze entzünden, Blitz auf Brennende schleudert Funken |
| Giftreif | Gift + Frost | Gift verlangsamt kurz, vergiftet + verlangsamt tickt 40 % schneller |
| Neurotoxin | Gift + Blitz | Kettenblitze vergiften, Blitz auf Vergiftete verdoppelt die Betäubung |
| Supraleiter | Frost + Blitz | Blitz auf Verlangsamte: 5 s lang 30 % verwundbarer |
| Lauffeuer | Feuer rein | Brand stapelt bis dreifach und springt über, Feuerböden halten länger |
| Seuche | Gift rein | Giftstapel addieren sich, größere Wolken, Vergiftete platzen beim Tod |
| Permafrost | Frost rein | 3 Frost-Treffer in 2 s frieren ein, der nächste Treffer zersplittert (+50 %), Eisspuren halten doppelt |
| Hochspannung | Blitz rein | Treffer laden auf, bei 5 Ladungen Entladung (20 Schaden, 0,4 s Betäubung), Blitzzonen 40 % größer |

**Welt-Reaktionen** (Lobby-Regel **Element-Reaktionen**, Standard an): Elemente verschiedener Spieler reagieren auch miteinander, am Ziel (z. B. Feuer auf Vergiftete) und in Flächen (Feuer + Giftwolke = Gasexplosion, Feuer + Eis = Dampfwolke, Blitz + Feuer = Plasmafeld, Frost + Gift = Giftreif, Blitz + Gift = Giftgewitter, Blitz + Eis = Strom über die Eisfläche). Pro Ziel gibt es eine Abklingzeit von 1,5 s, Einfrieren macht danach kurz immun. Ist die Regel aus, wirken nur die Kombinationen im eigenen Build.

**Neue Frost-Karten**: Eissplitter (+15 % Schaden gegen Verlangsamte), Tiefkühlung (stärkere Verlangsamung), Splitternova (Frostnova verschießt Splitter), Gletscherhaut (schneller und Heilung auf eigenem Eis), Kältepanzer (Rüstung, Nahkampf-Angreifer werden verlangsamt).

### Kartenstatistik & automatische Aufwertung

Das Spiel führt im Hintergrund `card_statistics.json` mit **Pickrate**, **Killrate** und **Winrate** jeder Karte, inklusive Nahkampfschaden. Alle 3 abgeschlossenen Matches wird ausgewertet. Eine Karte steigt um eine Seltenheit auf, wenn sie:

- mindestens 8 Match-Samples hat,
- seit der letzten Aufwertung 8 Matches vergangen sind,
- eine geglättete Winrate von mindestens 55 % hat und
- mindestens 15 Prozentpunkte über dem Schnitt ihrer Seltenheit liegt.

Pro Auswertung steigt höchstens eine Karte je Seltenheit auf, Legendary ist das Maximum. Abgewertet wird nie. Wer die Datei löscht, setzt alle Seltenheiten zurück.

---

## 📚 Karten-Übersicht

Insgesamt gibt es über **230 Karten**: rund 210 in den Pools Offensive, Defensive und Bewegung, dazu 19 im Pool Nahkampf. Hier die wichtigsten Gruppen.

### Kartenpools

| Pool | Inhalt | Beispiele |
| :--- | :--- | :--- |
| **Offensive** | Schaden, Munition, Projektile, Elemente | Splittergeschoss, Panzerbrecher, Kettenblitz (Ausbau Kettenreaktion), Leichtes/Schweres Geschoss, Mörser, Notvorrat, Fokuskristall, Weitstrahler, Kraftladung, Schlagkraft, Munitionsgurt, Gefechtsbereit |
| **Defensive** | Leben, Schild, Rüstung, Reflexion, Barriere, Größe | Sanitäter, Bollwerk, Zweites Herz, Tank-Panzerung, Stachelweste, Dornenthron, Riese, Wandelnder Koloss |
| **Bewegung** | Tempo, Sprünge, Dash, Größe | Federstiefel, Windschatten |
| **Nahkampf** | Nur für den `E`-Schlag | Schleifstein, Frostklinge, Parade, Meister der Werkbank |

Weitere bekannte Karten: **Lebensquell** (Max-HP), **Scharfe Munition** (+20 % Schaden), **Abpraller**, **Splittergeschoss** (+1 Projektil), **Flipper-Modus**, **Blutdurst** (Lebensraub), **Homing Micro-Seekers** (Zielsuche), **Cluster Warhead**, **Ricochet Frenzy**, **Martyrdom Shockwave** (Explosion beim K.O.), **Chronos Drive**. Munition und Nachladen verbessern **Quick Draw**, **Schnellfeuer**, **Gatling Surge**, **Großes Magazin**, **Schnelllader**, **Taktisches Magazin** und **Feldwartung**.

**Duplikat-Abgleich (28.10.2026):** Pro Effekt soll es je Seltenheit möglichst nur eine Karte geben. Strikt schwächere Karten derselben Seltenheit wurden entfernt (u. a. Gummigeschoss, Wirbelsturm, Treffsicher, Schnelle Hände, Vitaler Kern, Panzerplatte, Raketenschuh, Leichtgewicht, Giftkern, Explosionswelle, Instabiler Kern). Notvorrat ist jetzt Uncommon, Quick Draw Rare, Martyrdom Shockwave Epic. Ähnliche Karten sind **Evolutionen** einer Grundkarte: Sie kommen nur, wenn man die Grundkarte besitzt, wer einen Zweig nimmt, bekommt den anderen nicht mehr, und die Werte kommen zur Grundkarte dazu.

| Grundkarte | Zweig A | Zweig B |
| :--- | :--- | :--- |
| Abpraller (Common, +1) | Bouncy Balls (Uncommon, +1, +15 % Projektilgeschw.) | Stabilisator (Uncommon, +1, +15 % Projektilgröße) |
| Flipper-Modus (Rare, +3 Abpraller) | Ricochet Frenzy (Epic, +3, +15 % Projektilgeschw., +20 % Schaden pro Abpraller) | Flummi-Kern (Epic, +3, +15 % Projektilgröße) |
| Scharfe Munition (Common, +20 % Schaden) | Wuchtgeschoss (Uncommon, +20 %) | Heavy Bullets (Uncommon, +15 %, +40 % Projektilgröße) |
| Scharfschütze (Common, +30 % Projektilgeschw.) | Railgun-Munition (Uncommon, +30 %, +8 % Schaden) | Fast Forward (Uncommon, +30 %, +12 % Tempo) |
| Splittergeschoss (Uncommon, +1 Projektil) | Splitterladung (Rare, +1, enge schnelle Salve) | Leichte Schrotflinte (Rare, +2, breit) |
| Zäher Kern (Common, +24 % Max HP) | Lebensquell (Uncommon, +20 %) | Schwarzes Herz (Uncommon, +30 %, −6 % Tempo) |
| Regenerationsmodul (Common, +1 HP/s) | Regenerationsserum (Uncommon, +1 HP/s) | Sanitäter (Uncommon, +0,6 HP/s, +30 Max HP) |
| Blutdurst (Uncommon, +12 % Lebensraub) | Vampiric Leech (Rare, +15 %) | Vampirklinge (Rare, +20 %, −10 % Max HP) |
| Kompaktkern (Common, −10 % Größe) | Kompakte Statur (Uncommon, −5 %, +8 % Tempo) | Schlanker Körper (Uncommon, −10 %, +10 % Sprungkraft) |
| Feather Shoes (Uncommon, +1 Luft-Sprung) | Federstiefel (Rare, +1 Luft-Sprung, +10 % Sprungkraft) | – |
| Verstärkte Deckung (Uncommon, +0,3 s Barriere) | Ausdauerbarriere (Rare, +0,3 s, −10 % Abklingzeit) | – |
| Weitstrahler (Common, +25 % Fähigkeitsgröße) | Flächenbrecher (Common, +50 % Fähigkeitsgröße) | – |
| Kraftladung (Common, +25 % Fähigkeitsschaden) | Überladung (Common, +50 % Fähigkeitsschaden) | – |
| Powerup-Verstärker (Common, +25 % Powerup-Wirkung) | Powerup-Magnet (Common, +25 % Powerup-Wirkung, +2 Felder Sammelreichweite) | – |

Max-HP- und Schild-Boni auf Karten wurden verdoppelt, damit man nicht zu schnell stirbt.

**Stufenkarten (3 Stufen, Offensive):** Jede Stufe erscheint erst, wenn die vorige im Deck ist. Stufe I ist Common, II Uncommon, III Rare. Die Boni stapeln sich, Schaden multipliziert sich (drei Stufen Schlagkraft = ×2,2).

| Linie | Stufe I | Stufe II | Stufe III |
| :--- | :--- | :--- | :--- |
| Schlagkraft | +30 % Schaden | +30 % Schaden | +30 % Schaden |
| Munitionsgurt | +2 Munition | +2 Munition | +2 Munition |
| Gefechtsbereit | +15 % Schaden, +1 Munition | +15 % Schaden, +1 Munition | +15 % Schaden, +1 Munition |

### Sub-Tags

Jede Karte hat neben ihrem Pool (Haupt-Tag) beliebig viele **Sub-Tags**. Sie werden automatisch aus den Kartenwerten abgeleitet und erscheinen in der Lobby-Kartenliste unter dem Titel.

| Haupt-Tag | Sub-Tags |
| :--- | :--- |
| **Offensive** | Schaden, Feuerrate (inkl. Munition/Nachladen), Projektil, Bounce, Durchschlag, Zielsuche, Mehrfachschuss, Explosion, Element, Begleiter |
| **Defensive** | Leben, Heilung, Schild, Barriere, Rüstung, Reflexion |
| **Bewegung** | Tempo, Sprung, Dash, Schwerkraft, Größe (kleiner oder größer) |
| **Nahkampf** | Klinge, Reichweite, Schlagtempo, Rückstoß, Kontrolle, Elementarhieb |
| **Allgemein** | Fähigkeit (Heldenfähigkeit), Powerup (verstärkt eingesammelte Powerups), Unique (eigene Spezialmechanik) |

Sub-Tags gelten poolübergreifend: Eine Defensive-Karte kann z. B. auch „Tempo“ haben.

Kartentexte nutzen für gleiche Effekte immer dieselben Begriffe: **Tempo** (Laufgeschwindigkeit), **Max HP**, **Schild**, **Schaden**, **Feuerrate**, **Munition**, **Projektilgeschwindigkeit**, **Projektilgröße**, **Abpraller**, **Durchschlag**, **Explosionsradius**, **Sprungkraft**, **Luft-Sprung**, **Größe**, **Giftstapel**, **Giftschaden**, **HP/s Regeneration** sowie **Dash-**, **Barriere-**, **Fähigkeits-** und **Nahkampf-Abklingzeit**.

### Klassenkarten (je 3 pro Held)

| Held | Klassenkarten |
| :--- | :--- |
| **Ignis** | Nachbrenner, Sprengkern, Überhitzung |
| **Volt** | Overclock, Statisches Feld, Kinetische Ladung |
| **Spore** | Virulenter Stamm, Mycelnetz, Toxische Blüte |
| **Nova** | Schwerkraftkern, Leerer Raum, Supernova |
| **Klinge** | Wirbelklinge, Klingenreflexe, Duellklinge |
| **Bastion** | Energieschild, Feldwartung, Bastionsfestung |
| **Phantom** | Schattenklinge, Schattenlauf, Todeskuss |
| **Blutritter** | Aderlass, Dickes Blut (Kugeln +50 % Schild), Blutgier |
| **Flocke** | Frostatem, Eiszapfenhagel (jeder 3. Schuss ein Splitter), Lange Lanze (Evolutionen Lanzenfächer / Frostbahn), Glatteis, Ewiger Winter |

### Fähigkeitskarten (je 4 pro Held)

Eine Grundkarte (Rare) mit zwei exklusiven Evolutionen (Epic) und eine Einzelkarte (Uncommon). Evolutionen erscheinen erst mit der Grundkarte, und nur ein Zweig ist wählbar.

| Held | Grundkarte | Evolution A | Evolution B | Einzelkarte |
| :--- | :--- | :--- | :--- | :--- |
| **Ignis** | Raketentriebwerk | Napalm-Landung | Splitterlandung | Kurze Zündschnur |
| **Volt** (Kugelblitz) | Hochspannung | Sprungziel | Entladung | Restladung |
| **Spore** (Giftpilz) | Pilzgarten | Ätzender Nebel | Klebsporen (C: Sprungpilz) | Sporenvorrat |
| **Nova** (Gravitationsstoß) | Druckwelle | Wandschlag | Umkehr | – |
| **Klinge** (Klingenbumerang) | Wurfklinge | Blutung | Fangen | – |
| **Bastion** (Magnethaken) | Langer Haken | Kettenschlag | Magnetfeld | – |
| **Phantom** (Köder) | Doppelgänger | Sprengköder | Platztausch (C: Lähmendes Mal) | Lange Schatten |
| **Blutritter** (Blutbersten) | Weites Bersten | Blutspende (heilt 30 % des Schilds) | Blutregen (Getroffene lassen Blutkugeln fallen) | Blutschneise (Dash, Epic) und Blutsog (Ulti, Epic) |

**Zeitschläger** (Nahkampf mit Uhrenpendel = Flegel, 30 Schaden, Rundumschlag) hat 7 Klassenkarten und 2 Familien mit je 2 Evolutionen: **Taktgeber** (Common, +15 % Nahkampftempo, +10 % Tempo), **Schweres Pendel** (Uncommon, +30 % Nahkampfschaden, +0,5 Felder, −10 % Tempo), **Schnellladung** (Uncommon, −15 % Ulti- und −10 % Fähigkeits-Abklingzeit), **Stundenschlag** (Epic, Taktschlag schon jeden 2. Treffer, 2,5 s lang), **Ewige Sekunde** (Epic, Zeitstopp +50 % Dauer), **Zinseszins** (Epic, gestaute Treffer schlagen mit 150 % ein). Familie Zeitblase: **Große Blase** (Rare, +30 % Radius, +25 % Dauer) → A **Zerfall** (8 Schaden/s in der Blase) oder B **Eigenzeit** (+30 % Tempo in der eigenen Blase). Familie Rückspul: **Lange Erinnerung** (Rare, 1 s weiter zurück, −15 % Dash-Abklingzeit) → A **Zeitriss** (Explosion an der verlassenen Stelle, 25 Schaden) oder B **Reinigung** (entfernt Gift, Brand und Verlangsamung, +20 Schild).

**Dash- und Ulti-Karten (neu):** Volt: **Dreifachblitz** (Rare, +1 Blitzschritt-Ladung, +20 % Teleportweite) mit den Evolutionen **Kettenblink** (Kettenblitz am Zielpunkt) und **Gewitterspur** (Blitzzone am Zielpunkt); **Starkstrom** (Rare, Überladung +30 % Dauer, −10 % Ulti-Abklingzeit) mit **Dauerblitz** (Blitzschritt lädt in der Überladung dreimal so schnell) und **Schockring** (Schockwelle am Ende). Phantom: **Schattenschnitt** (Epic, der Dash sticht alle Gegner auf dem Weg, 60 % Schaden) und **Blutspur** (Epic, ein Kill in der Nachtjagd gibt die halbe Ulti-Abklingzeit zurück). Für alle Helden mit Ulti: **Ulti-Akku** (Uncommon, −15 % Ulti-Abklingzeit).

**Dash- und Ulti-Karten der übrigen Helden** (Grundkarte Rare, Evolutionen Epic):

| Held | Dash-Grundkarte → Evolutionen | Ulti-Grundkarte → Evolutionen | Einzelkarte |
| :--- | :--- | :--- | :--- |
| **Ignis** | Glutspur → Zündung (Explosion am Dash-Ende) | Meteorregen (+2 Meteore) → Komet (ein riesiger Einschlag) / Flächenbrand (größeres, längeres Feuer) | – |
| **Spore** | Sporenschleier → Symbiose (Heilung in der Dash-Wolke) | Seuchenherd → Pandemie (Gift springt über) / Verwesung (keine Heilung im Nebel) | – |
| **Nova** | Schwebeflug → Phasenhülle (Kugeln fliegen beim Gleiten durch Nova) | Ereignishorizont → Schwarzes Loch (verschluckt Kugeln, spuckt sie als eigene aus) / Doppelstern | Massenanziehung |
| **Klinge** | Stoßklinge → Klingenfluss (Treffer lädt den Dash ganz auf, alle 4 s) | Geschliffene Klingen → Echowirbel / Blutrausch | Tanzschritt |
| **Bastion** | Schwerer Rammbock → Prellbock (Wandaufprall betäubt, +25 Schild) | Verstärkte Emitter → Schutzkuppel / Pulsfeld (C: Wanderfestung) | Notfallprotokoll |
| **Druide** | Lange Ranke → Fesselranke / Rankenkletterer | Urkraft → Raserei (Treffer verlängern) / Dornenfell (Schaden zurückwerfen) | – |

**Druide (Wurzelwall)** hat statt 3 Klassen- und 4 Fähigkeitskarten 4 Wandkarten plus 3 Evolutionen:

| Karte | Seltenheit | Wirkung |
| :--- | :--- | :--- |
| **Wurzelwerk** | Uncommon | Wände +30 % größer |
| **Immergrün** | Uncommon | Wände halten 40 % länger |
| **Schnellwuchs** | Uncommon | −25 % Fähigkeits-Abklingzeit |
| **Wildwuchs** (Grundkarte) | Rare | +1 Wand gleichzeitig |
| ↳ A **Elementarwand** | Epic | Gegner, die eine deiner Wände berühren, bekommen deine Waffeneffekte ab (Gift, Feuer, Frost, Blitz; höchstens alle 0,6 s pro Gegner). Ohne Elementeffekt vergiften die Dornen (2 Stapel). |
| ↳ B **Urwald** | Epic | Wände halten 50 % länger, zusammen mit Wildwuchs +4 Wände gleichzeitig (5 insgesamt) |
| ↳ C **Lebensborke** | Epic | Berührst du deine Wand, heilt sie dich um 12 HP/s |

So funktioniert die Wand: Sie wächst 62 px vor dem Druiden quer zur Zielrichtung. Zielst du in der Seitenansicht eher waagerecht, steht sie senkrecht auf dem Boden darunter; schräg oder nach oben gezielt liegt sie entsprechend gedreht in der Luft (z. B. als Dach oder Trittstufe). Sie hält Kugeln und Spieler aller Teams auf, man kann auf ihr stehen. Kugeln und Nahkampf beschädigen sie, Durchschlag geht wie durch zerstörbare Blöcke hindurch. Wer beim Aufbau in ihr steht, wird zur Seite geschoben. Ist das Limit erreicht, zerfällt die älteste Wand. *Fähigkeitsgröße* verlängert die Wand, *Fähigkeitsdauer* verlängert ihre Standzeit, *Fähigkeitsschaden* (Kraftladung) erhöht ihre HP und die Stärke von Elementarwand und Lebensborke. In der Arena ist die Wand 108 px (3 Höhenbänder) hoch, also nicht überspringbar, und wird als 3D-Block gezeigt.

**Für alle Helden:** **Weitstrahler** (+25 % Fähigkeitsgröße) mit Evolution **Flächenbrecher** (+50 %) und **Kraftladung** (+25 % Fähigkeitsschaden) mit Evolution **Überladung** (+50 %), alle Common. Die Boni multiplizieren sich (Grundkarte + Evolution = ×1,875). *Fähigkeitsgröße* vergrößert Wirkungsradius und Effektfläche der Klassenfähigkeit samt Evolutionen (Einschlag, Schockwelle, Giftwolke, Sog, Klingenwirbel, Heilfeld-Optik, Schattenschnitt, Napalm, Blitzzonen, Splitter-Explosionen), aber **nicht** die Teleport-, Sprung- oder Wurfweite. *Fähigkeitsschaden* erhöht allen Schaden der Fähigkeit inklusive Kettenblitz, Splitter, Blitzzonen und Gift von „Ätzender Nebel“; bei Bastion steigen Heilung und Schild. Novas Singularität selbst macht keinen Schaden, deshalb bekommt Nova Kraftladung und Überladung erst angeboten, wenn „Implosion“ im Deck ist. Gesamtwerte sind gedeckelt (Größe ×2,5, Schaden ×4).

### Talentbäume

Eine Ausbaukarte erscheint erst, wenn die Grundkarte im Deck liegt. Wer einen Zweig wählt, bekommt den anderen nicht mehr angeboten.

| Familie | Grundkarte | Ausbau A | Ausbau B |
| :--- | :--- | :--- | :--- |
| **Turm** | Turm: Fähigkeit stellt eine Kanone (100 Leben) auf | Mehr Türme: alle 5 s ein weiterer | Folgende Türme: folgen dir |
| **Giftschuss** | +2 Gift-Stapel | Giftwolke am Einschlag | Giftspur hinter dir |
| **Blitzschuss** | 0,1 s Betäubung | Blitz-Orb am Einschlag | |
| **Kettenblitz** | Treffer springen als Blitz auf den nächsten Gegner (45 % Schaden, 0,1 s Betäubung), im 1-gegen-1 zurück aufs Ziel. Auch für Nahkämpfer | Kettenreaktion: +1 Sprung | |
| **Frostschuss** | 0,8 s Verlangsamung | Eisnova am Einschlag | Eisbahn hinter dir |
| **Explosivschuss** | +30 px Explosion | Großer Knall (+60 px) | Splitterbomben (Zweig C: Meteor Cannon, +75 px, +60 % Schaden, −30 % Feuerrate, früher eigene Karte) |
| **Feuersturm** | Geschosse entzünden Gegner und den Boden am Einschlag (früher Brandkapsel) | Brandherd: +60 % Feuerschaden | Brandkapsel: +60 % Feuerreichweite (Zweig C: Feuerspur hinter dir) |
| **Wächterdrohne** | Drohne schießt mit | Zwillingsdrohne | Regenerationsdrohne |
| **Schutzdrohne** | Drohne fängt Schüsse ab | Heilende Schutzdrohne | Schutzdrohnen-Schwarm |
| **Mörser** | Steiler Bogen, mehr Schaden | Präzisionsmörser | Belagerungsmörser |
| **Rückstoßfeder** | +25 % Rückstoß | Druckkammer | Schockgeschoss |
| **Leichte Schuhe** | Tempo | Windschuhe | |
| **Minenleger** | Jede Barriere legt eine unsichtbare Mine | Sofortzünder: explodiert ohne Verzögerung | |
| **Tank-Panzerung** | siehe unten | | |

**Türme** haben 100 Leben und verlieren 5 % davon pro Sekunde, halten also höchstens 20 s. Gegner und Explosionen beschädigen sie. Turm-Panzerung und Schnellfeuer-Geschütz gibt es nur mit Turm.

### Tank-Panzerung (Evolutionsbaum)

| Seltenheit | Zweig A (Rüstung) | Zweig B (Reflexion) |
| :--- | :--- | :--- |
| Common | Tankplatte (+Max-HP, +5 % Rüstung) | Tankplatte |
| Uncommon | Stahlhaut | Dornenhaut (8 % Reflexion) |
| Rare | Festungspanzer | Reflektorplatte (12 %) |
| Epic | Titanenbollwerk | Spiegelpanzer (18 %) |
| Legendary | Ewige Bastion | Spiegelkoloss (22 %) |

Dazu kommen einzelne Reflexions-Karten im Pool Defensive: **Stachelweste**, **Rachepanzer**, **Blutspiegel**, **Vergeltungsschild** und **Dornenthron**. Manche reflektieren mehr unter 35 % Leben oder heilen dich mit.

### Barriere-Karten

| Seltenheit | Karten |
| :--- | :--- |
| Common | Barriereübung (+0,15 s), Schnelle Deckung (−15 % Abklingzeit) |
| Uncommon | Verstärkte Deckung (+0,3 s, Evolution: Ausdauerbarriere), Barrierestoß (stößt weg) |
| Rare | Barrierebombe, Heilzone, Druckwelle, Panzerglas (+1 Treffer, bevor die Barriere zerbricht) |
| Epic | Konterblitz (+50 % auf reflektierte Schüsse), Barriere-Experte, Unzerbrechlich |

**Minen:** Mit **Minenleger** (Rare) lässt jede Barriere eine Mine fallen, die auf dem Boden darunter liegen bleibt und auf Plattformen und Wippen mitfährt. Gegner sehen sie nicht (online gar nicht, am selben Bildschirm nur schwach). Nach 2 s ist sie scharf. Läuft ein Gegner darüber, blinkt sie und explodiert 1,5 s später: 50 Schaden, 2 Felder Explosionsradius, nur gegen Gegner. Höchstens 8 Minen pro Spieler, bei der neunten verschwindet die älteste. Nur mit Minenleger im Deck gibt es **Minenschaden** (Rare, +50 Schaden) und **Minenreichweite** (Uncommon, +1 Feld Explosionsradius). Evolution A **Sofortzünder** (Epic) lässt Minen ohne Verzögerung explodieren. Im Horden-Modus lösen Bodengegner die Minen aus und nehmen Schaden, Adler fliegen darüber.

**Barriere automatisch:** Im Lobby-Reiter Handicaps hat jeder Spieler den Schalter BARRIERE AUTO (online stellt jeder seinen eigenen, der Host alle). Ist er an und die Barriere bereit, zündet ein Treffer sie selbst und sie fängt ihn ab. Gift- und Brandticks und eigener Schaden lösen sie nicht aus. Praktisch im Horden-Modus.

### Nahkampf-Karten

| Seltenheit | Karten |
| :--- | :--- |
| Common | Schleifstein (+25 % Schaden), Langer Griff (+0,5 Felder), Leichter Griff (−15 % Abklingzeit), Schwerer Kopf (+40 % Rückstoß) |
| Uncommon | Frostklinge (1,2 s Frost), Giftzahn (+3 Gift), Glühende Spitze (3 Brand), Weiter Schwung (+30° Bogen), Gnadenstoß (+60 % unter 35 % Leben) |
| Rare | Elektroschocker (0,35 s Betäubung), Wandklatscher (Wand-Betäubung für alle Waffen), Blutklinge (25 % Lebensraub), Meisterschliff |
| Epic | Hochspannung (Kettenblitz), Nachschlag (zweiter Schlag 60 %), Eiskern |
| Legendary | Meister der Werkbank, Gewitterschlag, Parade (bereiter Schlag löst von selbst aus und wirft anfliegende Projektile zurück) |

---

## 🌍 Maps & Spielfeld-Objekte

Der Host wählt die Map unter **Regeln → Spielfeld**. **Zufällig** zieht pro Runde eine der aktiven Maps (abschaltbar im Reiter **Levels**), alle Spieler bekommen dieselbe.

| Map | Art | Besonderheiten |
| :--- | :--- | :--- |
| **Grasarena** | Arena | Luftige Balken, zentrale Wippe, Kisten, Ranken. Der Mittelbalken hat eine Falltür über den Stacheln, Hebel unter den Seitenbalken öffnen sie für 4 s |
| **Wüstenruine** | Arena | Offene Sandinseln, Kettenplattformen, TNT |
| **Eisgrotte** | Arena | Glatte Eisflächen, schwebende Wippe, Kistenstapel |
| **Neonfabrik** | Arena | Technik-Balken, Ketten, Kisten, Powerups. Hebel unter den Einweg-Stegen schalten 4 s lang einen senkrechten Laser durch die Mitte |
| **Weite Wiese** | Arena | Wenige Plattformen, viel Platz für Duelle |
| **Wolkeninsel** | Arena | Kleine Wolkeninseln, weite Sprünge, Wolkenfähre |
| **Uhrwerk** | Arena | Großes Zifferblatt in der Mitte: Der lange Minutenzeiger dreht sich in 16 s einmal herum, man fährt auf ihm mit. Aufzüge an den Seiten, aus zwei Trichtern fallen alle 10 s Kugeln, die der Zeiger herumschiebt |
| **Hauptplatine** | Arena | Leuchtende Leiterplatte, Datenbus-Shuttle, Chips als Deckung |
| **Kistenfestung** | Arena | Nur Holzkisten, große Wippe mit Kistentürmen |
| **Sonnentempel** | Arena | Riesige hohle Pyramide über drei Viertel der Breite (drüberlaufen oder unten hinein), Kistenkette über der Spitze |
| **Kettenwerk** | Arena | Neon-Halle voller Kistenketten, Einweg-Stege |
| **Wollhaus** | Arena | Haus mit vier Räumen, Luken und begehbarem Dach, Kisten an Ketten. Die untere Mitteltür ist zu (Hebel im Raum öffnet sie 6 s), die obere steht offen (Hebel schließt sie 5 s) |
| **Eispyramiden** | Arena | Zwei große hohle Eispyramiden über fast die ganze Breite, Kistenkette zwischen den Spitzen |
| **Serverhaus** | Arena | Rechenzentrum mit vier Räumen, tief gespannte Kistenketten zum Rand |
| **Gitterzaun** | Arena | Gitter aus fünf senkrechten Ketten (Decke bis Boden) und vier waagrechten Ketten, große Kisten an jeder Kreuzung, Einweg-Stege an den Rändern |
| **Trümmerfeld** | Arena | Offen: zerstörbare Mauerreste, Torbogen in der Mitte, viele Fässer und Kisten |
| **Schrottplatz** | Arena | Offen: Blockhaufen, Kisten an Deckenketten, viel TNT |
| **Schneefeld** | Arena | Offen: Schneeburgen aus zerstörbaren Blöcken, Tiefschnee und Eis |
| **Wollmarkt** | Arena | Offen: Marktstände mit Einweg-Dächern auf zerstörbaren Pfosten, Trampoline |
| **Kugellawine** | Arena | Zwei Schrägen unter der Decke voller Kugeln hinter einer Kettensperre. Sie reißt nach 7 s (oder früher, wenn man sie zerschießt), dann rollt die Lawine über ein Satteldach durch die Arena. In der Höhle unter dem Dach dreht sich ein Rührbalken: Kleine Kugeln rollen darunter durch, große schiebt er an |
| **Kugelbahn** | Arena | Doppelte, gespiegelte Zickzack-Kugelbahn. Oben an jeder Bahn erscheint alle 5 s eine Kugel, oft mit bis zu zwei kleinen Kugeln davor, und rollt bis auf den Boden. Die Schrägen sind Einweg-Rampen: von unten durchspringen, mit `S` / `↓` durchfallen, Kugeln rollen oben darauf. Leiter aus Einweg-Stegen in der Mitte |
| **Kugelkette** | Arena | Lange Kette quer unter der Decke zwischen zwei Randleisten, oben drauf viele Kugeln aller Größen. Zerschießt man ein Glied, regnet alles in die Arena |
| **Kugelmühle** | Arena | Zwei gegenläufige Windmühlen-Kreuze. Aus Trichtern fallen alle 5 s Kugeln auf die Flügel, die sie anheben und zur Mitte schleudern. Leiter aus Einweg-Stegen in der Mitte, Steg-Treppen außen |
| **Falltürburg** | Arena | Breite Falltür-Brücke über einer Stachelgrube, Hebel darunter öffnen sie für 3 s. Oben je eine Falltür-Bastion, deren Hebel auf der Gegenseite hängt. Ganz oben eine Druckplatte: Wer sie betritt, ruft einen Orbitalschlag auf die andere Kartenseite |
| **Laserlabor** | Arena | Laser in Knöchelhöhe quer über den Boden (drüberspringen!), Laser auf den Seitenbalken mit dem Hebel auf der Gegenseite. Oben ein Tresor mit Herz-Blöcken hinter zwei Laserwänden: Der Hebel schaltet die eigene Wand ab, ein zweiter Treffer wieder an |
| **Schleusenwerk** | Arena | Tresor mit zwei Schleusentüren und einer Falltür über Stacheln als Boden. Die Druckplatte vor der Tür hält sie offen, solange jemand draufsteht (danach 2,5 s), innen öffnet ein Hebel. Außen lässt ein Hebel den Boden fallen. Über dem Dach ein Laser, oben eine Platte für einen Bodenlaser über die gegnerische Hälfte |
| **Pilzpfad** | Scrollt seitlich | Gruben, Treppen, Herz-Block, Fähre, Portale |
| **Gletscherpass** | Scrollt seitlich | Aufzüge im Abgrund, Eisfähre, hängende Wippe |
| **Lavaturm** | Scrollt nach oben | Lava steigt schon ab 4 s, Gipfel-Arena |
| **Himmelsleiter** | Scrollt nach oben | Feder, Aufzug, Wolkenfähre, Gipfelportal |
| **Turbotrasse** | Autoscroll | Das Bild fährt von selbst nach rechts. Kurze Abzweigungen laufen wieder zusammen: Steg über zwei Gruben oder unten durch, Tunnel unter der Decke oder obendrüber, Trittsteine oder Fähre über die große Grube. Turbo- und Umkehrfelder |
| **Asteroidenfeld** | Weltraum | Schwerelos zwischen schwebenden Stationen. Asteroiden treiben durchs Bild, kleine mit goldenem Kern enthalten Powerups, Weltraumquallen jagen die Spieler |
| **Kometenjagd** | Weltraum, Autoscroll | Schwerelose Autoscroll-Strecke durch einen Asteroidengürtel, Stationswände teilen die Bahn kurz in Spuren. Asteroiden kommen von vorn |

Auf Scroll-Maps folgt die Kamera dir. Gegner außerhalb des Bildes zeigen Pfeile am Rand.

### Autoscroll

Auf Autoscroll-Maps (Seitenansicht und die Arena-Karte *Rennstrecke*) fährt ein Bildfenster von etwa 40 Kacheln Breite zwei Sekunden nach dem Countdown von selbst los, alle müssen mithalten.

- **Rote Wand hinten:** schiebt nach vorn und macht 30 Schaden pro Sekunde. Wer weit dahinter hängt oder dort gegen eine Wand gedrückt wird, wird zerquetscht (95 pro Sekunde).
- **Vordere Kante** (gestrichelt): bremst nur, weiter vorlaufen geht nicht.
- **Turbofeld** (orange, Doppelpfeile): Das Bild fährt 5 s lang 1,8-mal so schnell.
- **Umkehrfeld** (lila, Gegenpfeile): Die Fahrtrichtung dreht sich um, die rote Wand ist dann auf der anderen Seite.
- Felder lösen aus, sobald jemand sie berührt, und laden 9 s nach (Balken unter dem Feld). Am Kartenende dreht die Strecke von selbst um. Im Sudden Death fährt sie 35 % schneller.

### Weltraum

- **Schwerelos:** `W` `A` `S` `D` (bzw. Pfeiltasten) sind Düsen in alle Richtungen, man treibt weiter, bis man gegensteuert oder anstößt. `Leertaste` ist ein Schubstoß in Steuerrichtung (ohne Richtung: zur Maus). Schübe laden bei Kontakt mit einer Fläche sofort, sonst alle 1,1 s einer; Anzahl wie Sprünge (Luftsprung-Karten geben mehr). Dash geht in Steuerrichtung. Kugeln fliegen geradeaus, Kisten und Fässer schweben.
- **Asteroiden** in drei Größen treiben durchs Bild und machen beim Aufprall Schaden je nach Größe und Tempo. Schüsse und Explosionen zerlegen sie: groß in zwei mittlere, mittel in zwei kleine. Kleine mit **goldenem Kern** lassen ein Powerup fallen. Neue kommen vom Rand herein (auf Autoscroll-Strecken von vorn).
- **Weltraumquallen** (90 LP) treiben auf den nächsten Spieler zu, laden sichtbar auf (rot, zitternd) und schießen dann auf ihn zu. Berührung 13 Schaden, beim Vorstoß 22. Beim Tod lassen sie oft ein Powerup fallen.

### Spielfeld

- **Gummiwand**: Um die Karte liegt ein Rahmen mit Stacheldraht (rote Dornen zeigen ins Feld). Wer ihn berührt, nimmt Schaden (roter Plasma-Schlag am Rand, online für alle sichtbar) und wird Richtung Bildschirmmitte zurückgeschleudert (Mitte aller Spieler, online für alle gleich; in Scroll-Levels gerade zurück ins Feld). Mit dem Modifier **Höhle** sind es feste Felswände.
- **Spawns** sind jede Runde anders, verteilt über das Level und auf verschiedene Höhen.
- Jede neue Runde räumt Projektile, Türme und Effekte der Vorrunde weg.

### Objekte

| Objekt | Verhalten |
| :--- | :--- |
| **Zerstörbare Blöcke** | Halten 3 Treffer, dann weg |
| **Starke Ranken** | Brechen nur durch Beschuss, wachsen nach 8 s nach |
| **Schwache Ranken** | Brechen beim Drüberlaufen, wachsen nach 4,5 s nach |
| **Eisflächen** | Rutschig, wenig Reibung |
| **Sprungfedern** | Katapultieren hoch in die Luft |
| **Portale** | Teleportieren, danach 10 s weg |
| **Herz-Blöcke** | Von unten anspringen oder anschießen: +30 HP |
| **Stacheln** | Schaden und Wegschleudern |
| **Wippe** | Kippt unter Gewicht, Schüssen und Explosionen, federt zurück |
| **Kettenplattform** | Hängt an Ketten und schwingt |
| **Einweg-Steg** | Dünner Steg mit kleinen Pfeilen darunter: von unten durchspringen, oben landen. Mit `S` / `↓` fällst du hindurch. Schüsse von unten fliegen durch |
| **Kistenkette** | Kisten verschiedener Größe an Ketten, gespannt zwischen Plattformen oder vom Kartenrand, oder frei hängend. Spieler, Kisten und Schüsse prallen ab, man kann darauf laufen. Glieder halten 2 Treffer (Schüsse oder Schläge), Kisten 2 Treffer; dann reißt die Kette dort und die Teile fallen. Explosionen und Kugeln schubsen Glieder nur, sie reißen sie nicht. Beim Spawn schwingt die Kette gedämpft in ihre Ruhelage |
| **Kettengitter** | Netz aus Ketten mit Kisten an den Kreuzungen (Gitterzaun). Jedes Kettenstück reißt einzeln, eine zerstörte Kreuzungskiste löst die angrenzenden Stücke |
| **Pyramide** | Großes hohles Dreieck: Die Schrägen sind begehbar, unten ist sie offen. Innen führen Einweg-Stege bis unter die Spitze |
| **Haus** | Vier Räume: unten Türen, oben Fenster, Einweg-Luken in der Zwischendecke über kleinen Plattformen. Außen führen Leisten zum Fenster und aufs Satteldach |
| **Aufzug / Fähre** | Fährt zwischen zwei Punkten und nimmt dich mit |
| **Drehbalken** | Dreht sich gleichmäßig um seine Nabe (Uhrzeiger, Rührbalken, Windmühlen-Kreuz). Man fährt darauf mit, bis er zu steil wird. Kugeln, Kisten und Fässer schiebt und schleudert er weg. Schüsse prallen ab wie an einer Wand |
| **Schalter** | **Hebel** (Kasten mit Hebel) werden angeschossen, geschlagen oder von Explosionen umgelegt; Spieler laufen hindurch. **Druckplatten** reagieren auf Spieler, Kisten und Kugeln, solange etwas draufsteht, und bleiben danach noch kurz an. Jeder Schalter hat eine Laufzeit: Der Ring (Platte: Balken) läuft leer, in der letzten 1,5 s blinkt er rot und tickt, dann fällt er zurück. Danach ist er einige Sekunden gesperrt (roter Ring füllt sich), damit niemand Türen im Dauerfeuer flattern lässt. *Zeitschalter* lassen sich während der Laufzeit nicht erneut auslösen, *Kippschalter* (Toggle) schaltet ein zweiter Treffer wieder aus. Schalter und Ziel tragen dieselbe Farbe. Bots schießen Hebel, wenn es dem Gegner schadet (Falltür unter ihm, Laser auf ihm) oder eine Tür im Weg ist, laufen zu lohnenden Platten und weichen aktiven Lasern aus |
| **Tür / Falltür** | Gesteuert von Schaltern: Türen fahren nach oben auf, Falltüren klappen nach unten weg. Manche sind normal offen und schließen per Schalter. Sie schließen nie auf jemandem: Steht etwas im Rahmen, warten sie und blinken rot |
| **Laserschranke** | Zwischen zwei Emittern. Beim Einschalten erst 0,6 s rote Warnlinie, dann der Strahl: 70 Schaden pro Sekunde und leichtes Wegstoßen. Manche Schranken sind normal an und werden per Schalter abgeschaltet |
| **Orbitalschlag** | Per Schalter: derselbe Strahl wie beim Modifier Orbitallaser entlang einer festen Bahn (Peilmarken in Schalterfarbe), 1,8 s Warnung |
| **Fass** | Rollt und fliegt bei Treffern weg, fallende Fässer machen Schaden |
| **TNT-Fass** | Blinkt 3 s nach einem Treffer, dann Explosion mit Kettenreaktion |
| **Holzkisten** | Stapelbar, kippen um. Fallende oder geschleuderte Kisten machen Schaden (bis 38) |
| **Rollende Kugeln** | 0,5, 1 oder 2 Kacheln groß, aus Gummi, Holz oder Eisen. Rollen Schrägen hinab und verletzen, wen sie treffen: je schneller und schwerer, desto mehr. Gummi: wie ein Strandball, sehr leicht und etwas schwebend, fliegt bei Schüssen, Schlägen, Explosionen und Anrempeln weit weg, hält sehr viel aus, wenig Schaden (bis 16). Holz: mittel, bis 30 Schaden, splittert bei harten Aufprallen. Eisen: sehr schwer, bis 55 Schaden, zertrümmert Kisten und Blöcke. Große Kugeln halten doppelt so viel aus und treffen härter, kleine halten halb so viel aus und treffen schwächer. Wer draufsteht, rollt sie weg, wer dagegenläuft, schiebt sie an. Wer obendrauf steht oder dagegen läuft, nimmt keinen Schaden |
| **Kettensperre** | Hält Kugeln auf einer Schräge zurück, blinkt rot kurz bevor sie reißt. Reißt nach Treffern oder nach Ablauf der Zeit |
| **Powerups** | Heilung (35 HP), Schutz (3 s Unverwundbarkeit), Schaden (6 s +65 %), Dauerfeuer (5 s), Auto-Angriff (8 s: halbe Nahkampf-Abklingzeit, die Nahkampfwaffe schlägt selbst nach Gegnern in Reichweite), Multishot (8 s: jeder Schuss feuert 3 Projektile im Fächer), Unsterblichkeit (stirbst du in den nächsten 10 s, liegst du 2 s unverwundbar am Boden und stehst mit halbem Leben und 1 s Schutz wieder auf; der Tod zählt nicht, kein Kill für den Gegner; Todes-Effekte wie die Kamikaze-Explosion lösen trotzdem aus), Rache (5 s 100 % Dornenschaden: Angreifer bekommen den Schaden, den sie dir machen, zurück), Unsichtbar (6 s: Gegner sehen deinen Charakter samt Lebensleiste nicht, Schüsse und Effekte bleiben sichtbar; online sieht dein Team dich schwach, am geteilten Bildschirm bleibt gegen menschliche Gegner nur ein Hauch übrig; Bots, Auto-Angriff und Zielsuche nehmen dich nicht ins Visier, treffen kannst du trotzdem). Aktive Powerups lassen den Körper in ihrer Farbe schimmern und zeigen eine Aura: Schutz eine Schildblase, Unsterblichkeit einen Heiligenschein, Rache einen drehenden Stachelkranz, alle anderen ein loderndes Energiefeld in ihrer Farbe; in der letzten Sekunde flackert die Aura. Powerups erscheinen 30 % seltener als in den Map-Werten angegeben (zufällig in der Arena, aus Kisten und beim Powerup-Regen). Einzeln abschaltbar im Lobby-Reiter **Powerups**. **Powerup-Verstärker** (+25 %) und seine Evolution **Powerup-Magnet** (weitere +25 %, +2 Felder Sammelreichweite: Powerups fliegen dir aus der Nähe zu) verlängern die Dauer bzw. erhöhen die Heilung |

---

## 🎲 Runden-Modifier

Jede Runde können zufällig Modifier aktiv sein. Bei Rate 100 %: 53 % keine, 33 % einer, 10 % zwei, 3 % drei, 1 % vier. Unter 100 % fällt öfter einer weg, über 100 % kommt öfter einer dazu. Der Host schaltet im Regeln-Tab einzelne Modifier an oder aus (**ALLE** / **KEINE**).

| | Modifier | Wirkung |
| :---: | :--- | :--- |
| ⛰ | Höhle | Feste Felswände statt Gummiwand |
| 💣 | TNT-Depot | Mehr TNT, alle 10 s regnen 5 TNT-Kisten |
| 🌪 | Sturmwind | Alle 10 s ein Windstoß (3,5 s), schiebt Spieler und bremst Schüsse |
| 🔴 | Orbital-Laser | Alle 10 s ein angekündigter Riesenlaser quer über die Map (50 Schaden) |
| 🪙 | Münzbeute | Münzen im Level, wer die meisten hat, bekommt eine Extrakarte |
| 💚 | Wandernde Heilzone | Schwebender Heilkreis wandert über die Map, 16 HP/s |
| 🦙 | Piñata-Lama | Unsterbliches Lama flieht vor dem Führenden. Meister Schaden bekommt eine Extrakarte |
| 🌙 | Mondgravitation | 50 % Gravitation |
| 🪨 | Schwerewelt | 60 % mehr Gravitation |
| 🌋 | Der Boden ist Lava | Der unterste Boden brennt |
| 🌊 | Lava-Flut | Alle 30 s steigt Lava auf ein Drittel bis die Hälfte der Höhe und sinkt wieder |
| ☄ | Meteoritenschauer | Alle 12 s 3 Meteore mit Zielkreuzen |
| ❄ | Glatteis-Welt | Alle Plattformen spiegelglatt |
| 🐷 | Mini-Chaos | Alle 35 % kleiner und flinker |
| 💥 | Schadensrausch | +35 % Schaden für alle |
| 💨 | Turboschweine | Alle 30 % schneller |
| 🪂 | Luftakrobatik | +1 Sprung in der Luft für alle |
| 🌿 | Regeneration | Alle heilen 4 HP/s |
| 🛡 | Startschild | Bonusschild in Höhe von 30 % der Max-HP |
| 📦 | Kistenregen | Alle 9 s drei Holzkisten |
| 🎁 | Powerup-Regen | Etwa drei zusätzliche Powerups beim Start (vier, abzüglich 30 %) |
| ⚪ | Kugelregen | Alle 4 s fallen fünf Kugeln (Gummi, Holz, Eisen) vom Himmel |
| 🎳 | Kugelhagel | Alle 16 s (erstmals nach 6 s) prasseln 24 Kugeln auf einmal über die ganze Breite herab |
| 🌀 | Zone | Sturmkreis wie in Fortnite: startet größer als die Map, schrumpft in drei Stufen (gestrichelte Vorschau), am Ende wandert ein kleiner Kreis über die Map. Außerhalb 6 bis 16 HP/s, im Sudden Death doppelt so schnell und immer über der Lava |
| 🌑 | Nacht | Jeder sieht nur einen kleinen Lichtkreis |
| 😈 | Heiße Kartoffel | Ein kleines fliegendes Teufelschwein (fliegt durch Wände) jagt zuerst den Führenden und schießt gerade Feuerbälle auf ihn (8 Schaden, alle 1,2 s, nur mit Sichtlinie). Ein Hörnchen-Pfeil zeigt das Ziel. Trifft das Ziel den Teufel (Schuss, Explosion oder Nahkampf), jagt er einen anderen Spieler. Trifft ihn jemand anderes, wird dieser sein Ziel und der Teufel ist 5 s wütend: schneller, schießt alle 0,5 s und lässt sich nicht weitergeben |
| 🔨 | Brawl | Nahkampfwaffen: 50 % mehr Reichweite, halbe Abklingzeit |

Extrakarten aus Münzbeute und Piñata-Lama erscheinen im Draft als **Bonus Zug (Gold)** bzw. **Bonus Zug (Pinata)**. Währenddessen regnen Goldmünzen bzw. Konfetti und Bonbons über den Bildschirm.

---

## 🤖 Bots

- Jeder Slot ab 2 kann ein Bot sein. Für ein Solo-Match einfach bis zu fünf Bots einstellen.
- Bots suchen den nächsten Gegner, springen über Hindernisse, lassen sich durch Einweg-Stege fallen, gleichen den Geschossbogen aus, schießen nur mit Sichtlinie, nutzen Dash, Fähigkeit und Nahkampf, flüchten vor Lava und wählen selbst passende Karten. Bei der Heißen Kartoffel schießen sie als Ziel auf den Teufel und halten sonst das Feuer zurück, wenn er in der Schusslinie schwebt.
- Online simuliert der Host alle Bots.

---

## 🌐 Online & LAN

Bis zu **6 Spieler** (Host + 5) plus bis zu **4 Zuschauer**. Der Host ist Slot 1 und rechnet die ganze Runde, die anderen senden nur Eingaben. Online spielt jeder mit der **P1-Steuerung**.

### Übers Internet mit Code (Epic, empfohlen)

1. **Host**: Hauptmenü → **ONLINE SPIELEN** → **Online hosten**.
2. Oben in der Lobby steht ein **6-stelliger Code** mit Kopier-Knopf. Den an die Freunde schicken.
3. **Mitspieler**: **ONLINE SPIELEN** → Code eintragen → **Mit Code beitreten**.

Kein Portfreigeben nötig. Läuft über Epic Online Services, ein Epic-Konto braucht niemand. Wichtig: Host und Mitspieler müssen an **verschiedenen PCs** sitzen.

### Im LAN oder per IP

1. **Host**: **ONLINE SPIELEN** → Port `7777` lassen → **SPIEL HOSTEN**. Die Lobby zeigt die lokale IP (z. B. `192.168.1.42`).
2. **Mitspieler**: IP und Port eintragen → **BEITRETEN**. Für Zuschauer vorher **„Als Zuschauer beitreten“** anhaken.

Übers Internet per IP: Das Spiel versucht **UPnP** automatisch. Klappt das nicht, im Router **UDP 7777** weiterleiten oder **ZeroTier/Tailscale** nutzen (gut bei CGNAT).

### Gut zu wissen

- **Ping** steht in Lobby und HUD (grün, gelb, rot).
- Synchronisiert werden Lobby-Einstellungen, Charaktere, Namen, Map, alle Objekte, Lava, Modifier, Draft, Punkte, Kill-Cam und Statistik.
- Zuschauer können nur in der Lobby beitreten.
- Kein Reconnect: Verlässt ein Spieler das Match, geht es zurück ins Menü.

### Typische Probleme

| Problem | Lösung |
| :--- | :--- |
| „Verbindung fehlgeschlagen“ | Gleiche Spielversion? Host wirklich offen? IP, Port oder Code richtig? |
| Code-Beitritt hängt | Nicht am selben PC hosten und beitreten. Protokoll steht in `epic_online.log` |
| LAN geht, Internet per IP nicht | Firewall und Router-Portfreigabe prüfen, sonst Code-Beitritt oder ZeroTier/Tailscale |
| UPnP „nicht möglich“ | Router kann es nicht, Port manuell freigeben |
| Client steuert falsch | Online gilt WASD + Maus |

---

## 🔧 Hauptmenü & Optionen

Das Hauptmenü im **Platinen-Look**: leuchtende Leiterbahnen, zwei Eber mit Lötkolben, die Knöpfe in der Mitte.

| Knopf | Wirkung |
| :--- | :--- |
| **SPIEL STARTEN** | Lokale Lobby |
| **ONLINE SPIELEN** | Hosten oder beitreten (Code oder IP) |
| **PROFIL** | Deine Werte über alle Partien (siehe unten) |
| **HELDEN** | Übersicht aller Helden mit Werten und Fähigkeiten |
| **ERFOLGE** | Erfolge, Fortschritt, Titel-Auswahl |
| **WIKI** | Öffnet dieses Wiki im Browser |
| **OPTIONEN** | Einstellungen |
| **BEENDEN** | Spiel schließen |

**Optionen** gibt es im Hauptmenü und in der Runde über `Esc`:

- **Grafik**: Fenster, Vollbild oder Vollbild-Fenster (randlos).
- **Audio**: Gesamt, Effekte und Musik, je 0–100 %.
- **Effekt-Set** (Soundpaket): Arena (Standard), Retro, Handgemacht (Foley), Modernes Sci-Fi, Kräftig & echt, Magie & Zauber, Werkstatt & Metall, Weich & verspielt und optional **Eigene Mischung**. Mit **PROBE** anhören. Gilt nur auf deinem PC.
- **Steuerung**: Feld anklicken, neue Taste drücken. Doppelte Belegungen werden angezeigt, **STANDARD WIEDERHERSTELLEN** setzt alles zurück.

Jede Map-Stilrichtung hat eine eigene, ruhige **Hintergrundmusik**.

---

## 🏅 Erfolge, Titel & Freischaltungen

Über **ERFOLGE** im Hauptmenü (oder im Lobby-Tab **Charakter**) siehst du alle 32 Erfolge mit Fortschrittsbalken, Belohnung und Freischaltdatum. Neu erreichte Erfolge werden oben eingeblendet.

- **Was zählt**: nur dein eigener Slot, nur in Runden mit mindestens einem Gegner (Mensch oder Bot), nicht im Bot-Test. Online rechnet der Host und schickt jedem Mitspieler seine Rundenwerte; gespeichert wird auf deinem PC. Am selben PC mit mehreren Menschen zählt nur Slot 1.
- **Titel**: Fast jeder Erfolg gibt einen Titel (z. B. *Kartoffelkönig*, *Bollwerk*, *Feuerteufel*). Wähle ihn im Charakter-Tab oder im Erfolge-Fenster. Er steht hinter deinem Namen in der Lobby, im Tab-Charakterblatt und in der Match-Statistik und wird online an alle verteilt.
- **Freischaltungen**: Einige Aussehens-Teile sind gesperrt (🔒 im Charakter-Tab, Tooltip nennt den Erfolg): Hauer *Säbel* und *Doppelt*, Lötspitzen *Diamant*, *Stern* und *Flamme*, Ohren *Fledermaus*, Frisuren *Irokese* und *Mähne*, Rüssel *Herz*, Körperform *Keiler*, Augen *Wild*, Oberteil *Kleid / Robe*, Schwanz *Quaste*. Was du schon trägst, bleibt. **ZUFÄLLIG** würfelt nur freie Teile.
- **Test-Schalter**: „Alle Aussehens-Teile freigeben (Test)“ im Erfolge-Fenster macht alles wählbar, ohne Erfolge zu vergeben.

| Erfolg | Ziel | Belohnung |
| :--- | :--- | :--- |
| Erstes Blut | 1 Kill | Titel Ersttäter |
| Erster Sieg | 1 Match gewinnen | Titel Frischling, Hauer Säbel |
| Stammgast | 10 Matches spielen | Titel, Ohren Fledermaus |
| Rundenjäger | 25 Runden gewinnen | Titel, Frisur Irokese |
| Schweinejäger | 50 Kills | Titel, Lötspitze Diamant |
| Dreifach-Eber | 3 Kills in einer Runde | Titel |
| Unberührbar | Runde ohne Schaden gewinnen | Titel |
| Feuerwerker | 10.000 Schaden | Titel, Schwanz Quaste |
| Feldsanitäter | 3.000 Heilung | Titel, Rüssel Herz |
| Bollwerk | 150 geblockte Treffer | Titel, Körperform Keiler |
| Raufbold | 4.000 Nahkampfschaden | Titel, Frisur Mähne |
| Fähigkeitsfanatiker | 8.000 Fähigkeitsschaden | Titel, Lötspitze Stern |
| Kartoffelkönig | 3 Rundensiege mit Heißer Kartoffel | Titel |
| Zonenläufer | 5 Rundensiege mit Zone | Titel |
| Arenafürst | 10 Rundensiege im Arena-Modus | Titel |
| Nervenstark | 5 Rundensiege im Sudden Death | Titel |
| Kartenhai | 12 Karten in einem Match | Titel |
| Unantastbar | 10 Runden ohne Schaden gewinnen | Titel, Hauer Doppelt |
| Seriensieger | 10 Matches gewinnen | Titel, Oberteil Kleid / Robe |
| Keilerkönig | 250 Kills | Titel, Augen Wild |
| Tausendsassa | Mit jedem Helden ein Match gewinnen | Titel |
| Urgestein | 100 Matches spielen | Titel |
| Großmeister | 50 Matches gewinnen | Titel Großmeister des Lötens, Lötspitze Flamme |
| Legende | 1.000 Kills | Titel Legende vom Lötkolben |
| *Held*-Profi (×8) | 15 Rundensiege mit dem Helden | Feuerteufel, Blitzableiter, Pilzkönig, Sternenkind, Klingenmeister, Eiserne Wand, Schattenschwein, Waldhüter |

---

## 📊 Statistiken, HUD & Feedback

- **HUD**: Oben rechts das Match-Ziel, pro Spieler ein Punktebalken (im Team-Modus in Teamfarbe), Ulti-Status `[E]: BEREIT`. Nahkämpfer haben über dem Charakter statt der Munition einen Balken für den nächsten Schlag.
- **Fähigkeitenleiste** (unten in der Mitte, wie eine Zauberleiste): Felder für Fähigkeit, Dash (Punkte für mehrere Ladungen), Barriere und Ulti mit ihrer Taste. Während der Abklingzeit liegt eine dunkle Abdeckung über dem Symbol, die sich von unten wieder auffüllt, die Restzeit steht in der Mitte. Rechts daneben Status-Felder für Schild, aktive Powerups (mit Restdauer), Gift und Zeitstopp. Maus darüber zeigt einen Tooltip mit Beschreibung, Abklingzeit und Restzeit. Online sieht jeder seine eigene Leiste, lokal bekommt jeder menschliche Spieler eine eigene (Bots keine).
- **Am Charakter**: Munitionsstriche bzw. Nachlade-Ring und Lebensbalken mit Schild-Overlay. Die früheren kleinen Symbole darunter sind in die Fähigkeitenleiste gewandert.
- **Tab-Charakterblatt**: Alle Werte, die Nahkampfwaffe und **KARTEN-BONI (SUMMEN)**. Geht auch während der Kartenwahl und wenn du tot bist. Ohne Blind Pick zeigt oben eine Leiste alle Spieler: bei gehaltenem Tab mit den Tasten 1–9 oder per Klick umschalten. Mit Blind Pick (online) bleibt es beim eigenen Blatt.
- **Kill-Cam**: Beim rundenentscheidenden Tod läuft das Spiel 1,6 s lang in Zeitlupe (20 %), die Kamera zoomt auf den Treffer.
- **Screenshake** bei Treffern, Kills und Explosionen.
- **Trefferanimation**: Stauchen, Zittern, rotes Aufblitzen, Blutspritzer. Dazu ein Todes-Sound.
- **Match-Ende**: Tabelle mit Punkten, Kills, Toden, Schaden, Barriere, Heilung, Trefferquote, Runden und Nahkampf. Dazu **MVP**, **Meister Schaden**, **meiste Barriere-Treffer**, **meiste Heilung** und **Meister Nahkampf**.
- **ALLE SPIELER, KARTEN & STATS**: Nach dem Match für jeden Spieler das komplette Blatt mit Karten.
- **Spielerprofil**: Hauptmenü → **PROFIL**. Deine Werte über alle Partien: Matches und Siegquote, Runden, K/D, MVP-Ehrungen, Schaden, Trefferquote, Heilung, gewählte Karten und Spielzeit. Dazu **Lieblingsheld**, **meistgewählte Karte**, **Lieblingsmap**, **Rekorde** (meiste Kills pro Runde und Match, meister Schaden, längste Siegesserie), Tabellen für Helden, Karten und Maps und die letzten 20 Matches. Es zählt nur dein eigener Slot auf diesem PC (online dein Slot, lokal Spieler 1); Bot-Test, Zuschauen und Testrunden aus den Editoren zählen nicht. Eine abgebrochene Runde zählt nicht, ein vorzeitig beendetes Match schon (als „abgebr.“). **ZURÜCKSETZEN** (zweimal klicken) löscht die Werte.
- **Rundenstatistik**: Jede Runde wird als Zeile in `round_stats.jsonl` gespeichert (für Balancing).
- **Balance-Statistik im Spiel**: Optionen → **STATISTIK**. Sortierbare Tabellen (Spaltenkopf anklicken) für **Karten**, **Waffen** und **Helden**, getrennt nach Version: Runden, geglättete Siegquote, Vergleich mit derselben Seltenheit, Kills/Tode pro Runde, Schadens- und Heilanteil, Nahkampfschaden, Pickquote und Aufstiegsvorschläge. Filter: nur menschliche Spieler, nur aktuelle Versionen, Mindestrunden für Vorschläge. Bei Helden zusätzlich **Fähigk./R** und **Fähigk.-Anteil**: Schaden aus direkten Treffern der Heldenfähigkeit samt Evolutionen (Brand/Gift danach zählt nicht), erfasst seit 28.10.2026. Die Seite **Hinweise** listet Vorschläge, Werte ohne neue Version und die automatischen Aufstiege. Hältst du die Maus 0,5 s über eine Kartenzeile oder einen Kartennamen unter Hinweise, erscheint die Karte unten links. Rechnet genauso wie `tools/analyze_round_stats.py`.

---

## 💾 Dateien & Speicherorte

Spieldaten liegen unter `%APPDATA%\Godot\app_userdata\Lötkolbeneber\`. Beim ersten Start übernimmt das Spiel automatisch die Daten aus dem alten Ordner `BattleBalls`.

| Datei | Inhalt |
| :--- | :--- |
| `settings.cfg` | Optionen: Grafik, Lautstärke, Effekt-Set, Tasten |
| `character_customization.json` | Dein Charakter, Name, Nahkampfwaffe |
| `achievements.json` | Erfolge: Zähler, freigeschaltete Erfolge, gewählter Titel |
| `lobby_loadouts.json` | Eigene Regel-Presets |
| `card_statistics.json` | Kartenstatistik und Aufwertungen |
| `round_stats.jsonl` | Eine Zeile pro gespielter Runde |
| `player_profile.json` | Dein Spielerprofil mit Lebenszeit-Werten |
| `epic_online.log` | Protokoll der Epic-Verbindung |
| `wiki.html` | Kopie dieses Wikis, wird beim Klick auf **WIKI** angelegt |
| `logs/` | Godot-Logs |

---

## 🧰 Für Entwickler

### Wichtige Skripte

| Datei | Zweck |
| :--- | :--- |
| `scripts/autoload/global.gd` | Helden, Maps, Modi, Lobby-Zustand, Nahkampfwaffen |
| `scripts/autoload/card_database.gd` | Alle Karten |
| `scripts/autoload/network_manager.gd` | ENet- und Epic-Netzwerk |
| `scripts/autoload/epic_online.gd` | Epic-Login und Lobby-Code |
| `scripts/autoload/sound_manager.gd` | Sounds, Effekt-Sets, Musik |
| `scripts/autoload/game_settings.gd` | Optionen und Tastenbelegung |
| `scripts/autoload/card_stats.gd`, `round_stats.gd` | Statistik |
| `scripts/balance_report.gd`, `scripts/ui/stats_screen.gd` | Balance-Statistik im Optionsmenü |
| `scripts/autoload/player_profile.gd`, `scripts/ui/profile_screen.gd` | Spielerprofil: Lebenszeit-Werte, Signale `round_recorded`/`match_recorded`, Erweiterungen über `get_ext()` |
| `scripts/main.gd` | Rundenablauf, Snapshots, Kill-Cam, Lava |
| `scripts/player.gd` | Spieler, Fähigkeiten (Konstanten oben), Nahkampf |
| `scripts/bullet.gd` | Ballistik, Durchschlag, Zielsuche, Kollision |
| `scripts/level_generator.gd` | Maps und Tilesets, Einweg-Stege, Pyramide, Haus |
| `scripts/level/crate_chain.gd`, `chain_link.gd` | Kistenketten (Bauplan, Gelenke, Netzwerk) |
| `scripts/level_modifier_defs.gd` | Liste der Runden-Modifier |
| `scripts/main_menu.gd` | Hauptmenü inkl. Wiki-Knopf |
| `scripts/ui/hud.gd` | HUD, Tab-Blatt, Match-Ende |

### Werkzeuge

- `godot --headless res://tools/level_check.tscn` prüft alle Maps auf unerreichbare Flächen (`-- --seeds=24 --maps=pilzpfad --ascii` für eine Textkarte).
- `tools/analyze_round_stats.py` wertet `round_stats.jsonl` aus, getrennt nach Version von Karten, Nahkampfwaffen, Helden und Heldenfähigkeiten. Dieselbe Rechnung steckt in `scripts/balance_report.gd` (Optionen → STATISTIK); Änderungen in beiden nachziehen.

### Balance-Versionen

Damit die Statistik alte und neue Werte nicht vermischt, tragen Karten, Nahkampfwaffen, Helden und Heldenfähigkeiten eine Versionsnummer. **Regel: Zahl geändert, die beeinflusst, wie stark etwas ist → Version +1. Nur Name, Text oder Farbe geändert → nichts tun.**

| Was geändert | Wo erhöhen |
| :--- | :--- |
| Karte | `cX.version` in `card_database.gd` |
| Nahkampfwaffe | `"version"` im Eintrag von `MELEE_WEAPON_DATA` in `global.gd` |
| Held: Basiswerte oder Passiv | `x.version` in `Global._setup_heroes` |
| Heldenfähigkeit: Konstanten oben in `player.gd` oder `ability_cooldown` | `x.ability_version` in `Global._setup_heroes` |

Vergessen ist nicht schlimm: Ein automatischer Fingerabdruck merkt geänderte Werte, das Spiel gibt dann eine Warnung aus und das Auswerteskript meldet „Werte ohne neue Version geändert“.
- `tools/build_sound_packs.py` baut die Effekt-Sets, `tools/compose_music.py` die Musik.
- `tools/build_wiki.py` baut aus dieser README die Browser-Fassung `docs/wiki.html` (braucht Python und pandoc).

### Export

- Windows-Export legt die EXE mit eingebettetem PCK an und packt den Ordner danach als ZIP.
- `eos_config.cfg`, `assets/audio/packs/mix.json` und `docs/wiki.html` werden über den Export-Filter mitgenommen.
- Nach Änderungen an dieser README `docs/wiki.html` neu bauen, sonst zeigt der Knopf im Spiel den alten Stand.
