#!/usr/bin/env python3
"""Arcade HANDHELD theme — composed on real iOS + watchOS device aspect ratios.
Left: iPhone (full GBC-era handheld skin). Right: Apple Watch (degraded form —
LCD screen treatment + phosphor 7-seg + scanlines only; controls are the watch's
real buttons/swipes, no D-pad). Generic shapes + color, no trademark.

Render:
  python3 gen_devices.py
  rm -f arcade-devices.svg.png
  qlmanage -t -s 1800 -o . arcade-devices.svg
  mv arcade-devices.svg.png arcade-devices.png
"""
import math, random

SQ = 900

PHONE="#0a0a0d"; PHONE_RIM="#26262e"
BODY1="#8675cf"; BODY2="#574a9c"; BODY3="#3d3275"; BODY_EDGE="#2b2356"; BODY_HI="#b3a6e8"
BEZEL1="#2a2a32"; BEZEL2="#16161c"; GLASS_BG="#06121b"
PHOS="#2bff67"; PHOS_DIM="#0d5a26"; YELLOW="#ffd400"; CYAN="#28e6ff"
MAGENTA="#ff5cf0"; NEON_PINK="#ff2bd6"; NEON_CYAN="#21e6ff"; DIMTXT="#3a7a8f"; WHITE="#f4f4ff"
DPAD1="#26262e"; DPAD2="#101015"; DPAD_HI="#43434f"
BTN_MAG1="#ff4d8d"; BTN_MAG2="#c11d5e"; PILL1="#3a3358"; PILL2="#241f3c"; SPK_LINE="#2b2356"
LED_RED="#ff3b53"; WATCH="#08080b"; WATCH_RIM="#3a3a42"; CROWN="#5a5a64"

SEG={"0":"abcdef","1":"bc","2":"abged","3":"abgcd","4":"fgbc",
     "5":"afgcd","6":"afgcde","7":"abc","8":"abcdefg","9":"abcfgd"}

def seven_seg(x,y,w,h,ch,on,off,t=None):
    if t is None: t=w*0.18
    segs=SEG.get(ch,""); out=[]
    def horiz(cy):
        l=x+t*0.7; r=x+w-t*0.7
        return (f'<polygon points="{l},{cy} {l+t*0.7},{cy-t/2} {r-t*0.7},{cy-t/2} '
                f'{r},{cy} {r-t*0.7},{cy+t/2} {l+t*0.7},{cy+t/2}" ')
    def vert(cx,top,bot):
        return (f'<polygon points="{cx},{top} {cx+t/2},{top+t*0.7} {cx+t/2},{bot-t*0.7} '
                f'{cx},{bot} {cx-t/2},{bot-t*0.7} {cx-t/2},{top+t*0.7}" ')
    midy=y+h/2
    geom={"a":horiz(y+t*0.6),"g":horiz(midy),"d":horiz(y+h-t*0.6),
          "f":vert(x+t*0.6,y+t*0.9,midy-t*0.2),"b":vert(x+w-t*0.6,y+t*0.9,midy-t*0.2),
          "e":vert(x+t*0.6,midy+t*0.2,y+h-t*0.9),"c":vert(x+w-t*0.6,midy+t*0.2,y+h-t*0.9)}
    for s,g in geom.items():
        col=on if s in segs else off; opa="1" if s in segs else "0.13"
        out.append(g+f'fill="{col}" opacity="{opa}"/>')
    return "\n".join(out)

def seven_seg_str(x,y,cw,chh,s,on,off,gap=None):
    if gap is None: gap=cw*0.32
    out=[]; cx=x
    for ch in s:
        if ch==":":
            r=chh*0.06
            out.append(f'<circle cx="{cx+gap/2}" cy="{y+chh*0.34}" r="{r}" fill="{on}"/>')
            out.append(f'<circle cx="{cx+gap/2}" cy="{y+chh*0.66}" r="{r}" fill="{on}"/>')
            cx+=gap; continue
        out.append(seven_seg(cx,y,cw,chh,ch,on,off)); cx+=cw+gap
    return "\n".join(out),cx

def rrect(x,y,w,h,r,fill,stroke=None,sw=0,opacity=1,flt=None):
    s=f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" ry="{r}" fill="{fill}" opacity="{opacity}"'
    if stroke: s+=f' stroke="{stroke}" stroke-width="{sw}"'
    if flt: s+=f' filter="url(#{flt})"'
    return s+"/>"

def txt(x,y,s,size,fill,anchor="start",weight="700",family="Menlo, monospace",ls="0",opacity=1,flt=None,rot=None):
    f=f' filter="url(#{flt})"' if flt else ""
    tr=f' transform="rotate({rot} {x} {y})"' if rot is not None else ""
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
            f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
            f'letter-spacing="{ls}" opacity="{opacity}"{f}{tr}>{s}</text>')

el=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{SQ}" height="{SQ}" viewBox="0 0 {SQ} {SQ}">']
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
for fid,dev in [("glowS","1.6"),("glowM","3")]:
    el.append(f'<filter id="{fid}" x="-60%" y="-60%" width="220%" height="220%">'
              f'<feGaussianBlur stdDeviation="{dev}" result="b"/><feMerge>'
              f'<feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
el.append(f'<filter id="soft" x="-40%" y="-40%" width="180%" height="180%">'
          f'<feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#000" flood-opacity="0.55"/></filter>')
el.append('</defs>')
el.append(f'<rect x="0" y="0" width="{SQ}" height="{SQ}" fill="#eef0f6"/>')

def scanlines(GX,GY,GW,GH,clip):
    sl=[]; yy=GY+3
    while yy<GY+GH:
        sl.append(f'<rect x="{GX}" y="{yy}" width="{GW}" height="1.2" fill="#000" opacity="0.18"/>'); yy+=4
    return f'<g clip-path="url(#{clip})">{"".join(sl)}</g>'

# =================== iPhone (full handheld skin) ===================
PX,PY=34,28
W,H=360,800
el.append(f'<g transform="translate({PX},{PY})">')
el.append(rrect(0,0,W,H,56,PHONE,flt="soft"))
el.append(rrect(2,2,W-4,H-4,54,"none",PHONE_RIM,1.4))
DB=8; DX,DY,DW,DH=DB,DB,W-2*DB,H-2*DB
el.append(f'<clipPath id="disp"><rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" rx="48"/></clipPath>')
el.append(f'<g clip-path="url(#disp)">')
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#body)"/>')
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#bodysheen)"/>')
el.append(f'<rect x="{DX}" y="{DY}" width="{DW}" height="{DH}" fill="url(#vign)" opacity="0.5"/>')
random.seed(7)
spk=[]
for _ in range(200):
    px=DX+random.random()*DW; py=DY+random.random()*DH
    spk.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="0.7" fill="#fff" opacity="0.05"/>')
el.append("".join(spk))
el.append(rrect(W/2-42,DY+9,84,24,12,"#000"))
el.append(f'<circle cx="{W/2+28}" cy="{DY+21}" r="3.6" fill="#0c1418"/>')

SBX,SBY,SBW,SBH=DX+20,DY+46,DW-40,388
el.append(rrect(SBX,SBY,SBW,SBH,17,"url(#bezel)","#000",1,flt="soft"))
el.append(f'<circle cx="{SBX+16}" cy="{SBY+17}" r="3" fill="{LED_RED}" filter="url(#glowS)"/>')
el.append(txt(SBX+26,SBY+20,"POWER",8,LED_RED,"start","700",ls="1"))
el.append(txt(SBX+SBW-13,SBY+20,"DOT-MATRIX HR",7,"#6b6b78","end","700",ls="1.5"))
GX,GY=SBX+15,SBY+31; GW,GH=SBW-30,SBH-46
el.append(rrect(GX,GY,GW,GH,8,"url(#glass)"))
el.append(rrect(GX,GY,GW,GH,8,"none",NEON_CYAN,1,opacity=0.25))
el.append(f'<clipPath id="gclip"><rect x="{GX}" y="{GY}" width="{GW}" height="{GH}" rx="8"/></clipPath>')
el.append(scanlines(GX,GY,GW,GH,"gclip"))
el.append(txt(GX+13,GY+24,"1UP",10,NEON_CYAN,"start","800",ls="1"))
el.append(f'<text x="{GX+13}" y="{GY+49}" font-family="Menlo, monospace" font-size="24" font-weight="800" fill="{YELLOW}" filter="url(#glowS)">142</text>')
el.append(txt(GX+66,GY+49,"&#9829; Z3",12,YELLOW,"start","700"))
el.append(txt(GX+GW-13,GY+24,"HI-SCORE",10,NEON_PINK,"end","800",ls="1"))
el.append(f'<text x="{GX+GW-13}" y="{GY+49}" font-family="Menlo, monospace" font-size="24" font-weight="800" fill="{PHOS}" text-anchor="end" filter="url(#glowS)">03280</text>')
el.append(txt(GX+GW-13,GY+62,"STEPS",8,DIMTXT,"end","700",ls="1"))
heroY=GY+82; cw,chh=38,68
seg_svg,_=seven_seg_str(GX+28,heroY,cw,chh,"01:48",PHOS,PHOS_DIM,gap=12)
el.append(f'<g filter="url(#glowM)">{seg_svg}</g>')
el.append(txt(GX+GW/2,heroY+chh+18,"WORK REMAINING",10,NEON_CYAN,"middle","800",ls="3",opacity=0.85))
sbY=heroY+chh+40
el.append(txt(GX+13,sbY+10,"STAGE 3/8",9,NEON_CYAN,"start","800",ls="1"))
barX=GX+92; barW=GW-106; cells=10; filled=3
cellw=(barW-(cells-1)*4)/cells
for i in range(cells):
    cx=barX+i*(cellw+4); c=PHOS if i<filled else PHOS_DIM
    el.append(rrect(cx,sbY+1,cellw,10,2,c,opacity=("1" if i<filled else "0.4"),flt=("glowS" if i<filled else None)))
mbY=sbY+25; mbH=56; gapb=6
bw=(GW-26-3*gapb)/4
metrics=[("HR","142",YELLOW),("DIST","2.15",PHOS),("PACE","5:42",NEON_CYAN),("SPM","168",NEON_PINK)]
for i,(lab,val,col) in enumerate(metrics):
    bx=GX+13+i*(bw+gapb)
    el.append(rrect(bx,mbY,bw,mbH,5,"#04030f",col,1.3,flt="glowS"))
    el.append(rrect(bx+2,mbY+2,bw-4,mbH*0.4,4,"#ffffff",opacity=0.05))
    el.append(txt(bx+bw/2,mbY+15,lab,8,col,"middle","800",ls="1"))
    el.append(txt(bx+bw/2,mbY+41,val,18,WHITE,"middle","800"))
el.append(f'<rect x="{GX}" y="{GY}" width="{GW}" height="{GH}" fill="url(#vign)" opacity="0.5" clip-path="url(#gclip)"/>')
el.append(txt(W/2,SBY+SBH+28,"SHUTTLX",21,BODY_EDGE,"middle","900",ls="2",opacity=0.9))
el.append(txt(W/2+1,SBY+SBH+27,"SHUTTLX",21,BODY_HI,"middle","900",ls="2",opacity=0.5))
el.append(txt(W/2,SBY+SBH+43,"INTERVAL  SYSTEM",8,BODY_EDGE,"middle","700",ls="4",opacity=0.7))
CY=SBY+SBH+86
dcx,dcy=DX+86,CY+54; arm,thick=70,28
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="58" fill="#000" opacity="0.12"/>')
el.append(rrect(dcx-thick/2,dcy-arm/2-thick/2,thick,arm+thick,8,"url(#dpad)",flt="soft"))
el.append(rrect(dcx-arm/2-thick/2,dcy-thick/2,arm+thick,thick,8,"url(#dpad)"))
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="12" fill="{DPAD2}"/>')
el.append(f'<circle cx="{dcx}" cy="{dcy}" r="12" fill="none" stroke="{DPAD_HI}" stroke-width="1" opacity="0.6"/>')
for ang,gx,gy in [(0,dcx,dcy-arm/2-5),(180,dcx,dcy+arm/2+5),(90,dcx+arm/2+5,dcy),(270,dcx-arm/2-5,dcy)]:
    el.append(f'<polygon points="{gx},{gy-4} {gx-4},{gy+3} {gx+4},{gy+3}" fill="#5a5a68" transform="rotate({ang} {gx} {gy})"/>')
el.append(txt(dcx,dcy+arm/2+thick/2+16,"SKIP STEP",8,BODY_EDGE,"middle","800",ls="1.5",opacity=0.8))
bB=(DX+DW-108,CY+72); bA=(DX+DW-52,CY+36)
for (bx,by),glyph,cap,gsz in [(bB,"&#9632;","FINISH",16),(bA,"&#10073;&#10073;","PAUSE",14)]:
    el.append(f'<circle cx="{bx}" cy="{by+3}" r="27" fill="#000" opacity="0.22"/>')
    el.append(f'<circle cx="{bx}" cy="{by}" r="27" fill="#1a1430"/>')
    el.append(f'<circle cx="{bx}" cy="{by}" r="23" fill="url(#btn)" filter="url(#soft)"/>')
    el.append(f'<ellipse cx="{bx-5}" cy="{by-7}" rx="8" ry="5" fill="#fff" opacity="0.35"/>')
    el.append(txt(bx,by+gsz*0.34,glyph,gsz,"#3a0a1e","middle","900"))
    el.append(txt(bx,by+41,cap,8,BODY_EDGE,"middle","800",ls="1.5",opacity=0.85))
pcx,pcy=W/2-4,CY+132
for i,lab in enumerate(["PREV","LAP"]):
    px=pcx-34+i*68
    el.append(f'<g transform="rotate(-20 {px} {pcy})">')
    el.append(f'<ellipse cx="{px}" cy="{pcy+4}" rx="28" ry="10" fill="#000" opacity="0.18"/>')
    el.append(rrect(px-28,pcy-8,56,16,8,"url(#pill)","#15102a",1,flt="soft"))
    el.append(rrect(px-24,pcy-6,48,5,3,"#ffffff",opacity=0.06))
    el.append('</g>')
    el.append(txt(px,pcy+24,lab,8,BODY_EDGE,"middle","800",ls="1.5",opacity=0.8))
spx,spy=DX+DW-72,CY+144
el.append(f'<g transform="rotate(-20 {spx} {spy})">')
el.append(rrect(spx-32,spy-24,60,48,9,"#000",opacity=0.10))
for i in range(5):
    el.append(rrect(spx-26,spy-18+i*9,48,4,2,SPK_LINE,opacity=0.75))
el.append('</g>')
el.append('</g>')  # disp clip
el.append(txt(W/2,H+24,"iPhone &#183; active workout",13,"#6a6a76","middle","700",ls="1"))
el.append('</g>')

# =================== Apple Watch (degraded form) ===================
# Series-10 46mm aspect ~ 0.84 (w/h)
WW,WH=232,278
WPX,WPY=560,250
el.append(f'<g transform="translate({WPX},{WPY})">')
# side button + digital crown on right edge
el.append(rrect(WW-3,WH*0.30,9,46,5,CROWN))           # crown
el.append(f'<circle cx="{WW+2}" cy="{WH*0.30+23}" r="5" fill="#76767e"/>')
el.append(rrect(WW-2,WH*0.56,7,34,4,"#3a3a42"))       # side button
# case
el.append(rrect(0,0,WW,WH,62,WATCH,flt="soft"))
el.append(rrect(2,2,WW-4,WH-4,60,"none",WATCH_RIM,1.3))
WDB=10; WDX,WDY,WDW,WDH=WDB,WDB,WW-2*WDB,WH-2*WDB
el.append(f'<clipPath id="wdisp"><rect x="{WDX}" y="{WDY}" width="{WDW}" height="{WDH}" rx="52"/></clipPath>')
el.append(f'<g clip-path="url(#wdisp)">')
# LCD glass fills screen; thin GBC-purple frame inside the edge (degraded "bezel only")
el.append(f'<rect x="{WDX}" y="{WDY}" width="{WDW}" height="{WDH}" fill="url(#glass)"/>')
el.append(rrect(WDX+4,WDY+4,WDW-8,WDH-8,48,"none",BODY2,3,opacity=0.55))   # purple identity frame
el.append(f'<clipPath id="wgclip"><rect x="{WDX}" y="{WDY}" width="{WDW}" height="{WDH}" rx="52"/></clipPath>')
el.append(scanlines(WDX,WDY,WDW,WDH,"wgclip"))
wcx=WDX+WDW/2
# top strip: HR + step
el.append(txt(WDX+22,WDY+34,"142",20,YELLOW,"start","800",flt="glowS"))
el.append(txt(WDX+62,WDY+34,"&#9829;Z3",11,YELLOW,"start","700"))
el.append(txt(WDX+WDW-22,WDY+34,"3/8",13,NEON_CYAN,"end","800"))
el.append(txt(WDX+WDW-22,WDY+46,"STAGE",7,DIMTXT,"end","700",ls="1"))
# hero 7-seg timer
whY=WDY+50; wcw,wchh=30,52
wseg,wend=seven_seg_str(WDX+18,whY,wcw,wchh,"01:48",PHOS,PHOS_DIM,gap=9)
el.append(f'<g filter="url(#glowM)">{wseg}</g>')
el.append(txt(wcx,whY+wchh+15,"WORK REMAINING",8,NEON_CYAN,"middle","800",ls="2",opacity=0.85))
# stage bar
wsbY=whY+wchh+26; wbarX=WDX+18; wbarW=WDW-36; wcells=8; wfill=3
wcw2=(wbarW-(wcells-1)*3)/wcells
for i in range(wcells):
    cx=wbarX+i*(wcw2+3); c=PHOS if i<wfill else PHOS_DIM
    el.append(rrect(cx,wsbY,wcw2,7,2,c,opacity=("1" if i<wfill else "0.4"),flt=("glowS" if i<wfill else None)))
# compact two-up metrics (DIST / PACE) + SPM row
wmY=wsbY+18; wbw=(WDW-36-8)/2
for i,(lab,val,col) in enumerate([("DIST","2.15",PHOS),("PACE","5:42",NEON_CYAN)]):
    bx=WDX+18+i*(wbw+8)
    el.append(rrect(bx,wmY,wbw,34,5,"#04030f",col,1.1,flt="glowS"))
    el.append(txt(bx+7,wmY+13,lab,7,col,"start","800",ls="1"))
    el.append(txt(bx+wbw/2,wmY+29,val,15,WHITE,"middle","800"))
el.append(txt(WDX+18,wmY+50,"SPM",7,NEON_PINK,"start","800",ls="1"))
el.append(txt(WDX+WDW-18,wmY+51,"168",14,WHITE,"end","800"))
el.append(f'<rect x="{WDX}" y="{WDY}" width="{WDW}" height="{WDH}" fill="url(#vign)" opacity="0.55" clip-path="url(#wgclip)"/>')
el.append('</g>')  # wdisp clip
el.append(txt(WW/2,WH+24,"Apple Watch &#183; same screen",13,"#6a6a76","middle","700",ls="1"))
el.append(txt(WW/2,WH+42,"(LCD + 7-seg + scanlines; no D-pad)",10,"#9a9aa4","middle","600"))
el.append('</g>')

el.append('</svg>')
with open("arcade-devices.svg","w") as f:
    f.write("\n".join(el))
print("wrote arcade-devices.svg")
