# Heldenfähigkeiten neu entwerfen (Entwurf)

Stand: 2026-11-12. Von Jochen als Entwurf abgesegnet, noch nichts davon ist gebaut.
Grundlage ist der Code-Stand von `feature/zielbare-faehigkeiten` (enthält Druide und das Zielsystem).

## 1. Rahmen

| Taste | Heute | Neu |
|---|---|---|
| Linksklick | Schuss (alle Helden) | Hauptangriff: je nach Held **Schuss oder Nahkampf** |
| Rechtsklick | Heldenfähigkeit | **Fähigkeit** (kurze Abklingzeit, 5 bis 8 s) |
| E | Nahkampfwaffe (frei wählbar) | **Ulti** |
| Shift | Dash (für alle gleich) | **Helden-Dash** |
| Q | Barriere | Barriere (bleibt unverändert) |

Leitlinien für die Varianz:

- Jeder Held bekommt **eine Rolle**, die sonst keiner hat (Teleporter, Täuscher, Fallensteller, Schubser, Bauer …).
- Jede Mechanik gehört **genau einem Helden**: Teleport nur Volt, Unsichtbarkeit nur Phantom, Gift nur Spore, Ziehen/Schieben nur Nova, Wände nur Druide.
- Die Dashes unterscheiden sich im Bewegungsgefühl, nicht nur in Zahlen.
- Die Ulti ist der "große Moment" und hat eine lange Abklingzeit (24 bis 35 s).

### Aufteilung Nah/Fern

| Held | Typ | Waffe (Linksklick) | Rolle |
|---|---|---|---|
| Ignis | Fern | Explosivgeschosse, langsam, Flächenschaden | Bomber |
| Volt | Fern | Schnellfeuer, kleine Kugeln | Teleporter |
| Spore | Fern | Giftkugeln im Bogen | Fallensteller |
| Nova | Fern | Schwere, langsame Kugel mit viel Rückstoß | Raumkontrolle |
| Druide | Fern | Dornen, mittlere Werte | Bauer / Gestaltwandler |
| Klinge | **Nah** | Schwert (60°-Bogen, schnell) | Duellant |
| Bastion | **Nah** | Hammer (120°-Bogen, Wandbetäubung) | Tank |
| Phantom | **Nah** | Lötkolben-Stich (schmal, hoher Schaden) | Assassine |
| Zeitschläger (neu) | **Nah** | Uhrenpendel (Flegel, Rundumschlag) | Zeitmagier |

Mit dem Zeitschläger sind es vier Nahkämpfer und fünf Fernkämpfer. Die vier bestehenden Nahkampfwaffen (`Global.MELEE_WEAPON_DATA`) sind damit alle vergeben und lassen sich direkt wiederverwenden.

Damit Nahkämpfer in einem Shooter nicht untergehen, bekommen sie mehr Leben, einen Dash, der sie wirklich an den Gegner bringt, und je ein Werkzeug gegen Kugeln (Klinge: Ulti wehrt Kugeln ab, Bastion: Ramm-Schild und Kuppel, Phantom: Unsichtbarkeit, Zeitschläger: Zurückspulen und Kondensator).

### Ulti-Ladung (entschieden)

Jochen, 2026-11-12: Die Ulti läuft über eine **Abklingzeit**. Laden durch Schaden ist verworfen, weil es den Führenden noch stärker macht (Snowball).

Vorschlag für die Werte:

| Held | Ulti | Abklingzeit |
|---|---|---|
| Ignis | Meteorschauer | 28 s |
| Volt | Überladung | 26 s |
| Spore | Seuchennebel | 30 s |
| Nova | Singularität | 30 s |
| Druide | Urkeiler | 35 s |
| Klinge | Klingensturm | 24 s |
| Bastion | Festung | 32 s |
| Phantom | Nachtjagd | 28 s |
| Zeitschläger | Schadenskondensator | 30 s |

Beim Rundenwechsel gilt: Die Abklingzeit läuft einfach weiter und wird nicht zurückgesetzt, und im ersten Match-Durchgang startet die Ulti halb geladen. So kommt sie nicht in jeder Runde sofort, aber auch nicht nie.

## 2. Vorschläge pro Held

Bei jeder Fähigkeit stehen Upgrade-Ideen dabei. "Karte" meint eine einfache Zahlenkarte, "Evo" eine Evolution, die das Verhalten ändert.

### Ignis (Fern, Bomber)

- **Dash – Nachbrenner:** Normaler Dash mit Feuerspur (ist heute schon die Passive). 
  - Karte: längere Spur, Spur brennt länger. Evo: Am Ende des Dashs eine kleine Explosion.
- **Fähigkeit – Rocket Leap:** Bleibt wie heute, ist sein Markenzeichen.
  - Bestehende Karten bleiben: Raketentriebwerk, Kurze Zündschnur, Evo Napalm-Landung, Evo Splitterlandung.
- **Ulti – Meteorschauer:** Zielgebiet wählen (Zielsystem), nach 0,8 s Vorwarnung schlagen 5 Feuerbälle nacheinander in einer Linie ein und hinterlassen Feuerflächen.
  - Karte: +2 Meteore, größerer Einschlag. Evo A "Komet": ein einziger riesiger Einschlag mit starkem Rückstoß. Evo B "Flächenbrand": Feuerflächen halten doppelt so lang und breiten sich aus.

### Volt (Fern, Teleporter)

- **Dash – Blitzschritt:** Statt Dash ein kurzer Teleport (ca. 130 px) mit **2 Ladungen**. Das ist der heutige Flash Blink in klein, damit ist Volt der einzige Teleporter.
  - Karte: +1 Ladung, mehr Weite. Evo "Gewitterspur" (gibt es schon): Start- und Zielpunkt werden zu Blitzzonen. Evo "Kettenblink" (gibt es schon): Schock am Ziel springt weiter.
- **Fähigkeit – Kugelblitz:** Langsam fliegende Blitzkugel, die Gegner im Umkreis alle 0,4 s schockt (wenig Schaden, kurze Verlangsamung). Sperrt Wege ab.
  - Karte: größerer Radius, fliegt länger. Evo A "Sprungziel": Fähigkeit erneut drücken teleportiert Volt zur Kugel. Evo B "Entladung": Die Kugel explodiert am Ende und betäubt.
- **Ulti – Überladung:** 5 s lang +40 % Tempo, +50 % Feuerrate, kein Nachladen, jeder Schuss springt als Kettenblitz weiter.
  - Karte: längere Dauer. Evo A: Während der Überladung lädt der Blitzschritt sofort nach. Evo B: Am Ende entlädt sich ein Schockring.

### Spore (Fern, Fallensteller)

- **Dash – Sporenstoß:** Dash, der am Startpunkt eine kleine Giftwolke hinterlässt (das ist der heutige Spore Burst mit 45 px Radius).
  - Karte: größere Wolke. Evo "Symbiose" (gibt es schon): Die eigene Wolke heilt Spore.
- **Fähigkeit – Giftpilz:** Wirft einen Pilz an den Zielpunkt. Er bleibt liegen (max. 3 gleichzeitig) und platzt zu einer Giftwolke, sobald ein Gegner nah kommt oder er getroffen wird.
  - Karte: +1 Pilz, größere Wolke, mehr Schaden. Evo A "Ätzender Nebel" (gibt es schon): Wolke stapelt Gift. Evo B "Klebsporen": Wolke verlangsamt stark. Evo C "Sprungpilz": Spore selbst wird vom Pilz hochgeschleudert (Trampolin).
- **Ulti – Seuchennebel:** Großer Nebel um Spore (ca. 300 px, 6 s), der mit ihm mitwandert. Gegner darin sind vergiftet und verlangsamt, Spore regeneriert.
  - Karte: Radius, Dauer. Evo A "Pandemie": Vergiftete Gegner stecken andere Gegner in ihrer Nähe an. Evo B "Verwesung": Gegner im Nebel können nicht geheilt werden und regenerieren kein Schild.

### Nova (Fern, Raumkontrolle)

- **Dash – Phasengleiten:** Kein schneller Ruck, sondern 0,6 s freies Schweben in jede Richtung ohne Schwerkraft. Langsamer als ein Dash, aber steuerbar. Passt zur Passive "Schwerelos".
  - Karte: längere Dauer. Evo: Kugeln fliegen während des Gleitens durch Nova hindurch und werden dabei abgebremst.
- **Fähigkeit – Gravitationsstoß:** Stoßwelle im Kegel nach vorn. Schleudert Gegner weg und lenkt Kugeln ab. Nach unten gezielt katapultiert sie Nova selbst nach oben.
  - Karte: breiterer Kegel, mehr Rückstoß. Evo A "Wandschlag": Gegner, die gegen eine Wand fliegen, nehmen Schaden und sind kurz betäubt. Evo B "Umkehr": Abgelenkte Kugeln gehören danach Nova.
- **Ulti – Singularität:** Die heutige Fähigkeit, aber größer und mit Implosion am Ende als Standard. Als Ulti darf sie endlich so stark sein, wie sie sich anfühlt.
  - Bestehende Karten bleiben: Ereignishorizont, Massenanziehung, Evo Doppelstern. Neue Evo "Schwarzes Loch": Schluckt auch Kugeln und schleudert sie bei der Implosion wieder heraus.

Mit Stoß auf Rechtsklick und Sog auf E hat Nova ein Schieben-und-Ziehen-Kit, das sich selbst kombiniert.

### Druide (Fern, Bauer und Gestaltwandler)

- **Dash – Rankenschwung:** Schießt eine Ranke in Zielrichtung. Trifft sie Gelände (bis ca. 220 px), zieht sie den Druiden dorthin. Ohne Treffer ein normaler kurzer Dash. Aufwendiger zu bauen als die anderen Dashes.
  - Karte: mehr Reichweite. Evo A: Trifft die Ranke einen Gegner, wird der kurz festgehalten. Evo B: Die Ranke hält auch an eigenen Wurzelwänden und setzt dabei die Dash-Abklingzeit zurück.
- **Fähigkeit – Wurzelwall:** Bleibt wie gerade gebaut, mit allen Karten und den drei Evolutionen.
- **Ulti – Urkeiler:** Der Druide verwandelt sich 7 s lang in einen riesigen Keiler: doppelte Größe, +60 % Leben für die Dauer, Linksklick wird zum Hauer-Nahkampf, der Dash wird zum Ansturm, der Gegner wegschleudert und zerstörbares Gelände durchbricht.
  - Karte: längere Dauer, mehr Schaden. Evo A "Raserei": Jeder Treffer verlängert die Gestalt um 0,5 s. Evo B "Dornenfell": Reflektiert in der Gestalt einen Teil des Schadens.
  - Alternative, falls die Verwandlung zu aufwendig ist: **Wurzelgriff**, ein großes Feld, das Gegner 1,5 s am Boden festhält (sie können noch schießen).

### Klinge (Nah, Duellant)

- **Linksklick – Schwert:** Schnelle Hiebe im 60°-Bogen. Idee: Der dritte Treffer in Folge ist ein stärkerer Stich.
- **Dash – Durchstoß:** Dash, der Gegner auf dem Weg trifft und durch sie hindurchgeht. Bei einem Treffer halbiert sich die Abklingzeit.
  - Karte: mehr Schaden, mehr Weite. Evo: Treffer setzt die Abklingzeit ganz zurück (einmal pro 4 s).
- **Fähigkeit – Klingenbumerang:** Wirft das Schwert in Zielrichtung, es kehrt zurück und trifft auf beiden Wegen. Gibt dem Nahkämpfer einen Stich auf Distanz. Während das Schwert fliegt, kann Klinge nicht zuschlagen.
  - Karte: mehr Weite, mehr Schaden. Evo A "Blutung": Treffer lassen den Gegner bluten und markieren ihn. Evo B "Fangen": Fängt Klinge das Schwert im Dash, ist die Fähigkeit sofort wieder bereit.
- **Ulti – Klingensturm:** Die heutige Fähigkeit als Ulti: 3 s wirbeln, dabei frei laufen, Schaden pro Tick im Umkreis, **Kugeln werden abgewehrt**. Das ist das Werkzeug, um an Schützen heranzukommen.
  - Bestehende Karten bleiben: Geschliffene Klingen, Tanzschritt, Evo Echowirbel, Evo Blutrausch.

### Bastion (Nah, Tank)

- **Linksklick – Hammer:** Langsam, schleudert weg, Wandbetäubung wie heute.
- **Dash – Rammbock:** Kurzer, wuchtiger Ansturm mit Schild voraus. Blockt Kugeln von vorn, schiebt Gegner mit und stößt sie am Ende weg. Dafür nicht unverwundbar von hinten.
  - Karte: mehr Weite, mehr Rückstoß. Evo: Wird ein Gegner gegen eine Wand gerammt, ist er betäubt und Bastion bekommt Schild.
- **Fähigkeit – Magnethaken:** Schießt einen Haken. Trifft er einen Gegner, wird der zu Bastion gezogen und ist 0,3 s benommen. Trifft er Gelände, passiert nichts (der Greifhaken gehört dem Druiden).
  - Karte: mehr Reichweite, kürzere Abklingzeit. Evo A "Kettenschlag": Der nächste Hammerschlag nach einem Treffer macht doppelten Schaden. Evo B "Magnetfeld": Der Haken zieht auch Kugeln und Powerups in seiner Bahn an.
- **Ulti – Festung:** Kuppel an der eigenen Position (5 s). Gegnerische Kugeln von außen prallen ab, innen wird geheilt und Schild aufgebaut (für Bastion und Verbündete). Das heutige Heilfeld geht darin auf.
  - Bestehende Karten ziehen um: Verstärkte Emitter, Notfallprotokoll, Evo Schutzkuppel, Evo Pulsfeld. Neue Evo "Wanderfestung": Die Kuppel folgt Bastion.

### Phantom (Nah, Assassine und Täuscher)

- **Linksklick – Stich:** Schneller, schmaler Stich mit hohem Schaden. Treffer aus der Unsichtbarkeit oder in den Rücken machen +50 %.
- **Dash – Schattenschritt:** Dash, nach dem Phantom 0,8 s unsichtbar ist (die Unsichtbarkeit gibt es schon als Powerup).
  - Karte: längere Unsichtbarkeit. Evo: Der Dash hinterlässt am Startpunkt ein Nachbild, das Bots und Zielsuche kurz ablenkt.
- **Fähigkeit – Köder:** Ein Doppelgänger läuft in Blickrichtung weiter, Phantom selbst wird 1,5 s unsichtbar. Bots, Türme, Drohnen und Zielsuche nehmen den Köder.
  - Karte: Köder hält länger, hat mehr Leben. Evo A "Sprengköder": Explodiert, wenn er zerstört wird oder abläuft. Evo B "Platztausch": Fähigkeit erneut drücken tauscht den Platz mit dem Köder. Evo C "Lähmendes Mal" (gibt es schon): Wer den Köder schlägt, wird betäubt.
- **Ulti – Nachtjagd:** 6 s unsichtbar und +30 % Tempo. Angriffe machen nur kurz sichtbar (Flackern). Der erste Treffer macht doppelten Schaden.
  - Karte: längere Dauer. Evo A "Blutspur": Ein Kill in der Nachtjagd gibt die halbe Ulti-Ladung zurück. Evo B "Dunkelheit": Gegner in der Nähe sehen für die Dauer nur einen kleinen Kreis um sich (nur sinnvoll bei eigenen Bildschirmen).

Der Teleport von Phantom entfällt ganz. So ist der Unterschied zu Volt klar: Volt ist überall gleichzeitig, Phantom ist nicht zu sehen.

### Zeitschläger (Nah, Zeitmagier) – neuer Held von Jochen

Das Kit stammt von Jochen (2026-11-12), die Zahlen und Karten sind mein Vorschlag.

- **Linksklick – Uhrenpendel:** Der Flegel, gezeichnet als Pendel an einer Kette. Kreist einmal komplett um den Eber (2 Felder Reichweite, 30 Schaden, 1,2 s Abklingzeit wie der heutige Flegel).
- **Dash – Zurückspulen:** Springt an die Position von vor 3 s zurück. Ein blasses Nachbild zeigt dem Spieler selbst die ganze Zeit, wo er landen würde. Nur die Position wird zurückgedreht, das Leben nicht. Abklingzeit 5 s statt 1,8 s, weil der Dash sehr stark ist.
- **Fähigkeit – Vorspulen:** 5 s lang +50 % Angriffs- und Bewegungstempo. Abklingzeit 10 s ab Ende der Wirkung.
- **Ulti – Schadenskondensator:** Absorbiert 3 s lang sämtlichen Schaden. Danach bekommt jeder Verursacher seinen Schaden zurück. Abklingzeit 30 s.

Regeln, die ich dafür festlegen würde:

- Der Rückschlag läuft über das vorhandene Reflexionssystem (`take_damage` mit `is_reflected`), damit zwei Kondensatoren oder Reflexions-Tanks sich nicht gegenseitig hochschaukeln.
- Schaden ohne Verursacher (Zone, Stacheln, Sturz) wird absorbiert, aber nicht zurückgegeben.
- Rückstoß und Betäubung wirken während des Kondensators weiter. Sonst wäre die Ulti eine reine Unverwundbarkeit und gegen Nahkämpfer nicht zu kontern.
- Über dem Eber läuft sichtbar ein Zähler mit dem gespeicherten Schaden. Gegner sollen merken: jetzt nicht draufhalten.
- Bots hören auf zu schießen, solange der Kondensator läuft.

Das ergibt eine schöne Kombo: Vorspulen an, reinlaufen, Pendel schwingen, Kondensator zünden, wenn alle draufhalten, und am Ende mit Zurückspulen wieder raus.

**Karten zum Zeitschläger**

Klassenkarten (Werte):

| Karte | Seltenheit | Wirkung |
|---|---|---|
| Taktgeber | Common | +20 % Nahkampftempo, +10 % Tempo |
| Schweres Pendel | Uncommon | +30 % Nahkampfschaden, +0,5 Felder Reichweite, -10 % Nahkampftempo |
| Unruh | Uncommon | -20 % Dash-Abklingzeit, -15 % Fähigkeits-Abklingzeit |
| Lange Erinnerung | Rare | Zurückspulen reicht 4,5 s statt 3 s zurück |
| Überdreht | Uncommon | Vorspulen gibt +65 % statt +50 % Tempo |
| Dauerlauf | Common | Vorspulen hält 2 s länger |
| Großer Kondensator | Rare | Schadenskondensator hält 1 s länger |
| Verstärker | Rare | Der Kondensator gibt 130 % des Schadens zurück |
| Schnellladung | Uncommon | -15 % Ulti-Abklingzeit |

Evolutionen (je Fähigkeit eine Familie, man wählt einen Zweig):

| Familie | Zweig | Karte | Wirkung |
|---|---|---|---|
| Pendel | A | Tick-Tack | Das Pendel schwingt nach 0,3 s mit 60 % Schaden zurück (nutzt das vorhandene Schlag-Echo). |
| Pendel | B | Stundenschlag | Jeder vierte Treffer macht doppelten Schaden und betäubt 0,5 s. |
| Zurückspulen | A | Zeitriss | Am Abreise- und am Ankunftspunkt entsteht eine kleine Explosion mit Rückstoß. |
| Zurückspulen | B | Heile Vergangenheit | Gibt zusätzlich 50 % des Lebens zurück, das in den letzten 3 s verloren ging. |
| Zurückspulen | C | Zeitecho | An der verlassenen Stelle schlägt 1 s später ein Echo des Pendels zu. |
| Vorspulen | A | Zeitlupe | Gegner im Umkreis von 150 px sind währenddessen 30 % langsamer. |
| Vorspulen | B | Zeitraffer | Dash und Barriere laden während Vorspulen doppelt so schnell nach. |
| Kondensator | A | Entladung | Der gespeicherte Schaden entlädt sich zusätzlich zu 50 % als Explosion um den Zeitschläger (180 px). Wirkt auch bei Schaden ohne Verursacher. |
| Kondensator | B | Zeitschuld | Der zurückgezahlte Schaden heilt den Zeitschläger zu 30 %. |
| Kondensator | C | Stillstand | Wer Schaden zurückbekommt, ist 1 s eingefroren. |

Worauf man beim Balancing achten muss: "Heile Vergangenheit" und "Zeitschuld" zusammen machen ihn sehr zäh, deshalb sollte höchstens eine der beiden als Legendary zählen. "Lange Erinnerung" macht das Nachbild schwerer einzuschätzen, das ist gewollt.

## 3. Übersicht

| Held | Typ | Dash | Fähigkeit | Ulti |
|---|---|---|---|---|
| Ignis | Fern | Nachbrenner (Feuerspur) | Rocket Leap | Meteorschauer |
| Volt | Fern | Blitzschritt (Teleport, 2 Ladungen) | Kugelblitz | Überladung |
| Spore | Fern | Sporenstoß (Giftwolke) | Giftpilz (Falle) | Seuchennebel |
| Nova | Fern | Phasengleiten (Schweben) | Gravitationsstoß | Singularität |
| Druide | Fern | Rankenschwung (Greifhaken) | Wurzelwall | Urkeiler |
| Klinge | Nah | Durchstoß | Klingenbumerang | Klingensturm |
| Bastion | Nah | Rammbock | Magnethaken | Festung |
| Phantom | Nah | Schattenschritt | Köder | Nachtjagd |
| Zeitschläger | Nah | Zurückspulen | Vorspulen | Schadenskondensator |

Neu zu bauen: 8 Dashes (Ignis hat seinen schon), 7 Fähigkeiten (Rocket Leap und Wurzelwall bleiben), 6 Ultis (Singularität, Klingensturm und Festung bauen auf Vorhandenem auf), dazu der Zeitschläger als neunter Held mit Icon und Outfit.

## 4. Folgen für die Karten

1. **Filter nach Angriffsart.** Karten bekommen ein Feld wie `attack_type` ("ranged", "melee" oder leer). Der Pool "Nahkampf" (19 Karten) erscheint nur noch bei Nahkämpfern, Schusskarten (Abpraller, Zielsuche, Durchschlag, Mehrfachschuss, Projektiltempo, Munition, Nachladen …) nur bei Fernkämpfern.
2. **Nahkämpfer haben sonst zu wenig Auswahl.** Die Elementkarten (Gift, Feuer, Frost, Blitz) sollten bei Nahkämpfern auf die Schläge wirken. Die Felder dafür gibt es schon (`melee_poison_stacks_add`, `melee_burn_stacks_add` usw.), die Karten müssten nur beide Seiten bedienen. Türme und Drohnen bleiben für alle.
3. **Klassenkarten mit Schusswerten** bei Nahkämpfern umbauen: Wirbelklinge (Feuerrate), Schattenklinge (Durchschlag), Todeskuss, Feldwartung (Nachladen).
4. **Fähigkeitskarten brauchen ein Ziel.** Heute wirken `ability_*_mult` auf "die" Fähigkeit. Vorschlag: Die allgemeinen Karten (Weitstrahler, Kraftladung, Abklingzeit) wirken auf Fähigkeit **und** Ulti, die Klassenkarten nennen ihr Ziel ausdrücklich. Neu dazu: eine allgemeine Karte "Ulti-Abklingzeit kürzer". Die bestehenden Karten für Fähigkeits-Abklingzeit sollten auf die Ulti nur halb wirken, sonst wird sie zu häufig.
5. **Dash-Karten.** Die allgemeinen Abklingzeit-Karten bleiben. Jeder Held bekommt ein bis zwei eigene Dash-Karten. Bei Volt wirkt "Dash-Abklingzeit" auf das Nachladen der Ladungen.
6. **Umzug bestehender Evolutionen.** Flash-Blink-Evos wandern zum Blitzschritt, Spore-Burst-Evos zum Giftpilz und Sporenstoß, Heilfeld-Evos zur Festung. Die Schattensprung-Evos "Schattenschnitt" und "Lange Schatten" entfallen oder werden umgeschrieben.
7. **Turm-Karte** ("Spezialfähigkeit platziert zusätzlich einen Turm"): festlegen, dass sie an der Fähigkeit auf Rechtsklick hängt.
8. **Balance-Versionen:** Alle Helden und Fähigkeiten bekommen eine neue Version, die Statistik beginnt für sie neu.

Was sonst noch dranhängt:

- Die freie Wahl der Nahkampfwaffe im Charakter-Tab entfällt, ebenso die Lobby-Regel "Nahkampf an/aus".
- Powerup "Auto-Angriff" und Modifier "Rauferei" wirken heute auf die Nahkampfwaffe und brauchen eine neue Bedeutung (zum Beispiel Angriffstempo für alle).
- Bots brauchen pro Held Regeln für Ulti, Fähigkeit und Dash, die Nahkampf-Bots müssen aktiv auf den Gegner zugehen.
- Spieler 2 an der Tastatur braucht eine Taste für die Ulti (heute K = Nahkampf, das passt).
- HUD: dritte Anzeige für die Ulti-Ladung.

## 5. Freier Ideenpool

Noch keinem Helden zugeordnet, für spätere Helden oder als Ersatz:

**Fähigkeiten**
- **Netzwurf:** Projektil, das den Getroffenen 1 s am Boden festhält.
- **Rückstoß-Schuss:** Starker Schuss, der den Schützen nach hinten schleudert.
- **Spiegelschild:** 1 s lang ein Schild nach vorn, das Kugeln zurückwirft (überschneidet sich mit der Barriere, daher eher nicht).
- **Zeitblase:** Zone, in der Kugeln und Gegner auf 40 % Tempo fallen.
- **Portalpaar:** Zwei Portale setzen, Spieler und Kugeln reisen hindurch.
- **Öllache:** Rutschige Fläche, die brennt, wenn Feuer sie trifft (Kombo mit Ignis).
- **Magnetmine:** Haftet am ersten Gegner in der Nähe und explodiert nach 2 s.
- **Tauschschuss:** Projektil, das bei Treffer die Plätze tauscht.
- **Sprungfeld:** Trampolin für alle Spieler.

**Ultis**
- **Todesmal:** Markiert einen Gegner, er nimmt 5 s lang +30 % Schaden und ist immer sichtbar. Erneut drücken springt hinter ihn (wäre die Teleport-Variante für Phantom).
- **Orbitallaser:** Senkrechter Strahl, der langsam dem Mauszeiger folgt.
- **Zeitstopp:** Alle Gegner und Kugeln frieren 1,5 s ein.
- **Schwarmdrohnen:** 6 kleine Drohnen jagen 6 s lang den nächsten Gegner.
- **Erdbeben:** Alle Gegner am Boden werden hochgeworfen und betäubt, zerstörbare Blöcke brechen.
- **Riesenwuchs für alle:** Vergrößert alle Gegner (leichter zu treffen, langsamer).

**Dashes**
- **Raketenrucksack:** Kurzer Schub nach oben, lässt sich in der Luft halten.
- **Rolle:** Kurze Rolle am Boden, lädt dabei die Waffe nach.
- **Rückwärtssalto:** Springt vom Ziel weg und feuert dabei einen Schuss.
- **Wandlauf:** Dash an einer Wand entlang hebt die Schwerkraft kurz auf.
- **Eisrutsche:** Dash hinterlässt eine Eisbahn, auf der alle rutschen.

**Neue Helden-Archetypen**
- **Scharfschütze** (ein Schuss, lange Ladezeit, Dash = Rückwärtssalto).
- **Beschwörer** (Türme und Drohnen als Kern statt als Karte).

## 6. Entscheidungen (Jochen, 2026-11-12)

1. Die Ulti läuft über eine Abklingzeit. Sie läuft beim Rundenwechsel weiter und wird nicht zurückgesetzt, im ersten Durchgang startet sie halb geladen.
2. Nahkämpfer sind Klinge, Bastion, Phantom und Zeitschläger. Fernkämpfer sind Ignis, Volt, Spore, Nova und Druide.
3. Der Druide bekommt die Urkeiler-Verwandlung als Ulti.
4. Zeitschläger: Zurückspulen mit 5 s Abklingzeit und Nachbild. Beim Kondensator wirken Rückstoß und Betäubung weiter, Schaden ohne Verursacher wird geschluckt, aber nicht zurückgegeben.
5. Reihenfolge beim Bauen: zuerst das Grundgerüst (Angriffsart pro Held, Ulti auf E mit Abklingzeit, Kartenfilter), dann Phantom und Volt als Pilot, danach die übrigen Helden und der Zeitschläger.
