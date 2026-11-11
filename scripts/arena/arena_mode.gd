class_name ArenaMode
extends RefCounted

# Arena-Modus (Draufsicht). Die Spiellogik bleibt 2D: Die 2D-Ebene ist der
# Boden (x = Ost/West, y = Nord/Süd). Dazu kommt eine Höhe z in Pixeln, die
# Sprünge, niedrige Deckung, Mauern und später Rampen/Stege trägt.
#
# Höhen-Schichten: Die Höhe ist in Bänder zu je BAND_H Pixel geteilt. Jedes
# Band hat eine eigene Physik-Ebene. Ein Block (Mauer, Deckung, Steg) liegt
# in den Ebenen der Bänder, die er belegt. Spieler und Kugeln maskieren nur
# die Bänder, in denen sie sich gerade befinden. So springt man über
# niedrige Deckung und läuft (später) unter Stegen durch.
#   Band 0 = Physik-Ebene 1 (die bestehende Welt-Ebene, wie in der Seitenansicht)
#   Band 1..3 = Physik-Ebenen 10..12

const BAND_H: float = 36.0
const BAND_COUNT: int = 4
# Körperhöhe eines Schweins (für die belegten Bänder).
const BODY_H: float = 46.0
# Füße knapp über dem Boden: Auf einer Deckung (Oberkante 36) belegt der
# Körper Band 0 nicht mehr.
const FOOT_CLEAR: float = 4.0
# Abschusshöhe über den Füßen.
const MUZZLE_H: float = 24.0
# Sprung-Schwerkraft relativ zu Player.GRAVITY. Mit der Grund-Sprungkraft
# (470) ergibt das gut 1,4 Tiles Sprunghöhe und knapp 0,45 s Flugzeit.
const Z_GRAVITY_MULT: float = 2.2
# Kleine Stufen (Rampen) läuft man ohne Sprung hoch.
const STEP_UP: float = 10.0
# Von der Seite auf eine Rampe: bis zu dieser Höhe tritt man direkt hinauf.
# Höhere Rampenteile haben seitlich eine Wand (siehe ArenaBuilder).
const RAMP_SIDE_STEP: float = 46.0
# Kamera-Neigung über dem Boden. 90° wäre senkrecht von oben.
const TILT_DEG: float = 55.0

## true, solange eine Arena-Runde läuft (wird beim Levelaufbau gesetzt).
static var active: bool = false
## Höhenraster der aktuellen Arena.
static var grid: ArenaGrid = null

static func y_squash() -> float:
	return sin(deg_to_rad(TILT_DEG))

## Bildschirm-Versatz (2D-Weltkoordinaten) für etwas in Höhe z, damit es in
## der gestauchten 2D-Ebene über der richtigen Bodenstelle erscheint.
static func height_offset(z: float) -> Vector2:
	return Vector2(0.0, -z / tan(deg_to_rad(TILT_DEG)))

static func band_bit(band: int) -> int:
	if band <= 0:
		return 1
	return 1 << (8 + band) # Band 1 -> Ebene 10 (Wert 512)

static func all_bands_mask() -> int:
	var m := 0
	for b in range(BAND_COUNT):
		m |= band_bit(b)
	return m

## Maske aller Bänder, die der Bereich [z0, z1] berührt.
static func band_mask_range(z0: float, z1: float) -> int:
	var lo := clampi(int(floor(z0 / BAND_H)), 0, BAND_COUNT - 1)
	var hi := clampi(int(floor(maxf(z0, z1 - 0.01) / BAND_H)), 0, BAND_COUNT - 1)
	var m := 0
	for b in range(lo, hi + 1):
		m |= band_bit(b)
	return m

static func body_band_mask(z: float) -> int:
	return band_mask_range(z + FOOT_CLEAR, z + BODY_H)

static func point_band_mask(z: float) -> int:
	return band_mask_range(z, z)

## Ersetzt in einer bestehenden Maske alle Band-Bits durch bands.
static func with_bands(mask: int, bands: int) -> int:
	return (mask & ~all_bands_mask()) | bands
