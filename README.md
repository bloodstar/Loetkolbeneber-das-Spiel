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
15. [Statistiken, HUD & Feedback](#-statistiken-hud--feedback)
16. [Dateien & Speicherorte](#-dateien--speicherorte)
17. [Für Entwickler](#-für-entwickler)

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
| Schießen | `Linksklick` |
| Dash / Ausweichen | `Shift` (kurz unverwundbar) |
| Block | `Q` |
| Nachladen | `R` |
| Nahkampf | `E` |
| Heldenfähigkeit | `Rechtsklick` |

### Spieler 2 (nur lokaler 2-Spieler-Modus am selben PC)

| Aktion | Taste |
| :--- | :--- |
| Bewegen | `←` / `→` |
| Springen | `↑` |
| Durchfallen (Einweg-Steg) | `↓` |
| Zielen | Pfeiltasten |
| Schießen | `.` (Punkt) |
| Dash | `/` |
| Block | `M` |
| Nachladen | `L` |
| Nahkampf | `K` |
| Heldenfähigkeit | `,` (Komma) |

### Allgemeine Tasten

| Taste | Wirkung |
| :--- | :--- |
| `Tab` (halten) | Charakterblatt mit allen Werten, Karten-Boni und Netzdiagrammen der eigenen Kartenverteilung, auch während der Kartenwahl |
| `Esc` | Optionen öffnen. Lokal pausiert das Spiel, online läuft die Runde weiter |
| `F9` | Match zurücksetzen und zurück in die Lobby (nur lokal) |

---

## 🐷 Helden

Es gibt **7 Klassen**. Jede hat eigene Werte, ein Passiv, eine aktive Fähigkeit (Rechtsklick) und ein festes Outfit am Kopf.

| Held | Rolle | HP | Tempo | Schild | Passiv | Fähigkeit | Outfit |
| :--- | :--- | ---: | ---: | ---: | :--- | :--- | :--- |
| **Ignis** | Pyro Skirmisher | 100 | 310 | 0 | **Afterburner**: Dash hinterlässt eine echte Feuerspur, Gegner darin brennen | **Rocket Leap**: Explosiver Sprung, 35 Schaden im Einschlag (Radius 140) | Schweißerbrille |
| **Volt** | Hyper Speedster | 85 | 350 | 0 | **Overcharge**: Doppelsprung von Anfang an | **Flash Blink**: Teleport 260 px, 20 Schaden und 1,2 s Frost am Ziel | Gelbe Kappe mit Blitz |
| **Spore** | Toxic Alchemist | 105 | 295 | 10 | **Spore Coat**: Treffer vergiften (2 Stapel) | **Spore Burst**: Giftwolke, 9 Schaden/s für 3,5 s | Pilzhut |
| **Nova** | Gravity Mage | 95 | 290 | 10 | **Schwerelos**: Höchste Sprungkraft | **Singularität**: Kern zieht Gegner 2 s lang zur Mitte (kein Schaden) | Zauberhut mit Mini-Planet |
| **Klinge** | Blade Dancer | 110 | 315 | 15 | **Klingentanz**: Start-Schild und hohes Tempo | **Klingensturm**: Rundumschlag mit Rückstoß, 0,5 s unverwundbar | Roter Schal |
| **Bastion** | Field Engineer | 125 | 270 | 20 | **Aurora**: Doppelte Schild-Regeneration | **Heilfeld**: 4 s lang 8 HP und 10 Schild alle 0,5 s | Bauhelm mit Lampe |
| **Phantom** | Shadow Assassin | 90 | 325 | 5 | **Nachtwind**: Sehr schnell, kürzestes Feuerintervall | **Schattensprung**: Teleport 260 px mit Treffer, 0,9 s unverwundbar | Ninja-Stirnband |

Die genauen Zahlen der Fähigkeiten stehen im Spiel unter **HELDEN** im Hauptmenü und im Tooltip der Heldenwahl. Sie kommen direkt aus den Konstanten in `player.gd`, stimmen also immer.

### Waffe & Munition

Alle Eber schießen mit einem **Lötkolben**. Basis-Schaden pro Schuss ist **22** (in der Lobby einstellbar).

| Held | Munition | Feuerintervall | Nachladezeit |
| :--- | ---: | ---: | ---: |
| Ignis | 3 | 0,22 s | 1,2 s |
| Volt | 4 | 0,17 s | 1,4 s |
| Spore | 3 | 0,28 s | 1,05 s |
| Nova | 3 | 0,30 s | 1,35 s |
| Klinge | 4 | 0,20 s | 1,25 s |
| Bastion | 3 | 0,30 s | 1,45 s |
| Phantom | 2 | 0,14 s | 1,05 s |

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

### Block (`Q`)

Jeder Held kann blocken: **0,5 s kein Schaden**, gegnerische Projektile werden **zurückgeworfen**, **4 s Abklingzeit**. Ein aktiver Block fängt auch Nahkampfschläge ab. Block-Karten verlängern ihn oder lösen Bomben, Heilzonen, Minen und Rückstoß aus.

### Dash (`Shift`)

Kurzer Sprint mit kurzer Unverwundbarkeit. Ignis hinterlässt dabei Feuer.

### Leben, Schild & Regeneration

- **HP-Regeneration** (durch Karten) läuft sofort, auch direkt nach einem Treffer.
- **Schild** lädt sich erst **3 s nach dem letzten Treffer** wieder auf. Karten verkürzen die Pause (nie unter 0,5 s). Schild-Upgrade-Karten erscheinen erst, wenn man mindestens **25 Schild** hat.
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

Jeder Eber hat eine Nahkampfwaffe auf `E` (P2: `K`). Gewählt wird sie im Lobby-Tab **Charakter**, sie wird im Profil gespeichert. Reichweite wird in Feldern (36 px) ab dem Körperrand gemessen. Wände blockieren den Schlag. Der Schlag trifft auch Blöcke, Kisten, Fässer und Türme.

| Waffe | Form | Schaden | Reichweite | Rückstoß | Abklingzeit | Besonderheit |
| :--- | :--- | ---: | ---: | :--- | ---: | :--- |
| **Lötkolben** | gerader Stich | 50 | 3 Felder | stark | 1,4 s | |
| **Schwert** | 60°-Bogen | 30 | 3 Felder | wenig | 0,9 s | |
| **Hammer** | 90°-Bogen | 20 | 1 Feld | sehr stark | 1,1 s | Prallt das Ziel danach an Wand oder Decke: 0,8 s betäubt |
| **Flegel** | 360° rundum | 30 | 2 Felder | mittel | 1,2 s | |

**Parade** (Legendary): Ist der Schlag bereit (nicht auf Abklingzeit), schlägt die Waffe von selbst in Richtung eines gegnerischen Projektils, sobald es in Reichweite ist und auf dich zufliegt, und wirft es zurück. Der Schlag trifft dabei normal und startet die Abklingzeit. Ein manueller Schlag pariert ebenfalls. Gilt auch für Bots und online.

Das Powerup **Auto-Angriff** und der Runden-Modifier **Brawl** verstärken den Nahkampf. Ist Nahkampf in den Lobby-Regeln aus, erscheinen beide nicht.

Nahkampf-Karten (Pool **Nahkampf**, 19 Karten) wirken nur auf den `E`-Schlag, siehe [Karten-Übersicht](#nahkampf-karten).

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
- Die Vorschau zeigt alles live. Das Profil wird automatisch gespeichert und online an alle verteilt.

### Tab Regeln

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
- **Seltenheits-Prozente** für Common/Uncommon/Rare/Epic/Legendary (Standard 50 / 25 / 15 / 8 / 2). Die Summe wird automatisch normalisiert.
- **Karten sperren**: Gesperrte Karten kommen in keinem Draft mehr, nach Seltenheit sortiert. Karten aus abgeschalteten Pools stehen dort abgedunkelt als gesperrt („Pool aus“). Der Host kann sie einzeln wieder freigeben („freigegeben“); Ausbaukarten einer freigegebenen Grundkarte sind dann ebenfalls frei. Wird der Pool wieder eingeschaltet, verfallen die Einzelfreigaben.
- **Filter ▾** filtert die Kartenliste nach Haupt-Tags und Sub-Tags. Innerhalb einer Gruppe reicht ein Treffer (oder), Haupt- und Sub-Tags zusammen müssen beide passen (und).
- Die Lobby zeigt `Pool min. X/Held`, also wie viele Karten der kleinste Helden-Pool noch hat.

### Tab Levels

- Zeigt **alle Maps mit Vorschaubild**. Die Bilder rendert das Spiel beim ersten Öffnen des Reiters selbst aus dem Level-Generator, neue Maps tauchen also automatisch auf.
- **Klick aufs Bild** öffnet die Großansicht mit Beschreibung. Mit `←`/`→` blättern, mit `Esc` oder Klick daneben schließen.
- Der Schalter neben dem Namen **schaltet ein Level ab**. Abgeschaltete Levels kommen bei **Zufällig** nicht mehr dran und sind unter Regeln → Spielfeld ausgegraut. **ALLE AN** / **ALLE AUS** schalten alles auf einmal. Ist kein Level aktiv, lässt sich das Match nicht starten.
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
| **Offensive** | Schaden, Munition, Projektile, Elemente | Splittergeschoss, Panzerbrecher, Brandkapsel, Kettenreaktion, Leichtes/Schweres Geschoss, Mörser, Notvorrat, Fokuskristall, Weitstrahler, Kraftladung |
| **Defensive** | Leben, Schild, Rüstung, Reflexion, Block, Größe | Sanitäter, Bollwerk, Zweites Herz, Tank-Panzerung, Stachelweste, Dornenthron, Riese, Wandelnder Koloss |
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
| Verstärkte Deckung (Uncommon, +0,3 s Block) | Ausdauerblock (Rare, +0,3 s, −10 % Abklingzeit) | – |
| Weitstrahler (Common, +25 % Fähigkeitsgröße) | Flächenbrecher (Common, +50 % Fähigkeitsgröße) | – |
| Kraftladung (Common, +25 % Fähigkeitsschaden) | Überladung (Common, +50 % Fähigkeitsschaden) | – |
| Powerup-Verstärker (Common, +25 % Powerup-Wirkung) | Powerup-Magnet (Common, +25 % Powerup-Wirkung, +2 Felder Sammelreichweite) | – |

Max-HP- und Schild-Boni auf Karten wurden verdoppelt, damit man nicht zu schnell stirbt.

### Sub-Tags

Jede Karte hat neben ihrem Pool (Haupt-Tag) beliebig viele **Sub-Tags**. Sie werden automatisch aus den Kartenwerten abgeleitet und erscheinen in der Lobby-Kartenliste unter dem Titel.

| Haupt-Tag | Sub-Tags |
| :--- | :--- |
| **Offensive** | Schaden, Feuerrate (inkl. Munition/Nachladen), Projektil, Bounce, Durchschlag, Zielsuche, Mehrfachschuss, Explosion, Element, Begleiter |
| **Defensive** | Leben, Heilung, Schild, Block, Rüstung, Reflexion |
| **Bewegung** | Tempo, Sprung, Dash, Schwerkraft, Größe (kleiner oder größer) |
| **Nahkampf** | Klinge, Reichweite, Schlagtempo, Rückstoß, Kontrolle, Elementarhieb |
| **Allgemein** | Fähigkeit (Heldenfähigkeit), Powerup (verstärkt eingesammelte Powerups), Unique (eigene Spezialmechanik) |

Sub-Tags gelten poolübergreifend: Eine Defensive-Karte kann z. B. auch „Tempo“ haben.

Kartentexte nutzen für gleiche Effekte immer dieselben Begriffe: **Tempo** (Laufgeschwindigkeit), **Max HP**, **Schild**, **Schaden**, **Feuerrate**, **Munition**, **Projektilgeschwindigkeit**, **Projektilgröße**, **Abpraller**, **Durchschlag**, **Explosionsradius**, **Sprungkraft**, **Luft-Sprung**, **Größe**, **Giftstapel**, **Giftschaden**, **HP/s Regeneration** sowie **Dash-**, **Block-**, **Fähigkeits-** und **Nahkampf-Abklingzeit**.

### Klassenkarten (je 3 pro Held)

| Held | Klassenkarten |
| :--- | :--- |
| **Ignis** | Nachbrenner, Sprengkern, Überhitzung |
| **Volt** | Overclock, Statisches Feld, Kinetische Ladung |
| **Spore** | Virulenter Stamm, Mycelnetz, Toxische Blüte |
| **Nova** | Schwerkraftkern, Leerer Raum, Supernova |
| **Klinge** | Wirbelklinge, Klingenreflexe, Duellklinge |
| **Bastion** | Energieschild, Feldwartung, Bastionsfestung |
| **Phantom** | Schattenklinge, Schattensprung, Todeskuss |

### Fähigkeitskarten (je 4 pro Held)

Eine Grundkarte (Rare) mit zwei exklusiven Evolutionen (Epic) und eine Einzelkarte (Uncommon). Evolutionen erscheinen erst mit der Grundkarte, und nur ein Zweig ist wählbar.

| Held | Grundkarte | Evolution A | Evolution B | Einzelkarte |
| :--- | :--- | :--- | :--- | :--- |
| **Ignis** | Raketentriebwerk | Napalm-Landung | Splitterlandung | Kurze Zündschnur |
| **Volt** | Hochspannung | Kettenblink | Gewitterspur | Restladung |
| **Spore** | Dichter Nebel | Ätzender Nebel | Symbiose | Sporenvorrat |
| **Nova** | Ereignishorizont | Implosion | Doppelstern | Massenanziehung |
| **Klinge** | Geschliffene Klingen | Echowirbel | Blutrausch | Tanzschritt |
| **Bastion** | Verstärkte Emitter | Schutzkuppel | Pulsfeld | Notfallprotokoll |
| **Phantom** | Lautlose Klinge | Schattenschnitt | Lähmendes Mal | Lange Schatten |

**Für alle Helden:** **Weitstrahler** (+25 % Fähigkeitsgröße) mit Evolution **Flächenbrecher** (+50 %) und **Kraftladung** (+25 % Fähigkeitsschaden) mit Evolution **Überladung** (+50 %), alle Common. Die Boni multiplizieren sich (Grundkarte + Evolution = ×1,875). *Fähigkeitsgröße* vergrößert Wirkungsradius und Effektfläche der Klassenfähigkeit samt Evolutionen (Einschlag, Schockwelle, Giftwolke, Sog, Klingenwirbel, Heilfeld-Optik, Schattenschnitt, Napalm, Blitzzonen, Splitter-Explosionen), aber **nicht** die Teleport-, Sprung- oder Wurfweite. *Fähigkeitsschaden* erhöht allen Schaden der Fähigkeit inklusive Kettenblitz, Splitter, Blitzzonen und Gift von „Ätzender Nebel“; bei Bastion steigen Heilung und Schild. Novas Singularität selbst macht keinen Schaden, deshalb bekommt Nova Kraftladung und Überladung erst angeboten, wenn „Implosion“ im Deck ist. Gesamtwerte sind gedeckelt (Größe ×2,5, Schaden ×4).

### Talentbäume

Eine Ausbaukarte erscheint erst, wenn die Grundkarte im Deck liegt. Wer einen Zweig wählt, bekommt den anderen nicht mehr angeboten.

| Familie | Grundkarte | Ausbau A | Ausbau B |
| :--- | :--- | :--- | :--- |
| **Turm** | Turm: Fähigkeit stellt eine Kanone (100 Leben) auf | Mehr Türme: alle 5 s ein weiterer | Folgende Türme: folgen dir |
| **Giftschuss** | +2 Gift-Stapel | Giftwolke am Einschlag | Giftspur hinter dir |
| **Blitzschuss** | 0,1 s Betäubung | Kettenblitz | Blitz-Orb am Einschlag |
| **Frostschuss** | 0,8 s Verlangsamung | Eisnova am Einschlag | Eisbahn hinter dir |
| **Explosivschuss** | +30 px Explosion | Großer Knall (+60 px) | Splitterbomben |
| **Feuersturm** | Geschosse entzünden | Brandherd am Einschlag | Feuerspur hinter dir |
| **Wächterdrohne** | Drohne schießt mit | Zwillingsdrohne | Regenerationsdrohne |
| **Schutzdrohne** | Drohne fängt Schüsse ab | Heilende Schutzdrohne | Schutzdrohnen-Schwarm |
| **Mörser** | Steiler Bogen, mehr Schaden | Präzisionsmörser | Belagerungsmörser |
| **Rückstoßfeder** | +25 % Rückstoß | Druckkammer | Schockgeschoss |
| **Leichte Schuhe** | Tempo | Windschuhe | |
| **Minenleger** | Blocken legt eine unsichtbare Mine | Sofortzünder: explodiert ohne Verzögerung | |
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

### Block-Karten

| Seltenheit | Karten |
| :--- | :--- |
| Common | Blockübung (+0,15 s), Schnelle Deckung (−15 % Abklingzeit) |
| Uncommon | Verstärkte Deckung (+0,3 s, Evolution: Ausdauerblock), Schildstoß (stößt weg) |
| Rare | Blockbombe, Heilzone, Druckwelle |
| Epic | Konterblitz (+50 % auf reflektierte Schüsse), Block-Experte, Unzerbrechlich |

**Minen:** Mit **Minenleger** (Rare) lässt jeder Block eine Mine fallen, die auf dem Boden darunter liegen bleibt und auf Plattformen und Wippen mitfährt. Gegner sehen sie nicht (online gar nicht, am selben Bildschirm nur schwach). Nach 2 s ist sie scharf. Läuft ein Gegner darüber, blinkt sie und explodiert 1,5 s später: 50 Schaden, 2 Felder Explosionsradius, nur gegen Gegner. Höchstens 8 Minen pro Spieler, bei der neunten verschwindet die älteste. Nur mit Minenleger im Deck gibt es **Minenschaden** (Rare, +50 Schaden) und **Minenreichweite** (Uncommon, +1 Feld Explosionsradius). Evolution A **Sofortzünder** (Epic) lässt Minen ohne Verzögerung explodieren.

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
| **Grasarena** | Arena | Luftige Balken, zentrale Wippe, Kisten, Ranken |
| **Wüstenruine** | Arena | Offene Sandinseln, Kettenplattformen, TNT |
| **Eisgrotte** | Arena | Glatte Eisflächen, schwebende Wippe, Kistenstapel |
| **Neonfabrik** | Arena | Technik-Balken, Ketten, Kisten, Powerups |
| **Weite Wiese** | Arena | Wenige Plattformen, viel Platz für Duelle |
| **Wolkeninsel** | Arena | Kleine Wolkeninseln, weite Sprünge, Wolkenfähre |
| **Uhrwerk** | Arena | Großes Zifferblatt in der Mitte: Der lange Minutenzeiger dreht sich in 16 s einmal herum, man fährt auf ihm mit. Aufzüge an den Seiten, aus zwei Trichtern fallen alle 10 s Kugeln, die der Zeiger herumschiebt |
| **Hauptplatine** | Arena | Leuchtende Leiterplatte, Datenbus-Shuttle, Chips als Deckung |
| **Kistenfestung** | Arena | Nur Holzkisten, große Wippe mit Kistentürmen |
| **Sonnentempel** | Arena | Riesige hohle Pyramide über drei Viertel der Breite (drüberlaufen oder unten hinein), Kistenkette über der Spitze |
| **Kettenwerk** | Arena | Neon-Halle voller Kistenketten, Einweg-Stege |
| **Wollhaus** | Arena | Haus mit vier Räumen, Luken und begehbarem Dach, Kisten an Ketten |
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
| **Pilzpfad** | Scrollt seitlich | Gruben, Treppen, Herz-Block, Fähre, Portale |
| **Gletscherpass** | Scrollt seitlich | Aufzüge im Abgrund, Eisfähre, hängende Wippe |
| **Lavaturm** | Scrollt nach oben | Lava steigt schon ab 4 s, Gipfel-Arena |
| **Himmelsleiter** | Scrollt nach oben | Feder, Aufzug, Wolkenfähre, Gipfelportal |

Auf Scroll-Maps folgt die Kamera dir. Gegner außerhalb des Bildes zeigen Pfeile am Rand.

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
| **HELDEN** | Übersicht aller Helden mit Werten und Fähigkeiten |
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

## 📊 Statistiken, HUD & Feedback

- **HUD**: Oben rechts das Match-Ziel, pro Spieler ein Punktebalken (im Team-Modus in Teamfarbe), Nahkampf-Status `[E]: BEREIT`.
- **Am Charakter**: Munitionsstriche bzw. Nachlade-Ring, Lebensbalken mit Schild-Overlay, Symbole für Block (mit Abklingzeit-Anzeige), Schild, Dash und Fähigkeit.
- **Tab-Charakterblatt**: Alle Werte, die Nahkampfwaffe und **KARTEN-BONI (SUMMEN)**. Geht auch während der Kartenwahl und wenn du tot bist. Ohne Blind Pick zeigt oben eine Leiste alle Spieler: bei gehaltenem Tab mit den Tasten 1–9 oder per Klick umschalten. Mit Blind Pick (online) bleibt es beim eigenen Blatt.
- **Kill-Cam**: Beim rundenentscheidenden Tod läuft das Spiel 1,6 s lang in Zeitlupe (20 %), die Kamera zoomt auf den Treffer.
- **Screenshake** bei Treffern, Kills und Explosionen.
- **Trefferanimation**: Stauchen, Zittern, rotes Aufblitzen, Blutspritzer. Dazu ein Todes-Sound.
- **Match-Ende**: Tabelle mit Punkten, Kills, Toden, Schaden, Block, Heilung, Trefferquote, Runden und Nahkampf. Dazu **MVP**, **Meister Schaden**, **meiste Blocks**, **meiste Heilung** und **Meister Nahkampf**.
- **ALLE SPIELER, KARTEN & STATS**: Nach dem Match für jeden Spieler das komplette Blatt mit Karten.
- **Rundenstatistik**: Jede Runde wird als Zeile in `round_stats.jsonl` gespeichert (für Balancing).
- **Balance-Statistik im Spiel**: Optionen → **STATISTIK**. Sortierbare Tabellen (Spaltenkopf anklicken) für **Karten**, **Waffen** und **Helden**, getrennt nach Version: Runden, geglättete Siegquote, Vergleich mit derselben Seltenheit, Kills/Tode pro Runde, Schadens- und Heilanteil, Nahkampfschaden, Pickquote und Aufstiegsvorschläge. Filter: nur menschliche Spieler, nur aktuelle Versionen, Mindestrunden für Vorschläge. Bei Helden zusätzlich **Fähigk./R** und **Fähigk.-Anteil**: Schaden aus direkten Treffern der Heldenfähigkeit samt Evolutionen (Brand/Gift danach zählt nicht), erfasst seit 28.10.2026. Die Seite **Hinweise** listet Vorschläge, Werte ohne neue Version und die automatischen Aufstiege. Hältst du die Maus 0,5 s über eine Kartenzeile oder einen Kartennamen unter Hinweise, erscheint die Karte unten links. Rechnet genauso wie `tools/analyze_round_stats.py`.

---

## 💾 Dateien & Speicherorte

Spieldaten liegen unter `%APPDATA%\Godot\app_userdata\Lötkolbeneber\`. Beim ersten Start übernimmt das Spiel automatisch die Daten aus dem alten Ordner `BattleBalls`.

| Datei | Inhalt |
| :--- | :--- |
| `settings.cfg` | Optionen: Grafik, Lautstärke, Effekt-Set, Tasten |
| `character_customization.json` | Dein Charakter, Name, Nahkampfwaffe |
| `lobby_loadouts.json` | Eigene Regel-Presets |
| `card_statistics.json` | Kartenstatistik und Aufwertungen |
| `round_stats.jsonl` | Eine Zeile pro gespielter Runde |
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
