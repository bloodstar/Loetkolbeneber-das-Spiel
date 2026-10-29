# Burj Khalifa — Wind Engineering

A 20-slide, 16:9 technical deck on the wind design of the Burj Khalifa: statistics,
boundary-layer testing, aeroelastic response, the buttressed core and the load path.

**Deck:** `Burj_Khalifa_Wind_Engineering.pptx`

## Build

Requires `python-pptx` (the repository also has the PowerPoint MCP server venv):

```powershell
& "$env:USERPROFILE\.local\share\opencode\mcp-servers\Office-PowerPoint-MCP-Server\.venv\Scripts\python.exe" build_deck.py
```

Rendering for QA uses LibreOffice → PDF → PNG. Fonts are Segoe UI; the deck is laid out
against that family, so re-render if you substitute fonts.

## Files

| File | Purpose |
| --- | --- |
| `build_deck.py` | All 20 slides; `build()` is the entry point |
| `deck_lib.py` | Palette, panels, charts, axes, text and plan/silhouette helpers |
| `Burj_Khalifa_Wind_Engineering.pptx` | Output deck |

## Data provenance

Numbers in the deck are typed on slide 20:

- **Reported** — published project facts (828 m, 163 floors, 192 piles, 40+ tests,
  23.5 m/s at 10 m, 41 m/s at 600 m).
- **Predicted** — aeroelastic predictions (12 milli-g, 37 → 19 → 12, ≈1.5 m sway).
- **Derived** — fits and arithmetic (α ≈ 0.136, ≈43 m/s at the crown, Reynolds numbers).
- **Schematic** — teaching diagrams (lock-in curves, moment diagram, foundation section).

Comfort bands follow typical supertall practice and ISO 10137 guidance; they are not
code minima. Acceleration and sway values are predictions, not long-term measurements.

## Slide list

1. Title
2. Executive summary
3. Wind profile statistics
4. Vortex shedding
5. The Y-plan and 27 setbacks
6. Wind-tunnel test programme
7. Reynolds similitude
8. Aeroelastic response
9. 37 → 19 → 12 milli-g
10. Occupant comfort
11. Buttressed core
12. Load path and outriggers
13. Foundations
14. Construction
15. Simulation stack
16. Monitoring
17. Scorecard
18. Lessons
19. Instability modes
20. Sources and method
