#!/usr/bin/env python3
"""Draw the README artwork from Flamenco Shell's own palettes.

    tools/readme-assets.py                    banners + diagram into docs/assets
    tools/readme-assets.py wallpapers DIR     one abstract wallpaper per palette (SVG), for screenshots

Plain SVG, so GitHub renders it inline. Colors come from the shell's
Commons/Palettes.qml (linked into greeter/ by `make dev`), the same source the
shell's README art uses, so both READMEs stay in step. Re-run after palette changes.
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
PALETTES = ROOT / "greeter/Commons/Palettes.qml"
FONT = "Inter, 'Google Sans', Roboto, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"


def load_palettes():
    if not PALETTES.exists():
        sys.exit(f"readme-assets: {PALETTES} not found; run `make dev` first")
    src = PALETTES.read_text()
    names = re.findall(r'"([a-z]+)"', re.search(r"names:\s*\[(.*?)\]", src).group(1))
    labels = dict(re.findall(r'(\w+):\s*"([^"]+)"', re.search(r"labels:\s*\(\{(.*?)\}\)", src, re.S).group(1)))
    schemes = {}
    for name in names:
        block = src[src.index(f"{name}: {{", src.index("schemes:")):]
        schemes[name] = {mode: dict(re.findall(r'(\w+):\s*"(#[0-9a-fA-F]{6})"',
                                                re.search(mode + r":\s*\{(.*?)\}", block, re.S).group(1)))
                         for mode in ("dark", "light")}
    return names, labels, schemes


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'role="img" aria-label="{escape(title)}">\n<title>{escape(title)}</title>\n{body}\n</svg>\n')


def flame(x, y, s, fg, glow):
    """The Flamenco badge (same as the shell's): gradient squircle + flame, top-left at (x, y), size s."""
    k = s / 128
    return f'''<g transform="translate({x} {y}) scale({k})">
  <rect x="8" y="8" width="112" height="112" rx="30" fill="url(#badge)"/>
  <path fill="{fg}" d="M64 20c6 18 26 30 26 56 0 19-12 32-26 32S38 95 38 77c0-13 7-22 13-28 0 11 4 18 11 20-5-15-3-33 2-49z"/>
  <path fill="{glow}" opacity=".85" d="M64 66c3 9 12 13 12 24 0 8-5 13-12 13s-12-5-12-12c0-6 3-10 6-13 0 5 2 8 5 9-2-7-1-14 1-21z"/>
</g>'''


def fingerprint(cx, cy, r, color, width=2.2):
    """Concentric arcs suggesting a fingerprint, centred on (cx, cy)."""
    arcs = []
    for i, k in enumerate((1.0, 0.74, 0.48, 0.22)):
        rr = r * k
        start, end = (200, 340) if i % 2 == 0 else (190, 360)
        arcs.append(_arc(cx, cy + r * 0.15, rr, start, end))
    arcs.append(_arc(cx, cy + r * 0.15, r * 0.74, 20, 120))
    arcs.append(_arc(cx, cy + r * 0.15, r * 0.48, 0, 150))
    return "".join(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>' for d in arcs)


def _arc(cx, cy, r, a0, a1):
    import math
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M{x0:.1f} {y0:.1f} A{r:.1f} {r:.1f} 0 {large} 1 {x1:.1f} {y1:.1f}"


def chip(x, y, text, p, filled=False):
    w = 22 + len(text) * 8.2
    bg = p["accent"] if filled else p["surfaceHighest"]
    fg = p["onAccent"] if filled else p["text"]
    return (f'<rect x="{x}" y="{y}" width="{w:.0f}" height="34" rx="17" fill="{bg}"/>'
            f'<text x="{x + w / 2:.0f}" y="{y + 22}" text-anchor="middle" font-family="{FONT}" font-size="14" '
            f'font-weight="600" fill="{fg}">{escape(text)}</text>'), w


def defs(p, mode, extra=""):
    return f'''<defs>
  <linearGradient id="badge" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p["accent"]}"/><stop offset="1" stop-color="{p["accent2"]}"/>
  </linearGradient>
  <radialGradient id="blobA" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{p["accent"]}" stop-opacity="{.38 if mode == "dark" else .22}"/>
    <stop offset="1" stop-color="{p["accent"]}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="blobB" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{p["accent2"]}" stop-opacity="{.30 if mode == "dark" else .22}"/>
    <stop offset="1" stop-color="{p["accent2"]}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="blobC" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{p["accent3"]}" stop-opacity="{.28 if mode == "dark" else .18}"/>
    <stop offset="1" stop-color="{p["accent3"]}" stop-opacity="0"/>
  </radialGradient>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity="{.35 if mode == "dark" else .12}"/></filter>
  {extra}
</defs>'''


def banner(p, mode):
    """Hero: badge, title, tagline and chips on the left; a stylized login screen on the right."""
    W, H = 1280, 440
    sx, sy, sw, sh = 700, 56, 520, 328   # the little screen
    cx = sx + sw / 2
    parts = [defs(p, mode, f'''<linearGradient id="wall" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p["accent"]}" stop-opacity=".55"/>
    <stop offset=".55" stop-color="{p["accent3"]}" stop-opacity=".35"/>
    <stop offset="1" stop-color="{p["accent2"]}" stop-opacity=".5"/>
  </linearGradient>
  <clipPath id="card"><rect width="{W}" height="{H}" rx="32"/></clipPath>
  <clipPath id="screen"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="22"/></clipPath>
  <clipPath id="face"><circle cx="{cx}" cy="226" r="26"/></clipPath>'''),
        f'''<g clip-path="url(#card)">
  <rect width="{W}" height="{H}" fill="{p["bg"]}"/>
  <circle cx="1040" cy="40" r="360" fill="url(#blobA)"/>
  <circle cx="160" cy="430" r="320" fill="url(#blobB)"/>
  <circle cx="620" cy="-40" r="240" fill="url(#blobC)"/>
</g>
<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="32" fill="none" stroke="{p["border"]}"/>''']
    parts.append(flame(64, 70, 92, p["onAccent"], p["accent2"]))
    parts.append(f'<text x="64" y="232" font-family="{FONT}" font-size="64" font-weight="800" fill="{p["text"]}" letter-spacing="-1.5">Flamenco Greeter</text>')
    parts.append(f'<text x="66" y="272" font-family="{FONT}" font-size="22" fill="{p["textDim"]}">The Flamenco lock screen, at login.</text>')
    parts.append(f'<text x="66" y="302" font-family="{FONT}" font-size="22" fill="{p["textDim"]}">A greetd greeter built with Quickshell.</text>')
    x = 64
    for i, t in enumerate(["greetd", "niri · Hyprland · sway", "Material 3", "Fingerprint"]):
        c, w = chip(x, 338, t, p, filled=i == 0)
        parts.append(c)
        x += w + 10

    # stylized login screen: blurred wallpaper, clock, avatar, password pill, session + power row
    parts.append(f'''<g filter="url(#soft)"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="22" fill="{p["surface"]}"/></g>
<g clip-path="url(#screen)">
  <rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" fill="url(#wall)"/>
  <circle cx="1150" cy="330" r="120" fill="{p["accent"]}" opacity=".25"/>
  <circle cx="780" cy="120" r="90" fill="{p["accent2"]}" opacity=".18"/>
  <rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" fill="{p["bg"]}" opacity=".28"/>
</g>
<text x="{cx}" y="142" text-anchor="middle" font-family="{FONT}" font-size="54" font-weight="900" fill="{p["text"]}">9:41</text>
<text x="{cx}" y="168" text-anchor="middle" font-family="{FONT}" font-size="13" fill="{p["text"]}" opacity=".85">Tuesday, 13 October</text>
<circle cx="{cx}" cy="226" r="28" fill="{p["text"]}" opacity=".6"/>
<circle cx="{cx}" cy="226" r="26" fill="{p["accent"]}"/>
<text x="{cx}" y="236" text-anchor="middle" font-family="{FONT}" font-size="26" font-weight="800" fill="{p["onAccent"]}">F</text>
<text x="{cx}" y="279" text-anchor="middle" font-family="{FONT}" font-size="14" font-weight="700" fill="{p["text"]}">flamenco</text>
<rect x="{cx - 110}" y="292" width="220" height="36" rx="18" fill="{p["surface"]}" opacity=".85" stroke="{p["accent"]}" stroke-width="2"/>
<text x="{cx - 12}" y="315" text-anchor="middle" font-family="{FONT}" font-size="11.5" fill="{p["textDim"]}">Scan your finger on the reader</text>
{fingerprint(cx + 88, 308, 9, p["accent"], 1.6)}
<rect x="{cx - 96}" y="342" width="74" height="28" rx="14" fill="{p["surface"]}" opacity=".85"/>
<rect x="{cx - 86}" y="352" width="12" height="9" rx="2" fill="none" stroke="{p["accent"]}" stroke-width="1.6"/>
<rect x="{cx - 68}" y="353" width="36" height="7" rx="3.5" fill="{p["text"]}" opacity=".7"/>
<circle cx="{cx + 2}" cy="356" r="14" fill="{p["surfaceHigh"]}"/>
<circle cx="{cx + 34}" cy="356" r="14" fill="{p["surfaceHigh"]}"/>
<circle cx="{cx + 66}" cy="356" r="14" fill="{p["surfaceHigh"]}"/>
<circle cx="{cx + 66}" cy="356" r="6" fill="none" stroke="{p["error"]}" stroke-width="1.8"/>''')
    return svg(W, H, "\n".join(parts), "Flamenco Greeter: the Flamenco lock screen, at login")


def flow(p, mode):
    """How a login works: four Material cards joined by arrows."""
    steps = [
        ("greetd", "starts flamenco-greeter", "as the greeter user"),
        ("Launcher", "loads your synced theme,", "keyboard and cursor"),
        ("niri", "a minimal session that", "runs the Quickshell UI"),
        ("Your desktop", "greetd launches the", "session you picked"),
    ]
    cw, ch, gap = 270, 132, 46
    W, H = len(steps) * cw + (len(steps) - 1) * gap, ch
    parts = [defs(p, mode)]
    for i, (title, l1, l2) in enumerate(steps):
        x = i * (cw + gap)
        accent = p["accent"] if i in (0, len(steps) - 1) else p["accent2"] if i == 1 else p["accent3"]
        parts.append(f'''<g transform="translate({x} 0)">
  <rect x=".5" y=".5" width="{cw - 1}" height="{ch - 1}" rx="24" fill="{p["surface"]}" stroke="{p["border"]}"/>
  <circle cx="40" cy="40" r="18" fill="{accent}"/>
  <text x="40" y="46" text-anchor="middle" font-family="{FONT}" font-size="16" font-weight="800" fill="{p["onAccent"] if accent == p["accent"] else p["bg"]}">{i + 1}</text>
  <text x="70" y="47" font-family="{FONT}" font-size="20" font-weight="700" fill="{p["text"]}">{escape(title)}</text>
  <text x="24" y="88" font-family="{FONT}" font-size="15" fill="{p["textDim"]}">{escape(l1)}</text>
  <text x="24" y="110" font-family="{FONT}" font-size="15" fill="{p["textDim"]}">{escape(l2)}</text>
</g>''')
        if i < len(steps) - 1:
            ax = x + cw + 8
            parts.append(f'<path d="M{ax} {ch / 2} h{gap - 22} m-8 -7 l8 7 l-8 7" fill="none" stroke="{p["textDim"]}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    return svg(W, H, "\n".join(parts), "How a login works: greetd, the launcher, niri, your desktop")


def wallpaper(p, mode, label):
    """A soft abstract wallpaper in a palette's colors (the greeter blurs it further)."""
    W, H = 1920, 1200
    o = 1 if mode == "dark" else 0.75
    return svg(W, H, f'''<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p["surfaceHigh"]}"/><stop offset="1" stop-color="{p["bg"]}"/>
  </linearGradient>
  <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>
</defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<g filter="url(#blur)">
  <circle cx="1460" cy="260" r="420" fill="{p["accent"]}" opacity="{.75 * o}"/>
  <circle cx="380" cy="980" r="460" fill="{p["accent2"]}" opacity="{.6 * o}"/>
  <circle cx="900" cy="520" r="300" fill="{p["accent3"]}" opacity="{.55 * o}"/>
  <ellipse cx="1700" cy="1100" rx="520" ry="240" fill="{p["accent3"]}" opacity="{.45 * o}"/>
  <ellipse cx="200" cy="120" rx="420" ry="220" fill="{p["accent"]}" opacity="{.35 * o}"/>
</g>
<path d="M0 860 C 420 700, 760 1040, 1180 860 S 1720 640, 1920 760 L1920 1200 L0 1200 Z" fill="{p["bg"]}" opacity=".35"/>
<path d="M0 960 C 480 820, 820 1120, 1260 960 S 1760 780, 1920 880 L1920 1200 L0 1200 Z" fill="{p["bg"]}" opacity=".35"/>''',
               f"{label} wallpaper ({mode})")


def main():
    names, labels, schemes = load_palettes()
    if len(sys.argv) > 1 and sys.argv[1] == "wallpapers":
        out = Path(sys.argv[2] if len(sys.argv) > 2 else ROOT / "docs/wallpapers")
        out.mkdir(parents=True, exist_ok=True)
        for n in names:
            for mode in ("dark", "light"):
                (out / f"{n}-{mode}.svg").write_text(wallpaper(schemes[n][mode], mode, labels.get(n, n)))
        print(f"wrote {len(names) * 2} wallpapers to {out}")
        return
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs/assets"
    out.mkdir(parents=True, exist_ok=True)
    for mode in ("dark", "light"):
        p = schemes["flamenco"][mode]
        (out / f"banner-{mode}.svg").write_text(banner(p, mode))
        (out / f"flow-{mode}.svg").write_text(flow(p, mode))
    print(f"wrote banners and diagrams to {out}")


if __name__ == "__main__":
    main()
