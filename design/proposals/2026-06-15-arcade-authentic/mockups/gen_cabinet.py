#!/usr/bin/env python3
"""Arcade authentic-hardware mockup generator — v2, 1980s synthwave-arcade aesthetic.
Full upright cabinet, dark charcoal finish, neon trim, glowing marquee, synthwave CRT,
live-data-driven chrome. iPhone-portrait timer screen for aesthetic review (no Swift).

Render:
  python3 gen_cabinet.py
  qlmanage -t -s 1540 -o . arcade-cabinet-v2.svg
  sips -c 1540 840 arcade-cabinet-v2.svg.png --out arcade-cabinet-v2.png
"""
import math

W, H = 420, 770
SQ = 770
OFFX = (SQ - W) // 2     # center portrait

# ---- palette: 80s synthwave-arcade ----
CAB_TOP   = "#211b2e"    # charcoal w/ violet cast
CAB_BOT   = "#0a0810"
MARQ_BG   = "#0a0612"
NEON_PINK = "#ff2bd6"
NEON_CYAN = "#21e6ff"
NEON_PURP = "#9d4bff"
GLOW_Y    = "#ffe24a"    # HR-zone-3 warm marquee back-light
SUN_TOP   = "#ffd23f"
SUN_BOT   = "#ff2d95"
CRT_BG    = "#060316"    # deep indigo glass
PHOS      = "#2bff67"    # phosphor green
PHOS_DIM  = "#0d5a26"
RED       = "#ff3b53"
RED_DK    = "#8a0d22"
YELLOW    = "#ffd400"
CYAN      = "#28e6ff"
MAGENTA   = "#ff5cf0"
DIMTXT    = "#3a7a8f"
WHITE     = "#f4f4ff"
CHROME_LT = "#cfd6e6"
CHROME_DK = "#4a4f63"

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
        opa = "1" if s in segs else "0.14"
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

def txt(x,y,s,size,fill,anchor="start",weight="700",family="Menlo, monospace",ls="0",opacity=1,flt=None):
    f = f' filter="url(#{flt})"' if flt else ""
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
            f'letter-spacing="{ls}" opacity="{opacity}"{f}>{s}</text>')

el = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SQ}" height="{SQ}" viewBox="0 0 {SQ} {SQ}">']

# ---------- defs ----------
el.append('<defs>')
el.append(f'<linearGradient id="cab" x1="0" y1="0" x2="0.3" y2="1">'
          f'<stop offset="0" stop-color="{CAB_TOP}"/><stop offset="1" stop-color="{CAB_BOT}"/></linearGradient>')
el.append(f'<linearGradient id="tmold" x1="0" y1="0" x2="1" y2="1">'
          f'<stop offset="0" stop-color="{NEON_CYAN}"/><stop offset="0.5" stop-color="{NEON_PURP}"/>'
          f'<stop offset="1" stop-color="{NEON_PINK}"/></linearGradient>')
el.append(f'<linearGradient id="title" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{NEON_CYAN}"/><stop offset="0.5" stop-color="#ffffff"/>'
          f'<stop offset="0.52" stop-color="{NEON_PINK}"/><stop offset="1" stop-color="{NEON_PURP}"/></linearGradient>')
el.append(f'<radialGradient id="marqglow" cx="0.5" cy="0.5" r="0.65">'
          f'<stop offset="0" stop-color="{GLOW_Y}" stop-opacity="0.9"/>'
          f'<stop offset="0.45" stop-color="#ff7a18" stop-opacity="0.45"/>'
          f'<stop offset="1" stop-color="{GLOW_Y}" stop-opacity="0"/></radialGradient>')
el.append(f'<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{SUN_TOP}"/><stop offset="1" stop-color="{SUN_BOT}"/></linearGradient>')
el.append(f'<radialGradient id="barrel" cx="0.5" cy="0.5" r="0.75">'
          f'<stop offset="0.55" stop-color="#000" stop-opacity="0"/>'
          f'<stop offset="1" stop-color="#000" stop-opacity="0.6"/></radialGradient>')
el.append(f'<linearGradient id="chrome" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="{CHROME_LT}"/><stop offset="0.5" stop-color="{CHROME_DK}"/>'
          f'<stop offset="1" stop-color="#23262f"/></linearGradient>')
el.append(f'<linearGradient id="panel" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="#2a2440"/><stop offset="1" stop-color="#15101f"/></linearGradient>')
for fid, dev in [("glowS","1.6"),("glowM","3"),("glowL","6")]:
    el.append(f'<filter id="{fid}" x="-60%" y="-60%" width="220%" height="220%">'
              f'<feGaussianBlur stdDeviation="{dev}" result="b"/><feMerge>'
              f'<feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
el.append('</defs>')

el.append(f'<rect x="0" y="0" width="{SQ}" height="{SQ}" fill="#000"/>')
el.append(f'<g transform="translate({OFFX},0)">')

# ---------- 1. CABINET BODY ----------
el.append(rrect(0,0,W,H,0,"url(#cab)"))
# faint diagonal grid texture in body (80s)
grid = []
for gx in range(-H, W, 26):
    grid.append(f'<line x1="{gx}" y1="0" x2="{gx+H}" y2="{H}" stroke="{NEON_PURP}" stroke-width="0.5" opacity="0.05"/>')
el.append("".join(grid))
el.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#barrel)" opacity="0.45"/>')
# neon T-molding edge trim
el.append(rrect(5,5,W-10,H-10,14,"none","url(#tmold)",3,flt="glowM"))
el.append(rrect(5,5,W-10,H-10,14,"none","url(#tmold)",1.4))

# ---------- 2. MARQUEE ----------
MQ_Y, MQ_H = 16, 92
el.append(rrect(14,MQ_Y,W-28,MQ_H,8,MARQ_BG,NEON_PINK,1.4,flt="glowS"))
# sunburst rays behind title
cxm, cym = W/2, MQ_Y+MQ_H/2
rays = []
for a in range(0, 360, 18):
    r = math.radians(a)
    x2 = cxm + 240*math.cos(r); y2 = cym + 60*math.sin(r)
    rays.append(f'<line x1="{cxm}" y1="{cym}" x2="{x2}" y2="{y2}" stroke="{NEON_PINK}" stroke-width="3" opacity="0.10"/>')
el.append("".join(rays))
el.append(f'<ellipse cx="{cxm}" cy="{cym}" rx="{W*0.40}" ry="30" fill="url(#marqglow)"/>')
el.append(txt(cxm, cym-2, "INTERVAL RUN", 24, "url(#title)", "middle", "800", ls="2", flt="glowS"))
el.append(txt(cxm, MQ_Y+MQ_H-13, "&#9733;  PLAYER 1  &#9733;", 11, NEON_CYAN, "middle", "700", ls="3"))

# ---------- 3. CRT BEZEL + GLASS ----------
BZ_Y, BZ_H = MQ_H+30, 430
# chrome bezel
el.append(rrect(14, BZ_Y, W-28, BZ_H, 12, "url(#chrome)"))
# bevel edges
el.append(f'<path d="M{18},{BZ_Y+BZ_H-8} L{18},{BZ_Y+6} L{W-18},{BZ_Y+6}" fill="none" stroke="#eef1f8" stroke-width="2" opacity="0.8"/>')
el.append(f'<path d="M{18},{BZ_Y+BZ_H-8} L{W-18},{BZ_Y+BZ_H-8} L{W-18},{BZ_Y+6}" fill="none" stroke="#000" stroke-width="2.5" opacity="0.8"/>')
# corner rivets
for rx, ry in [(26,BZ_Y+14),(W-26,BZ_Y+14),(26,BZ_Y+BZ_H-14),(W-26,BZ_Y+BZ_H-14)]:
    el.append(f'<circle cx="{rx}" cy="{ry}" r="4.5" fill="#1a1d24"/>')
    el.append(f'<circle cx="{rx-1}" cy="{ry-1}" r="1.8" fill="#dfe4ee"/>')

GX, GY = 30, BZ_Y+18
GW, GH = W-60, BZ_H-36
el.append(rrect(GX, GY, GW, GH, 8, CRT_BG))
# neon inner edge of glass
el.append(rrect(GX, GY, GW, GH, 8, "none", NEON_CYAN, 1, opacity=0.4))

# --- synthwave backdrop inside glass (faint, behind data) ---
# sun low-center with horizontal slits
sun_cx, sun_cy, sun_r = GX+GW/2, GY+GH*0.40, 58
el.append(f'<clipPath id="glassclip"><rect x="{GX}" y="{GY}" width="{GW}" height="{GH}" rx="8"/></clipPath>')
el.append(f'<g clip-path="url(#glassclip)" opacity="0.16">')
el.append(f'<circle cx="{sun_cx}" cy="{sun_cy}" r="{sun_r}" fill="url(#sun)"/>')
for i in range(5):
    yy = sun_cy + 6 + i*7
    el.append(f'<rect x="{sun_cx-sun_r}" y="{yy}" width="{2*sun_r}" height="{3+i}" fill="{CRT_BG}"/>')
# perspective grid (bottom of glass)
hz = GY+GH*0.62
for i in range(9):
    yy = hz + (i*i)*2.4
    if yy > GY+GH: break
    el.append(f'<line x1="{GX}" y1="{yy}" x2="{GX+GW}" y2="{yy}" stroke="{NEON_PINK}" stroke-width="1"/>')
for vx in range(-6, 7):
    x2 = sun_cx + vx*26
    el.append(f'<line x1="{sun_cx}" y1="{hz}" x2="{sun_cx + vx*70}" y2="{GY+GH}" stroke="{NEON_CYAN}" stroke-width="0.8"/>')
el.append('</g>')
# scanlines over everything in glass
sl = []
yy = GY+3
while yy < GY+GH:
    sl.append(f'<rect x="{GX}" y="{yy}" width="{GW}" height="1.3" fill="#000" opacity="0.22"/>'); yy += 4
el.append(f'<g clip-path="url(#glassclip)">{"".join(sl)}</g>')
el.append(rrect(GX, GY, GW, GH, 8, "url(#barrel)", opacity=0.65))

# --- CRT DATA CONTENT (full opacity, on top) ---
el.append(txt(GX+14, GY+24, "1UP", 11, NEON_CYAN, "start", "800", ls="1"))
el.append(f'<text x="{GX+14}" y="{GY+50}" font-family="Menlo, monospace" font-size="26" font-weight="800" fill="{YELLOW}" filter="url(#glowS)">142</text>')
el.append(txt(GX+74, GY+50, "&#9829; Z3", 13, YELLOW, "start", "700"))
el.append(txt(GX+GW-14, GY+24, "HI-SCORE", 11, NEON_PINK, "end", "800", ls="1"))
el.append(f'<text x="{GX+GW-14}" y="{GY+50}" font-family="Menlo, monospace" font-size="26" font-weight="800" fill="{PHOS}" text-anchor="end" filter="url(#glowS)">03280</text>')
el.append(txt(GX+GW-14, GY+64, "STEPS", 9, DIMTXT, "end", "700", ls="1"))

heroY = GY+90; cw, ch = 44, 84
seg_svg, _ = seven_seg_str(GX+34, heroY, cw, ch, "01:48", PHOS, PHOS_DIM, gap=14)
el.append(f'<g filter="url(#glowM)">{seg_svg}</g>')
el.append(txt(GX+GW/2, heroY+ch+22, "WORK REMAINING", 12, NEON_CYAN, "middle", "800", ls="3", opacity=0.85))

sbY = heroY+ch+54
el.append(txt(GX+14, sbY+12, "STAGE 3/8", 11, NEON_CYAN, "start", "800", ls="1"))
barX = GX+110; barW = GW-124; cells = 10; filled = 3
cellw = (barW-(cells-1)*4)/cells
for i in range(cells):
    cx = barX + i*(cellw+4)
    c = PHOS if i < filled else PHOS_DIM
    el.append(rrect(cx, sbY+2, cellw, 12, 2, c, opacity=("1" if i<filled else "0.4"),
                    flt=("glowS" if i<filled else None)))
dotsY = sbY+34; nd = 8
for i in range(nd):
    cx = GX+18 + i*((GW-36)/(nd-1))
    if i < 2: c, op, fl = PHOS, "1", None
    elif i == 2: c, op, fl = YELLOW, "1", "glowS"
    else: c, op, fl = PHOS_DIM, "0.45", None
    el.append(f'<circle cx="{cx}" cy="{dotsY}" r="4" fill="{c}" opacity="{op}"'+(f' filter="url(#{fl})"' if fl else "")+'/>')

mbY = dotsY+24; mbH = 68; gapb = 8
bw = (GW-28-3*gapb)/4
metrics = [("HR","142",YELLOW),("DIST","2.15",PHOS),("PACE","5:42",NEON_CYAN),("SPM","168",NEON_PINK)]
for i,(lab,val,col) in enumerate(metrics):
    bx = GX+14 + i*(bw+gapb)
    el.append(rrect(bx, mbY, bw, mbH, 5, "#04030f", col, 1.4, flt="glowS"))
    el.append(rrect(bx+2, mbY+2, bw-4, mbH*0.4, 4, "#ffffff", opacity=0.04))  # gloss
    el.append(txt(bx+bw/2, mbY+18, lab, 10, col, "middle", "800", ls="1"))
    el.append(txt(bx+bw/2, mbY+47, val, 22, WHITE, "middle", "800"))

# ---------- 4. CONTROL PANEL ----------
CP_Y, CP_H = BZ_Y+BZ_H+14, 132
el.append(rrect(14, CP_Y, W-28, CP_H, 10, "url(#panel)", NEON_PURP, 1.2, flt="glowS"))
el.append(rrect(14, CP_Y, W-28, 4, 10, "#4a4068"))
jcx = 70; jcy = CP_Y+CP_H/2
# joystick LED ring
el.append(f'<circle cx="{jcx}" cy="{jcy}" r="44" fill="#070510"/>')
el.append(f'<circle cx="{jcx}" cy="{jcy}" r="44" fill="none" stroke="{NEON_PURP}" stroke-width="1" opacity="0.5"/>')
nled = 12; prog = 0.30; lit = int(nled*prog)
for i in range(nled):
    ang = -90 + i*(360/nled); rad = math.radians(ang)
    lx = jcx+34*math.cos(rad); ly = jcy+34*math.sin(rad)
    c = PHOS if i < lit else PHOS_DIM
    el.append(f'<circle cx="{lx}" cy="{ly}" r="3.6" fill="{c}" opacity="{"1" if i<lit else "0.35"}"'
              +(' filter="url(#glowS)"' if i<lit else "")+'/>')
el.append(f'<rect x="{jcx-3}" y="{jcy-2}" width="6" height="20" fill="#0c0c12"/>')
el.append(f'<circle cx="{jcx}" cy="{jcy-6}" r="11" fill="{RED}" filter="url(#glowS)"/>')
el.append(f'<circle cx="{jcx-3}" cy="{jcy-9}" r="3.5" fill="#ffb0bc"/>')
# round arcade buttons
btns = [("&#8214;",RED,RED_DK,NEON_PINK,True),("&#9654;&#9654;","#5a5566","#2a2733",NEON_CYAN,False),
        ("&#9632;","#27c84a","#0c7a25",PHOS,False),("&#10005;","#cc2236","#700818",NEON_PINK,False)]
bstartx = 150; bgap = (W-28-bstartx-14)/3
for i,(g,top,bot,ring,latch) in enumerate(btns):
    bx = bstartx + i*bgap; by = jcy+(4 if latch else -2)
    el.append(f'<circle cx="{bx}" cy="{jcy}" r="23" fill="#040409"/>')
    el.append(f'<circle cx="{bx}" cy="{jcy}" r="23" fill="none" stroke="{ring}" stroke-width="1.3" opacity="0.7" filter="url(#glowS)"/>')
    el.append(f'<circle cx="{bx}" cy="{by}" r="19" fill="{bot}"/>')
    el.append(f'<circle cx="{bx}" cy="{by}" r="16" fill="{top}"/>')
    el.append(f'<ellipse cx="{bx-4}" cy="{by-6}" rx="7" ry="4.5" fill="#fff" opacity="0.4"/>')
    el.append(txt(bx, by+5, g, 15, "#0a0a14", "middle", "800"))

# ---------- 5. COIN DOOR ----------
CD_Y, CD_H = CP_Y+CP_H+10, 44
el.append(rrect(14, CD_Y, W-28, CD_H, 8, "url(#chrome)", "#000", 1))
for sx in [44, W-44]:
    el.append(rrect(sx-9, CD_Y+10, 18, 24, 2, "#0a0a0e"))
    el.append(rrect(sx-2, CD_Y+12, 4, 18, 1, "#3a3f4a"))
    el.append(f'<circle cx="{sx}" cy="{CD_Y+8}" r="1.6" fill="#dfe4ee"/>')
el.append(rrect(W/2-72, CD_Y+9, 144, 26, 5, "#06040e", NEON_PINK, 1, flt="glowS"))
el.append(txt(W/2, CD_Y+27, "CREDIT  02", 14, YELLOW, "middle", "800", ls="2"))

el.append('</g></svg>')

with open("arcade-cabinet-v2.svg","w") as f:
    f.write("\n".join(el))
print("wrote arcade-cabinet-v2.svg")
