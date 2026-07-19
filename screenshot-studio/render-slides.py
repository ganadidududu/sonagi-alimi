#!/usr/bin/env python3
# Composes each App Store slide as a full HTML page (background + blobs +
# weather-icon decorations + phone frame + screenshot + headline), replicating
# the editor's slide-canvas rendering. Chrome headless then screenshots each at
# 1320x2868 — reliable, unlike html-to-image which couldn't render the clipped
# screen <img>.
import json, os

STUDIO = "/Users/son-inseong/Desktop/project/weather/screenshot-studio"
PUB = f"{STUDIO}/public"
OUT = "/private/tmp/claude-501/-Users-son-inseong-Desktop-project-weather/613f5487-1eb3-4448-a936-cb7e0313e496/scratchpad/slides"
os.makedirs(OUT, exist_ok=True)

CW, CH = 1320, 2868
UNIT = min(CW, CH)  # 1320
BG, BGALT, FG, FGALT, ACCENT = "#D3E5F7", "#2F4A6D", "#2F4A6D", "#EAF3FC", "#4A90E2"

def shade(hexs, pct):
    c = hexs.lstrip("#"); n = int(c, 16)
    r, g, b = (n >> 16) & 255, (n >> 8) & 255, n & 255
    amt = round(255 * pct / 100)
    f = lambda x: max(0, min(255, x + amt))
    return f"#{(f(r) << 16 | f(g) << 8 | f(b)):06x}"

def background(inv):
    if inv: return f"linear-gradient(160deg, {BGALT} 0%, {shade(BGALT,-8)} 100%)"
    return f"linear-gradient(160deg, {BG} 0%, {shade(BG,-6)} 100%)"

# ---- weather glyphs (viewBox 0 0 64 64), ported from WeatherGlyph ----
SUN, CLOUD, DROP = "#FFCF5A", "#FFFFFF", "#7FB4EC"
SUNF, CLOUDF = "rgba(120,80,10,.8)", "rgba(70,95,130,.78)"

def sun_face(cx, cy, r):
    rays = "".join(
        f'<line x1="{cx}" y1="{cy-r-r*0.5}" x2="{cx}" y2="{cy-r}" stroke="{SUN}" stroke-width="{r*0.3}" stroke-linecap="round" transform="rotate({i*45} {cx} {cy})"/>'
        for i in range(8))
    return (f'<g>{rays}<circle cx="{cx}" cy="{cy}" r="{r}" fill="{SUN}"/>'
            f'<circle cx="{cx-r*0.28}" cy="{cy}" r="1.9" fill="{SUNF}"/>'
            f'<circle cx="{cx+r*0.28}" cy="{cy}" r="1.9" fill="{SUNF}"/>'
            f'<path d="M{cx-r*0.25} {cy+r*0.28} q{r*0.25} {r*0.24} {r*0.5} 0" stroke="{SUNF}" stroke-width="1.8" fill="none" stroke-linecap="round"/></g>')

def cloud_face():
    return (f'<g><circle cx="23" cy="34" r="12" fill="{CLOUD}"/><circle cx="43" cy="32" r="13" fill="{CLOUD}"/>'
            f'<circle cx="33" cy="25" r="12.5" fill="{CLOUD}"/><rect x="12" y="32" width="40" height="15" rx="7.5" fill="{CLOUD}"/>'
            f'<circle cx="27" cy="34" r="1.9" fill="{CLOUDF}"/><circle cx="39" cy="34" r="1.9" fill="{CLOUDF}"/>'
            f'<path d="M29 39 q4 3.6 8 0" stroke="{CLOUDF}" stroke-width="1.8" fill="none" stroke-linecap="round"/></g>')

def drops(pts):
    return "<g>" + "".join(f'<circle cx="{x}" cy="{y}" r="3" fill="{DROP}"/>' for x, y in pts) + "</g>"

UMBRELLA = (f'<g><path d="M32 12 C18 12 8 22 6 33 L58 33 C56 22 46 12 32 12 Z" fill="{DROP}"/>'
            '<path d="M6 33 Q13 27 20 33 Q26 27 32 33 Q38 27 44 33 Q51 27 58 33" fill="none" stroke="rgba(47,74,109,.35)" stroke-width="1.3"/>'
            '<rect x="30.6" y="33" width="2.8" height="18" rx="1.4" fill="#CDD8E6"/>'
            '<path d="M31 51 q0 5 6 4.5" fill="none" stroke="#CDD8E6" stroke-width="2.6" stroke-linecap="round"/>'
            '<circle cx="32" cy="11" r="2" fill="#CDD8E6"/></g>')

def glyph(kind):
    if kind == "sun": inner = sun_face(32, 32, 14)
    elif kind == "cloud": inner = cloud_face()
    elif kind == "drops": inner = drops([(20,26),(32,32),(44,26),(32,40)])
    elif kind == "umbrella": inner = UMBRELLA
    elif kind == "shower":
        inner = (f'<g transform="translate(8 6) scale(0.55)">{sun_face(14,14,12)}</g>'
                 + cloud_face() + drops([(24,52),(33,55),(42,52)]))
    else: inner = ""
    return (f'<svg viewBox="0 0 64 64" width="100%" height="100%" '
            f'style="display:block;overflow:visible;filter:drop-shadow(0 3px 8px rgba(40,60,95,.18))">{inner}</svg>')

DECOSETS = [
    [("sun",4,5,17,-8),("cloud",78,12,20,6),("umbrella",82,74,15,14)],
    [("cloud",3,8,20,-6),("drops",84,16,12,0),("shower",79,76,17,8)],
    [("umbrella",5,9,16,-12),("sun",80,10,16,10),("cloud",6,78,18,-5)],
    [("sun",82,8,17,9),("cloud",3,14,18,-7),("drops",84,76,12,6)],
    [("shower",4,7,18,-9),("umbrella",82,13,15,12),("cloud",80,76,18,5)],
]

# ---- phone screen rect inside mockup.png (1022x2082) ----
L, T, W, H = 52/1022*100, 46/2082*100, 918/1022*100, 1990/2082*100
RX, RY = 126/918*100, 126/1990*100
MOCKUP = f"file://{PUB}/mockup.png"

def deco_html(slide_id):
    seed = sum(ord(c) for c in slide_id) % len(DECOSETS)
    out = []
    for kind, x, y, size, rot in DECOSETS[seed]:
        out.append(f'<div style="position:absolute;left:{x}%;top:{y}%;width:{size}%;aspect-ratio:1/1;'
                   f'transform:rotate({rot}deg)">{glyph(kind)}</div>')
    return "".join(out)

def slide_html(slide):
    inv = bool(slide.get("inverted"))
    dev = slide["transforms"]["device"]
    cap = slide["transforms"].get("caption", {"x":106,"y":360,"width":1109,"height":700})
    fg = FGALT if inv else FG
    scr = slide["screenshot"].replace("{locale}", "en")
    scr_url = f"file://{PUB}{scr}"
    label = slide["label"]["en"]
    headline = slide["headline"]["en"].replace("\n", "<br>")
    b1 = 0.25 if inv else 0.28
    b2 = 0.18 if inv else 0.22
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box}} html,body{{width:{CW}px;height:{CH}px;overflow:hidden}}
body{{font-family:Inter,-apple-system,"Apple SD Gothic Neo",sans-serif;position:relative;
background:{background(inv)};-webkit-font-smoothing:antialiased}}
.blob{{position:absolute;border-radius:50%;filter:blur({CW*0.06}px);background:{ACCENT};pointer-events:none}}
</style></head><body>
<div class="blob" style="left:-15%;top:-10%;width:55%;aspect-ratio:1/1;opacity:{b1}"></div>
<div class="blob" style="left:70%;top:75%;width:45%;aspect-ratio:1/1;opacity:{b2}"></div>
{deco_html(slide['id'])}
<div style="position:absolute;left:{cap['x']}px;top:{cap['y']}px;width:{cap['width']}px;text-align:center">
  <div style="font-size:{UNIT*0.028}px;font-weight:600;letter-spacing:{UNIT*0.0015}px;color:{ACCENT};text-transform:uppercase;margin-bottom:{UNIT*0.018}px">{label}</div>
  <div style="font-size:{UNIT*0.092}px;font-weight:700;line-height:0.96;letter-spacing:{-UNIT*0.001}px;color:{fg}">{headline}</div>
</div>
<div style="position:absolute;left:{dev['x']}px;top:{dev['y']}px;width:{dev['width']}px;height:{dev['height']}px">
  <img src="{MOCKUP}" style="display:block;width:100%;height:100%"/>
  <div style="position:absolute;z-index:10;overflow:hidden;left:{L}%;top:{T}%;width:{W}%;height:{H}%;border-radius:{RX}% / {RY}%;background:#111">
    <img src="{scr_url}" style="display:block;width:100%;height:100%;object-fit:cover;object-position:top"/>
  </div>
</div>
</body></html>"""

data = json.load(open(f"{STUDIO}/app-store-screenshots.json"))
slides = data["slidesByDevice"]["iphone"]
for i, s in enumerate(slides, 1):
    html = slide_html(s)
    open(f"{OUT}/slide{i:02d}.html", "w").write(html)
    print(f"slide{i:02d}.html  <- {s['headline']['en'].replace(chr(10),' ')}")
print("생성 완료:", len(slides))
