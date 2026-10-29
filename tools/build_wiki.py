#!/usr/bin/env python3
"""Baut aus README.md die Browser-Fassung docs/wiki.html.

Der Knopf WIKI im Hauptmenü öffnet diese Datei. Nach jeder Änderung an der
README einmal ausführen:  python tools/build_wiki.py   (braucht pandoc)
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "README.md"
OUT = ROOT / "docs" / "wiki.html"

CSS = """
:root {
  --bg: #0b1418; --panel: #10201f; --line: #1d3b3a; --text: #d9f2ee;
  --muted: #8fb5b0; --cyan: #3ef2e0; --pink: #ff4fa3; --gold: #ffc857;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0; padding: 0; max-width: none; hyphens: manual; background: var(--bg); color: var(--text);
  font: 16px/1.6 "Segoe UI", system-ui, sans-serif;
  background-image:
    linear-gradient(var(--line) 1px, transparent 1px),
    linear-gradient(90deg, var(--line) 1px, transparent 1px);
  background-size: 48px 48px; background-attachment: fixed;
}
#TOC {
  position: fixed; top: 0; left: 0; bottom: 0; width: 260px; overflow-y: auto;
  padding: 24px 16px; background: rgba(8, 16, 18, 0.96);
  border-right: 2px solid var(--cyan); box-shadow: 0 0 18px rgba(62, 242, 224, 0.25);
}
#TOC::before {
  content: "LÖTKOLBENEBER WIKI"; display: block; margin-bottom: 14px;
  color: var(--pink); font-weight: 800; letter-spacing: 2px; font-size: 14px;
}
#TOC > ul > li > a { display: none; }
#TOC > ul > li > ul { padding-left: 0; font-size: 15px; }
#TOC ul { list-style: none; margin: 0; padding-left: 0; }
#TOC ul ul { padding-left: 14px; font-size: 14px; }
#TOC a { display: block; padding: 3px 6px; color: var(--muted); text-decoration: none; border-radius: 4px; }
#TOC a:hover { color: var(--bg); background: var(--cyan); }
main { margin-left: 260px; padding: 32px 48px 80px; max-width: 1180px; }
h1 { color: var(--cyan); font-size: 40px; margin-top: 0; text-shadow: 0 0 14px rgba(62, 242, 224, 0.6); }
h2 {
  color: var(--cyan); margin-top: 48px; padding-bottom: 6px;
  border-bottom: 2px solid var(--pink); text-shadow: 0 0 8px rgba(62, 242, 224, 0.4);
}
h3 { color: var(--gold); margin-top: 28px; }
a { color: var(--cyan); }
strong { color: #ffffff; }
code { background: #08100f; border: 1px solid var(--line); border-radius: 4px; padding: 1px 5px; color: var(--gold); }
hr { border: 0; height: 1px; background: var(--line); margin: 32px 0; }
blockquote { margin: 16px 0; padding: 10px 16px; background: var(--panel); border-left: 4px solid var(--pink); color: var(--muted); }
table { width: 100%; border-collapse: collapse; margin: 14px 0; font-size: 15px; display: block; overflow-x: auto; }
th, td { background: var(--panel); padding: 7px 10px; border: 1px solid var(--line); vertical-align: top; }
th { background: #14302e; color: var(--cyan); text-align: left; }
tr:nth-child(even) td { background: #132625; }
@media (max-width: 900px) {
  #TOC { position: static; width: auto; border-right: 0; border-bottom: 2px solid var(--cyan); }
  main { margin-left: 0; padding: 20px 16px 60px; }
}
"""


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    # Das Inhaltsverzeichnis der README ersetzt im Browser die Seitenleiste.
    text = re.sub(r"## 📑 Inhalt\n.*?\n---\n", "", text, count=1, flags=re.S)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    header = Path(tempfile.gettempdir()) / "loetkolbeneber_wiki_style.html"
    header.write_text("<style>" + CSS + "</style>", encoding="utf-8")
    try:
        html = subprocess.run(
            ["pandoc", "-f", "gfm", "-t", "html5", "--standalone", "--toc",
             "--toc-depth=2", "--metadata", "title=Lötkolbeneber – Spiel-Wiki",
             "--metadata", "lang=de", "-H", str(header),
             "--variable", "pagetitle=Lötkolbeneber – Spiel-Wiki"],
            input=text, capture_output=True, text=True, encoding="utf-8", check=True,
        ).stdout
    finally:
        header.unlink(missing_ok=True)
    # Pandoc setzt den Titel als eigenen Kopf, die README hat schon einen.
    html = re.sub(r'<header id="title-block-header">.*?</header>', "", html, flags=re.S)
    # Inhalt neben der Seitenleiste in <main> fassen.
    html = html.replace("</nav>", "</nav>\n<main>", 1).replace("</body>", "</main>\n</body>", 1)
    # Externe Links in neuem Tab öffnen.
    html = html.replace('<a href="http', '<a target="_blank" href="http')
    OUT.write_text(html, encoding="utf-8")
    print(f"{OUT} geschrieben ({len(html) // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
