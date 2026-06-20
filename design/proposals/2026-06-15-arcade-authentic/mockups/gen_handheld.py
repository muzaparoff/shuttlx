#!/usr/bin/env python3
"""Arcade authentic-hardware mockup — HANDHELD direction (GBC-era skin, Delta-style).
Generic translucent-purple portrait handheld: live workout data as the "game screen"
up top, molded control deck (D-pad + round A/B buttons + start/select pills + speaker)
below. NO trademark wordmarks/silhouettes — generic shapes + color only.

Render:
  python3 gen_handheld.py
  rm -f arcade-handheld.svg.png
  qlmanage -t -s 1720 -o . arcade-handheld.svg
  sips -c 1720 800 arcade-handheld.svg.png --out arcade-handheld.png
"""
import math

W, H = 400, 860
SQ = 860
OFFX = (SQ - W) // 2

# ---- palette ----
PHONE      = "#0a0a0d"     # phone bezel (it's an iPhone running the app)
PHONE_RIM  = "#26262e"
# translucent grape/atomic-purple handheld body (Delta-style)
BODY1      = "#8675cf"
BODY2      = "#574a9c"
BODY3      = "#3d3275"
BODY_EDGE  = "#2b2356"
BODY_HI    = "#b3a6e8"
# screen
BEZEL1     = "#2a2a32"
BEZEL2     = "#16161c"
GLASS_BG   = "#06121b"     # LCD navy
PHOS       = "#2bff67"
PHOS_DIM   = "#0d5a26"
YELLOW     = "#ffd400"
CYAN       = "#28e6ff"
MAGENTA    = "#ff5cf0"
NEON_PINK  = "#ff2bd6"
NEON_CYAN  = "#21e6ff"
DIMTXT     = "#3a7a8f"
WHITE      = "#f4f4ff"
# controls
DPAD1      = "#26262e"
DPAD2      = "#101015"
DPAD_HI    = "#43434f"
BTN_MAG1   = "#ff4d8d"
BTN_MAG2   = "#c11d5e"
PILL1      = "#3a3358"
PILL2      = "#241f3c"
SPK_LINE   = "#2b2356"
LED_RED    = "#ff3b53"

SEG = {"0":"abcdef","1":"bc","2":"abged","3":"abgcd","4":"fgbc",
       "5":"afgcd","6":"afgcde","7":"abc","8":"abcdefg","9":"abcfgd"}

def seven_seg(x, y, w, h, ch, on, off, t=None):
    if t is None: t = w * 0.18
    segs = SEG.get(ch, "")
    out = []
    def horiz(cy):
        l = x + t*0.7; r = x + w - t*0.7
        return (f'<polygon points="{l},{cy} {l+t*0.7},{cy-t/2} {r-t*0.7},{cy-t/2} '
                f'{r},{cy} {r-t*0.7},{cy+t/2} {l+t*0.7},{cy+t/2}" ')
    def vert(cx, top, bot):
        return (f'<polygon points="{cx},{top} {cx+t/2},{top+t*0.7} {cx+t/2},{bot-t*0.7} '
                f'{cx},{bot} {cx-t/2},{bot-t*0.7} {cx-t/2},{top+t*0.7}" ')
    midy = y + h/2
    geom = {"a": horiz(y + t*0.6), "g": horiz(midy), "d": horiz(y + h - t*0.6),
            "f": vert(x + t*0.6, y + t*0.9, midy - t*0.2),
            "b": vert(x + w - t*0.6, y + t*0.9, midy - t*0.2),
            "e": vert(x + t*0.6, midy + t*0.2, y + h - t*0.9),
            "c": vert(x + w - t*0.6, midy + t*0.2, y + h - t*0.9)}
    for s, g in geom.items():
        col = on if s in segs else off
        opa = "1" if s in segs else "0.13"
        out.append(g + f'fill="{col}" opacity="{opa}"/>')
    return "\n".join(out)

def seven_seg_str(x, y, cell_w, cell_h, s, on, off, gap=None):
    if gap is None: gap = cell_w * 0.32
    out = []; cx = x
    for ch in s:
        if ch == ":":
            r = cell_h*0.06
            out.append(f'<circle cx="{cx+gap/2}" cy="{y+cell_h*0.34}" r="{r}" fill="{on}"/>')
            out.append(f'<circle cx="{cx+gap/2}" cy="{y+cell_h*0.66}" r="{r}" fill="{on}"/>')
            cx += gap; continue
        out.append(seven_seg(cx, y, cell_w, cell_h, ch, on, off))
        cx += cell_w + gap
    return "\n".join(out), cx

def rrect(x,y,w,h,r,fill,stroke=None,sw=0,opacity=1,flt=None):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" fill="{fill}" opacity="{opacity}"'
    if stroke: s += f' stroke="{stroke}" stroke-width="{sw}"'
    if flt: s += f' filter="url(#{flt})"'
    return s + "/>"

def txt(x,y,s,size,fill,anchor="start",weight="700",family="Menlo, monospace",ls="0",opacity=1,flt=None,rot=None):
    f = f' filter="url(#{flt})"' if flt else ""
    tr = f' transform="rotate({rot} {x} {y})"' if rot is not None else ""
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
            f'letter-spacing="{ls}" opacity="{opacity}"{f}{tr}>{s}</text>')

el = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SQ}" height="{SQ}" viewBox="0 0 {SQ} {SQ}">']

# ---------- defs ----------
el.append('<defs>')
el.append(f'<linearGradient id="body" x1="0.15" y1="0" x2="0.7" y2="1">'
          f'<stop offset="0" stop-color="{BODY1}"/><stop offset="0.5" stop-color="{BODY2}"/>'
          f'<stop offset="1" stop-color="{BODY3}"/></linearGradient>')
el.append(f'<linearGradient id="bezel" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{BEZEL1}"/><stop offset="1" stop-color="{BEZEL2}"/></linearGradient>')
el.append(f'<radialGradient id="glass" cx="0.32" cy="0.2" r="1.1">'
          f'<stop offset="0" stop-color="#0c2230"/><stop offset="1" stop-color="{GLASS_BG}"/></radialGradient>')
el.append(f'<radialGradient id="vign" cx="0.5" cy="0.5" r="0.75">'
          f'<stop offset="0.55" stop-color="#000" stop-opacity="0"/>'
          f'<stop offset="1" stop-color="#000" stop-opacity="0.55"/></radialGradient>')
el.append(f'<linearGradient id="dpad" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{DPAD_HI}"/><stop offset="0.18" stop-color="{DPAD1}"/>'
          f'<stop offset="1" stop-color="{DPAD2}"/></linearGradient>')
el.append(f'<radialGradient id="btn" cx="0.36" cy="0.3" r="0.85">'
          f'<stop offset="0" stop-color="{BTN_MAG1}"/><stop offset="0.7" stop-color="{BTN_MAG2}"/>'
          f'<stop offset="1" stop-color="#7a0f3a"/></radialGradient>')
el.append(f'<linearGradient id="pill" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{PILL1}"/><stop offset="1" stop-color="{PILL2}"/></linearGradient>')
el.append(f'<linearGradient id="bodysheen" x1="0" y1="0" x2="1" y2="0">'
          f'<stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/>'
          f'<stop offset="0.25" stop-color="#ffffff" stop-opacity="0"/></linearGradient>')
for fid, dev in [("glowS","1.6"),("glowM","3")]:
    el.append(f'<filter id="{fid}" x="-60%" y="-60%" width="220%" height="220%">'
              f'<feGaussianBlur stdDeviation="{dev}" result="b"/><feMerge>'
              f'<feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
el.append(f'<filter id="soft" x="-40%" y="-40%" width="180%" height="180%">'
          f'<feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#000" flood-opacity="0.55"/></filter>')
el.append('</defs>')

el.append(f'<rect x="0" y="0" width="{SQ}" height="{SQ}" fill="#f0f1f7"/>')
el.append(f'<g transform="translate({OFFX},0)">')

# ---------- PHONE BODY (it's an iPhone) ----------
el.append(rrect(0,0,W,H,60,PHONE))
el.append(rrect(2,2,W-4,H-4,58,"none",PHONE_RIM,1.4))
DB = 9
DX,DY,DW,DH = DB, DB, W-2*DB, H-2*DB
el.append(f'<clipPath id="disp"><rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" rx="50"/></clipPath>')
el.append(f'<g clip-path="url(#disp)">')

# ---- handheld body fills the display (the skin) ----
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#body)"/>')
# molded body shading: rounded lower-right mass + edge darkening
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#bodysheen)"/>')
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#vign)" opacity="0.5"/>')
# faint speckle texture (translucent plastic)
import random
random.seed(7)
spk = []
for _ in range(220):
    px = DX+random.random()*DW; py = DY+random.random()*DH
    spk.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="0.7" fill="#fff" opacity="0.05"/>')
el.append("".join(spk))

# Dynamic Island
el.append(rrect(W/2-46, DY+10, 92, 26, 13, "#000"))
el.append(f'<circle cx="{W/2+30}" cy="{DY+23}" r="4" fill="#0c1418"/>')

# ---------- SCREEN BEZEL + GLASS ----------
SBX, SBY, SBW, SBH = DX+22, DY+50, DW-44, 412
el.append(rrect(SBX, SBY, SBW, SBH, 18, "url(#bezel)", "#000", 1, flt="soft"))
# upper "ridge" line of bezel + power label row
el.append(txt(SBX+14, SBY+22, "&#9679; POWER", 9, LED_RED, "start", "700", ls="1"))
el.append(f'<circle cx="{SBX+17}" cy="{SBY+18.5}" r="3.2" fill="{LED_RED}" filter="url(#glowS)"/>')
el.append(txt(SBX+SBW-14, SBY+22, "DOT-MATRIX HR", 8, "#6b6b78", "end", "700", ls="1.5"))

GX, GY = SBX+16, SBY+34
GW, GH = SBW-32, SBH-50
el.append(rrect(GX, GY, GW, GH, 8, "url(#glass)"))
el.append(rrect(GX, GY, GW, GH, 8, "none", NEON_CYAN, 1, opacity=0.25))
el.append(f'<clipPath id="gclip"><rect x="{GX}" y="{GY}" width="{GW}" height="{GH}" rx="8"/></clipPath>')

# scanlines
sl = []; yy = GY+3
while yy < GY+GH:
    sl.append(f'<rect x="{GX}" y="{yy}" width="{GW}" height="1.2" fill="#000" opacity="0.18"/>'); yy += 4
el.append(f'<g clip-path="url(#gclip)">{"".join(sl)}</g>')

# --- CRT DATA ---
el.append(txt(GX+14, GY+26, "1UP", 11, NEON_CYAN, "start", "800", ls="1"))
el.append(f'<text x="{GX+14}" y="{GY+52}" font-family="Menlo, monospace" font-size="26" font-weight="800" fill="{YELLOW}" filter="url(#glowS)">142</text>')
el.append(txt(GX+74, GY+52, "&#9829; Z3", 13, YELLOW, "start", "700"))
el.append(txt(GX+GW-14, GY+26, "HI-SCORE", 11, NEON_PINK, "end", "800", ls="1"))
el.append(f'<text x="{GX+GW-14}" y="{GY+52}" font-family="Menlo, monospace" font-size="26" font-weight="800" fill="{PHOS}" text-anchor="end" filter="url(#glowS)">03280</text>')
el.append(txt(GX+GW-14, GY+66, "STEPS", 8, DIMTXT, "end", "700", ls="1"))

heroY = GY+88; cw, ch = 42, 74
seg_svg, _ = seven_seg_str(GX+30, heroY, cw, ch, "01:48", PHOS, PHOS_DIM, gap=13)
el.append(f'<g filter="url(#glowM)">{seg_svg}</g>')
el.append(txt(GX+GW/2, heroY+ch+20, "WORK REMAINING", 11, NEON_CYAN, "middle", "800", ls="3", opacity=0.85))

sbY = heroY+ch+44
el.append(txt(GX+14, sbY+11, "STAGE 3/8", 10, NEON_CYAN, "start", "800", ls="1"))
barX = GX+102; barW = GW-116; cells = 10; filled = 3
cellw = (barW-(cells-1)*4)/cells
for i in range(cells):
    cx = barX + i*(cellw+4)
    c = PHOS if i < filled else PHOS_DIM
    el.append(rrect(cx, sbY+1, cellw, 11, 2, c, opacity=("1" if i<filled else "0.4"),
                    flt=("glowS" if i<filled else None)))

mbY = sbY+28; mbH = 60; gapb = 7
bw = (GW-28-3*gapb)/4
metrics = [("HR","142",YELLOW),("DIST","2.15",PHOS),("PACE","5:42",NEON_CYAN),("SPM","168",NEON_PINK)]
for i,(lab,val,col) in enumerate(metrics):
    bx = GX+14 + i*(bw+gapb)
    el.append(rrect(bx, mbY, bw, mbH, 5, "#04030f", col, 1.3, flt="glowS"))
    el.append(rrect(bx+2, mbY+2, bw-4, mbH*0.4, 4, "#ffffff", opacity=0.05))
    el.append(txt(bx+bw/2, mbY+16, lab, 9, col, "middle", "800", ls="1"))
    el.append(txt(bx+bw/2, mbY+44, val, 20, WHITE, "middle", "800"))

el.append(f'<rect x="{GX}" y="{GY}" width="{GW}" height="{GH}" fill="url(#vign)" opacity="0.5" clip-path="url(#gclip)"/>')

# embossed generic wordmark under screen
el.append(txt(W/2, SBY+SBH+30, "SHUTTLX", 22, BODY_EDGE, "middle", "900", ls="2", opacity=0.9))
el.append(txt(W/2+1, SBY+SBH+29, "SHUTTLX", 22, BODY_HI, "middle", "900", ls="2", opacity=0.5))
el.append(txt(W/2, SBY+SBH+45, "INTERVAL  SYSTEM", 9, BODY_EDGE, "middle", "700", ls="4", opacity=0.7))

# ---------- CONTROL DECK ----------
CY = SBY+SBH+92   # control baseline region top

# --- D-PAD (left) ---
dcx, dcy = DX+92, CY+58
arm, thick = 76, 30
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="62" fill="#000" opacity="0.12"/>')
# cross (two rounded rects)
el.append(rrect(dcx-thick/2, dcy-arm/2-thick/2, thick, arm+thick, 8, "url(#dpad)", flt="soft"))
el.append(rrect(dcx-arm/2-thick/2, dcy-thick/2, arm+thick, thick, 8, "url(#dpad)"))
# center pivot dish
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="13" fill="{DPAD2}"/>')
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="13" fill="none" stroke="{DPAD_HI}" stroke-width="1" opacity="0.6"/>')
# directional arrows
for ang,gx,gy in [(0,dcx,dcy-arm/2-6),(180,dcx,dcy+arm/2+6),(90,dcx+arm/2+6,dcy),(270,dcx-arm/2-6,dcy)]:
    el.append(f'<polygon points="{gx},{gy-4} {gx-4},{gy+3} {gx+4},{gy+3}" fill="#5a5a68" '
              f'transform="rotate({ang} {gx} {gy})"/>')
el.append(txt(dcx, dcy+arm/2+thick/2+18, "SKIP STEP", 8, BODY_EDGE, "middle", "800", ls="1.5", opacity=0.8))

# --- A / B round buttons (right, diagonal) — real transport controls ---
# B = lower-left (FINISH/stop), A = upper-right (PAUSE)
bB = (DX+DW-118, CY+78)
bA = (DX+DW-58, CY+40)
for (bx,by),glyph,cap,gsz in [(bB,"&#9632;","FINISH",17),(bA,"&#10073;&#10073;","PAUSE",15)]:
    el.append(f'<circle cx="{bx}" cy="{by+3}" r="29" fill="#000" opacity="0.22"/>')
    el.append(f'<circle cx="{bx}" cy="{by}" r="29" fill="#1a1430"/>')           # socket
    el.append(f'<circle cx="{bx}" cy="{by}" r="25" fill="url(#btn)" filter="url(#soft)"/>')
    el.append(f'<ellipse cx="{bx-6}" cy="{by-8}" rx="9" ry="6" fill="#fff" opacity="0.35"/>')
    el.append(txt(bx, by+gsz*0.34, glyph, gsz, "#3a0a1e", "middle", "900"))
    el.append(txt(bx, by+44, cap, 8, BODY_EDGE, "middle", "800", ls="1.5", opacity=0.85))

# --- START / SELECT angled pills (center-low) — PREV-step / LAP ---
pcx, pcy = W/2 - 4, CY+138
for i,lab in enumerate(["PREV","LAP"]):
    px = pcx - 36 + i*72
    el.append(f'<g transform="rotate(-20 {px} {pcy})">')
    el.append(f'<ellipse cx="{px}" cy="{pcy+4}" rx="30" ry="11" fill="#000" opacity="0.18"/>')
    el.append(rrect(px-30, pcy-9, 60, 18, 9, "url(#pill)", "#15102a", 1, flt="soft"))
    el.append(rrect(px-26, pcy-7, 52, 6, 3, "#ffffff", opacity=0.06))
    el.append('</g>')
    el.append(txt(px, pcy+26, lab, 8, BODY_EDGE, "middle", "800", ls="1.5", opacity=0.8))

# --- speaker grille (bottom-right, recessed slot cluster) ---
spx, spy = DX+DW-78, CY+150
el.append(f'<g transform="rotate(-20 {spx} {spy})">')
el.append(rrect(spx-34, spy-26, 64, 52, 9, "#000", opacity=0.10))
for i in range(5):
    el.append(rrect(spx-28, spy-20+i*10, 52, 4, 2, SPK_LINE, opacity=0.75))
el.append('</g>')

el.append('</g>')   # end display clip

# subtle screen glass reflection over whole device top-left
el.append(f'<path d="M{DX+20},{DY+8} Q{W*0.5},{DY+60} {DX+DW-20},{DY+8}" fill="none" '
          f'stroke="#fff" stroke-width="1" opacity="0.06"/>')

el.append('</g></svg>')

with open("arcade-handheld.svg","w") as f:
    f.write("\n".join(el))
print("wrote arcade-handheld.svg")
