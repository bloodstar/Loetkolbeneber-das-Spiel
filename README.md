# 🎮 Battle Balls

Ein rasantes 2D-Multiplayer-Plattform-Duellspiel in **Godot 4.6**, inspiriert von:
- **[Rounds](https://landfall.se/rounds)**: 1v1 Arena-Kämpfe, physikbasiertes Gunplay und der ikonische **5-Karten-Upgrade-Draft** für den Rundenverlierer!
- **[Bapbap](https://bapbap.gg/)**: Einzigartige Hero-Klassen mit passiven Traits und aktiven Fähigkeiten.
- **Super Mario**: Dynamisch generierte Sidescroller-Arenen mit Sprungfedern, Warp-Pipes, Fragezeichenblöcken, Stacheln und steigender Sudden-Death-Lava.
- **Integrierte Bot-KI**: Ermöglicht sofortiges Solo-Testen und Üben ohne zweiten Mitspieler.

---

## 🌟 Features

### 1. Bapbap Hero-Klassen
| Held | Rolle | HP / Tempo | Passive Fähigkeit | Aktive Fähigkeit |
| :--- | :--- | :--- | :--- | :--- |
| **Ignis** | Pyro Skirmisher | 100 HP / 310 Speed | **Afterburner**: Hinterlässt Feuerspur beim Dash | **Rocket Leap**: Explosiver Sprung mit AOE-Knockback |
| **Titan** | Armored Brawler | 140 HP / 260 Speed | **Ironclad**: 30 Start-Schild & Standfestigkeit | **Fortress Barrier**: 2.8s undurchdringlicher Schild |
| **Volt** | Hyper Speedster | 85 HP / 350 Speed | **Overcharge**: Permanenter Doppelsprung | **Flash Blink**: Sofortiger 220px Teleport |
| **Spore** | Toxic Alchemist | 105 HP / 295 Speed | **Spore Coat**: Angriffe vergiften Gegner (DoT) | **Spore Burst**: Hinterlässt toxische Giftgaswolke |

*Tipp: Im Hauptmenü auf „Spiel starten“ klicken – danach landet man in der Lobby.*

---

### 2. Lobby & Match-Regeln
Nach dem Start im Hauptmenü öffnet sich die **Lobby**:
- **Heldenwahl** für Spieler 1 und Spieler 2 – Spieler 2 kann per Checkbox als **Bot** gesteuert werden.
- **Bereit-System**: jeder menschliche Spieler bestätigt mit „Bereit“; Bots sind automatisch bereit. Der Start ist erst möglich, wenn alle bereit sind.
- **Host**: Spieler 1 ist Host und darf Match-Regeln, Draft-Konfiguration und Kartenbans ändern sowie das Match starten.
- **Rundensiege bis zum Match-Sieg**: 1–10, Standard **3**.
- **Basis-Hitpoints**: einstellbar von **0–500** (0 = Heldenwert). Der Wert gilt für beide Spieler und wird vor allen Kartenboni angewendet.
- **Karten-Draft konfigurieren**: „Wähle **X von Y** Karten“ – Standard **1 von 5**.
- **Draft-Anzeige in der Lobby**: Die Lobby zeigt dauerhaft `Draft: X von Y`, die nötigen Rundensiege, die Basis-HP und den Kartenvorrat beider Helden (P1/P2). Während der Runde gibt es dafür keine HUD-Anzeige mehr.
- **Powerup-Karten sperren**: gesperrte Karten erscheinen in keinem Draft mehr; mindestens eine Karte muss pro Pick verfügbar bleiben. Klassenspezifische Karten zählen dabei nur für den passenden Helden.
- **Start-Countdown**: Nach dem Rundenaufbau läuft ein großer **3-Sekunden-Countdown**. Erst danach werden Bewegung, Schießen, Dash, Fähigkeit, Bot-KI und Begleiter aktiv. Der eigene Charakter blinkt zum Start kurz auf. Sudden Death beginnt erst nach dem Countdown.
- **Bot-Steuerung nur in der Lobby**: Die P2-Checkbox legt fest, ob Spieler 2 ein Bot ist. Während der Runde gibt es bewusst keinen F1- oder HUD-Umschalter.
- **Zurück**: führt ohne Match-Start zurück ins Hauptmenü.

Die Auswahl liegt zentral in `Global` (Helden-Slots pro Spieler, `host_player_index`/`local_player_index`, Ready-Status, Match-Regeln, Sperrliste). Im Online-Modus übermitteln Netzwerk-Clients ihre eigene Heldenwahl und ihren Ready-Status, während Match-Regeln, Kartenbans und der Start beim Host liegen.

---

### 3. Der 5-Karten-Draft (Rounds Roguelike Comeback)
Der Rundenverlierer bekommt nach jeder Niederlage **Y zufällige Karten** (Common, Uncommon, Rare, Epic, Legendary) und wählt davon **X** aus. Jede Karte darf pro Spieler nur **einmal** im Deck liegen; besessene Karten werden nicht erneut angeboten. Upgrades stapeln sich über das Match:
- **Common – Grundwerte**: Karten wie **Vitaler Kern** (+30 Max HP), **Leichtfüßig** (+12% Tempo), **Scharfe Munition** (+20% Schaden) und **Abpraller** (+1 Abpraller) verbessern die Basiswerte.
- **Uncommon – Spezialisierung**: **Regenerationsserum** (1,5 HP/s nach 3s ohne Schaden), **Blutdurst** (+12% Lebensraub), **Kompakte Statur** (15% kleinere Spielfigur), **Zwillingsschuss** (+1 Projektil) und **Flipper-Modus** (+3 Abpraller).
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
| **Titan** | **Bollwerk** (+50 Schild, +25 Max HP, -10% Tempo), **Reaktive Panzerung** (+30 Schild, +60% Schild-Regeneration, +20% Max HP), **Festungsprotokoll** (+1,5s Barriere, -20% Ability-CD, +15% Schaden) |
| **Volt** | **Overclock** (-25% Ability-CD, +15% Tempo, +20% Feuerrate), **Statisches Feld** (+2 Abpraller, +30% Projektilgeschwindigkeit, +1 Durchschlag), **Kinetische Ladung** (-35% Dash-CD, +1 Luft-Sprung, +20% Tempo) |
| **Spore** | **Virulenter Stamm** (+4 Gift-Stapel, +15% Schaden), **Mycelnetz** (+35 Max HP, +25 Schild, +20% Schild-Regeneration), **Toxische Blüte** (+3 Gift-Stapel, +45px Explosionsradius, +15% Lebensraub) |

#### Talentbaum-Karten
Zusätzlich gibt es **7 globale Talentbaum-Familien** mit je **1 Grundkarte + 2 Ausbaukarten** (insgesamt **21 Karten**). Eine Ausbaukarte erscheint erst im Draft, wenn die Grundkarte bereits im eigenen Deck liegt. Sind beide Zweige einer Familie noch offen, werden sie gemeinsam angeboten (z. B. **Mehr Türme** und **Folgende Türme**). Jede Karte ist pro Spieler nur einmal verfügbar.

| Familie | Grundkarte | Ausbau A | Ausbau B |
| :--- | :--- | :--- | :--- |
| **Turm** | **Turm**: Spezialfähigkeit platziert einen automatisch angreifenden Turm. | **Mehr Türme**: Alle 5 Sekunden entsteht ein weiterer Turm an der aktuellen Position. | **Folgende Türme**: Türme folgen der Spielfigur. |
| **Giftschuss** | **Giftschuss**: +2 Gift-Stapel, +25% Gift-Schaden. | **Giftwolke**: Giftwolke an jeder Einschlagstelle. | **Giftspur**: Giftspur hinter dem Charakter, ohne Selbstschaden. |
| **Blitzschuss** | **Blitzschuss**: Betäubt Gegner für 0,1 Sekunden. | **Kettenblitz**: Springt auf nahe Gegner über und betäubt erneut. | **Blitz-Orb**: Erzeugt am Einschlag eine betäubende Blitzzone. |
| **Frostschuss** | **Frostschuss**: Geschosse verlangsamen Gegner für 0,8 Sekunden. | **Eisnova**: Gefrierende Fläche am Einschlag. | **Eisbahn**: Verlangsamende Spur hinter dem Charakter. |
| **Explosivschuss** | **Explosivschuss**: +30px Explosionsradius, +5% Schaden. | **Großer Knall**: +60px Explosionsradius, +15% Schaden. | **Splitterbomben**: Explosionen zerfallen in vier Splitterbomben. |
| **Feuersturm** | **Feuersturm**: Geschosse entzünden Gegner. | **Brandherd**: Brennender Boden am Einschlag. | **Feuerspur**: Brennende Spur hinter dem Charakter, ohne Selbstschaden. |
| **Wächterdrohne** | **Wächterdrohne**: Eine Drohne umkreist und beschießt Gegner. | **Zwillingsdrohne**: Eine zweite Drohne begleitet dich. | **Schutzdrohne**: Drohnen regenerieren zusätzlich Lebenspunkte. |

Der Kartenpool umfasst damit **87 Karten**. Talentbaum-Karten sind in Lobby, Draft und Auflösung mit einem Talentbaum-Badge markiert.

---

### 4. Dynamische Super-Mario-Sidescroller-Arenen
Jede Runde generiert eine prozedural balancierte Arena. Im Online-Modus bauen Host und Client dieselbe Karte aus einem gemeinsamen Seed:
- **Keine Seiten- oder Deckenwände**: Die Arena ist nach oben und zu den Seiten offen.
- **Gummiwand**: Außerhalb der Karte liegt ein viergeteilter Neon-Rahmen. Wer ihn berührt, nimmt Schaden und wird mit Nachdruck zurück in Richtung Kartenmitte geschleudert.
- **Zerstörbare Blöcke**: Halten 3 Treffer aus und verschwinden dann dauerhaft – neue Wege und Sichtlinien entstehen.
- **Starke Ranken**: Solide grüne Rankenbrücken, die nur durch Beschuss brechen und nach 8 Sekunden nachwachsen.
- **Schwache Ranken**: Zerbrechen bereits beim Darübergehen und wachsen nach 4,5 Sekunden nach. Nicht zu lange stehen bleiben!
- **Eisflächen**: Blau schimmernde Zonen mit deutlich reduzierter Beschleunigung und Reibung – Schwung holen, aber rechtzeitig bremsen.
- **Sprungfedern (Jump Pads)**: Katapultieren Spieler hoch in die Luft für akrobatische Ausweichmanöver.
- **Warp-Pipes**: Verknüpfte Röhren teleportieren Spieler blitzschnell über das Kampffeld.
- **Fragezeichen-Blöcke (Mystery Blocks)**: Von unten anspringen oder anschießen belohnt mit +30 HP Heilung!
- **Stachelfallen**: Gefährliche Zonen, die Schaden zufügen und Spieler wegschleudern.
- **Sudden-Death-Lava**: Dauert ein Duell nach dem Start-Countdown länger als 38 Sekunden, steigt von unten glühende Lava empor!

---

### 5. Rudimentäre Bot-KI (Solo-Testing)
- Spieler 2 wird standardmäßig von einer **automatischen Bot-KI** gesteuert.
- Die KI springt über Hindernisse, zielt mit dynamischer Streuung, feuert mit Sichtlinien-Prüfung, nutzt Dashs & Fähigkeiten und wählt nach Rundenverlusten selbstständig Synergie-Karten aus.
- Die Bot-Steuerung wird **ausschließlich in der Lobby** über die P2-Checkbox gewählt. Während der Runde gibt es keinen F1- oder HUD-Umschalter mehr. Im Online-Modus ist der Bot-Slot deaktiviert.

---

## 🌐 Online-Multiplayer (Host & Freund)

Das Spiel nutzt **ENet über UDP** (Standardport **7777**) und kommt ohne Relay-Server aus. Der Host ist Spieler 1 und autoritativ: Er simuliert die Runde, zieht die Draft-Karten und entscheidet über Runden-/Match-Ende. Der Client ist Spieler 2, sendet seine Eingaben an den Host und sieht die Welt als Replik.

### 1. Verbindung herstellen
1. **Beide** starten dieselbe Spielversion (idealerweise die exportierte `.exe`).
2. **Host**: Hauptmenü → **ONLINE SPIELEN** → Port stehen lassen (`7777`) → **HOST ÖFFNEN**.
3. **Freund**: Hauptmenü → **ONLINE SPIELEN** → IP-Adresse des Hosts und Port eingeben → **BEITRETEN**.
4. In der Lobby wählt der Client seinen Helden und setzt **Bereit**. Der Host stellt Regeln, Draft und Kartenbans ein, setzt ebenfalls **Bereit** und startet.

> **Steuerung im Online-Modus:** Der Client spielt trotz „Spieler 2“ mit der **P1-Steuerung** (WASD + Maus). Die Pfeiltasten-Steuerung gilt nur für den lokalen 2-Spieler-Modus.

### 2. Die richtige IP-Adresse finden

**Im selben WLAN (LAN):**
- Die Lobby zeigt die lokale IPv4 des Hosts an (z. B. `192.168.1.42`). Diese IP + Port `7777` gibt der Host an den Freund weiter.

**Über das Internet – Weg A: UPnP (automatisch):**
- Viele Router erlauben Programmen, den UDP-Port selbst freizugeben. Das Spiel versucht das automatisch und zeigt bei Erfolg die **öffentliche IP + Port** in der Lobby an.
- Diese Adresse teilt der Host dem Freund mit. Fertig.

**Über das Internet – Weg B: Portfreigabe im Router (falls UPnP scheitert):**
1. Im Router eine **Portweiterleitung** für **UDP 7777** auf die lokale IPv4 des Host-Rechners einrichten.
2. Die eigene **öffentliche IPv4** ermitteln (z. B. über eine Suchmaschine „meine IP“).
3. Freund trägt `öffentliche IP` + Port `7777` ein.
4. In der Windows-Firewall Godot bzw. die Spiel-`.exe` für **private Netzwerke** erlauben.

**Über das Internet – Weg C: ZeroTier oder Tailscale (empfohlen, wenn Weg A/B nicht gehen):**
- Beide installieren **ZeroTier** oder **Tailscale** (kostenlos für Privatnutzung) und treten demselben virtuellen Netzwerk bei.
- Der Host teilt seine **virtuelle IP** (bei Tailscale meist `100.x.x.x`, bei ZeroTier z. B. `10.x.x.x`).
- Der Freund trägt diese IP + Port `7777` ein. Router und Firewall müssen dafür meist nicht angepasst werden.
- Das ist besonders hilfreich bei **CGNAT** (wenn die öffentliche IP vom Provider geteilt wird und Portfreigaben nicht funktionieren).

### 3. Was synchronisiert wird
- Heldenwahl, Ready-Status, Match-Regeln, Draft-Konfiguration, Kartenbans und **Basis-HP**.
- Level (gemeinsamer Seed), Spielerpositionen, Geschosse, Treffer, Leben/Schilde, Lava und Sudden Death.
- Start-Countdown: Beide Seiten zeigen **3, 2, 1, LOS!**; der Host gibt die Steuerung nach Ablauf frei.
- Türme werden als Netzwerk-Entitäten repliziert. Flächeneffekte (Gift, Feuer, Eis, Blitz) und Spuren werden per zuverlässigem RPC erzeugt. Drohnen laufen auf dem Client visuell mit.
- Spezial-Tiles: Zerstörte Blöcke und nachwachsende Ranken werden per zuverlässigem RPC synchronisiert. Eisflächen und die Gummiwand werden host-seitig simuliert.
- Draft-Angebot und Picks (der Host bestätigt jede Wahl), Rundensiege und Match-Ende.
- Der Client sieht dasselbe Sieger-Panel; „HAUPTMENÜ“ trennt die Verbindung und führt zurück ins Menü.

### 4. Bekannte Grenzen
- Nur **1 gegen 1**; es gibt keinen Zuschauer- oder Relay-Modus.
- Kein Reconnect mitten im Match: Verlässt der Client das Spiel, kehrt der Host ins Hauptmenü zurück (und umgekehrt).
- Kern-Entitäten (Türme, Flächeneffekte, Geschosse) werden repliziert; einzelne Partikel-/Sound-Effekte werden weiterhin host-seitig berechnet und können beim Client fehlen.
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
- **Held-Fähigkeit**: `Rechtsklick` oder `E`

### Spieler 2 (Tastatur / lokaler 2-Spieler-Modus)
*Gilt nur für den lokalen 2-Spieler-Modus. Der Online-Client nutzt die P1-Steuerung.*
- **Bewegen**: `Pfeiltaste Links` / `Rechts`
- **Springen**: `Pfeiltaste Hoch`
- **Zielen**: Pfeiltasten
- **Schießen**: `.` (Punkt)
- **Dash**: `/` (Schrägstrich)
- **Held-Fähigkeit**: `,` (Komma)

### Globale Tasten
- `R`: Match zurücksetzen und zurück in die Lobby (im Online-Modus deaktiviert)
