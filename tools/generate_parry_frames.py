"""Original pixel parry/reaction poses and bounded contact effects.
Read-only reuse of Bellkeep's authored body vocabulary; no imported video pixels.
All fills and edge coordinates lie on the integer pixel grid.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math,json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'presentation/parry_frames';ART=ROOT/'artifacts'
P={'ink':'#101626','shade':'#24354e','cloak':'#326e89','fold':'#4a98aa','edge':'#8bc6c9','plate':'#7a98ae','metal':'#b5d6da','white':'#fff5d5','gold':'#d0a65b','skin':'#c8bf93','cyan':'#71ece1','red':'#b45566'}
FLOW=[(65,224,217),(72,191,237),(92,151,242),(122,115,228),(163,103,217),(205,116,205),(235,139,177),(246,170,137),(248,207,115)]
HERO={
'parry_ready':[(34,37,-35,0,1),(37,35,-55,-1,1),(38,35,-66,-1,2),(37,35,-70,-1,2)],
'parry_recoil':[(38,35,-66,-1,2),(33,31,-100,-3,3),(30,30,-119,-5,4),(31,32,-104,-3,3)],
'parry_recover':[(32,34,-92,-2,3),(34,35,-70,-1,2),(35,35,-40,0,1),(34,33,15,0,0)]}
BOSS={
'parry_recoil':[(0,0,-82,0),(1,-2,-111,1),(2,-4,-128,2),(1,-2,-118,1)],
'guard_break':[(0,-1,-115,2),(3,-4,-142,5),(7,-6,-157,11),(10,-7,-170,16)],
'guard_recover':[(10,-7,-170,16),(7,-5,-144,11),(3,-3,-119,5),(0,0,-89,0)]}

def ip(p):return(round(p[0]),round(p[1]))
def limb(d,a,b,width,color):
    dx=b[0]-a[0];dy=b[1]-a[1];length=max(1,math.hypot(dx,dy));nx=-dy/length*width*.5;ny=dx/length*width*.5
    d.polygon([ip((a[0]+nx,a[1]+ny)),ip((b[0]+nx,b[1]+ny)),ip((b[0]-nx,b[1]-ny)),ip((a[0]-nx,a[1]-ny))],fill=P.get(color,color),outline=P['ink'])
def weapon(d,hand,angle,length,frame,flow=True):
    a=math.radians(angle);ux,uy=math.cos(a),math.sin(a);nx,ny=-uy,ux;x,y=hand
    tip=(x+ux*length,y+uy*length);base=(x+ux*3,y+uy*3)
    d.polygon([ip((base[0]+nx*2,base[1]+ny*2)),ip((tip[0]-ux*3+nx,tip[1]-uy*3+ny)),ip(tip),ip((tip[0]-ux*3-nx,tip[1]-uy*3-ny)),ip((base[0]-nx*2,base[1]-ny*2))],fill=P['metal'],outline=P['ink'])
    d.line([ip(base),ip(tip)],fill=P['white'],width=1)
    if flow:
        for j in range(9):
            t=(j+1)/10;xx=x+ux*(3+(length-4)*t)+nx*2;yy=y+uy*(3+(length-4)*t)+ny*2
            d.line([ip((xx,yy)),ip((xx+ux*2,yy+uy*2))],fill=FLOW[(j+frame*2)%len(FLOW)],width=1)
    d.line([ip((x+nx*4,y+ny*4)),ip((x-nx*4,y-ny*4))],fill=P['gold'],width=2)

def hero(state,frame):
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);hx,hy,angle,lean,crouch=HERO[state][frame]
    sx=28+lean;sy=29+crouch;hip=(27,42+crouch)
    poly=lambda points,key:d.polygon([ip(p) for p in points],fill=P.get(key,key),outline=P['ink'])
    rect=lambda box,key:d.rectangle(tuple(round(x) for x in box),fill=P.get(key,key))
    # Feet stay planted while the knees, spine and arms absorb the clash.
    left_knee=(21-lean*.25,49+crouch*.4);right_knee=(34+lean*.25,48+crouch*.4)
    limb(d,(hip[0]-3,hip[1]),left_knee,6,'shade');limb(d,left_knee,(19,57),5,'shade')
    poly([(16,54),(20,54),(24,58),(16,58)],'plate');rect((17,56,22,57),'metal')
    trail=min(2+abs(lean)*2,sx-18)
    poly([(sx-4,sy-7),(sx-10,sy-1),(sx-11-trail,sy+9),(sx-17-trail,sy+17-crouch),(sx-8,sy+20),(sx-5,sy+15),(sx+1,sy+10)],'cloak')
    poly([(sx-8,sy-1),(sx-8-trail*.5,sy+8),(sx-13-trail,sy+15),(sx-5,sy+14)],'fold')
    d.line([ip((sx-10-trail,sy+14)),ip((sx-15-trail,sy+17-crouch)),ip((sx-8,sy+19))],fill=P['edge'])
    limb(d,(hip[0]+3,hip[1]),right_knee,7,'shade');limb(d,right_knee,(36,57),6,'plate')
    poly([(33,53),(37,54),(41,58),(33,58)],'shade');rect((34,55,39,56),'metal')
    poly([(sx-6,sy-3),(sx+4,sy-2),(sx+7,sy+7),(hip[0]+6,hip[1]+2),(hip[0]-6,hip[1]+2),(sx-7,sy+7)],'shade')
    poly([(sx-3,sy),(sx+4,sy),(sx+4,sy+7),(hip[0]+3,hip[1]-2),(hip[0]-1,hip[1]-1),(sx-4,sy+6)],'cloak')
    rect((sx-2,sy+1,sx,sy+6),'fold');rect((hip[0]-6,hip[1]-2,hip[0]+5,hip[1]),'gold');rect((hip[0]+1,hip[1]-3,hip[0]+3,hip[1]+1),'white')
    poly([(hip[0]-5,hip[1]+1),(hip[0],hip[1]+2),(hip[0]-3,hip[1]+7),(hip[0]-7,hip[1]+5)],'cloak')
    x=sx+1;y=sy-13
    poly([(x-8,y-3),(x-4,y-8),(x+4,y-7),(x+9,y-2),(x+10,y+5),(x+6,y+10),(x-5,y+8),(x-10,y+3)],'shade')
    poly([(x-3,y-5),(x+4,y-5),(x+7,y-1),(x+7,y+5),(x+3,y+8),(x-2,y+5),(x-4,y+1)],'skin')
    rect((x+4,y-1,x+8,y+1),'ink');rect((x+5,y-1,x+7,y-1),'cyan')
    d.line([ip((x-7,y-2)),ip((x-5,y-5)),ip((x,y-6))],fill=P['fold'])
    poly([(x-7,y+5),(x+1,y+8),(x-1,y+12),(x-10,y+9),(x-15-trail//2,y+10),(x-13,y+6)],'fold')
    d.line([ip((x-8,y+7)),ip((x-2,y+9))],fill=P['edge'])
    # Rear forearm braces the pommel; front elbow and blade visibly rebound.
    limb(d,(sx-4,sy+1),(sx+1,sy+7),5,'plate');limb(d,(sx+1,sy+7),(hx-3,hy+1),4,'shade')
    elbow=(sx+5,sy+5) if state=='parry_ready' else (sx+4,sy+2)
    limb(d,(sx+3,sy),elbow,6,'plate');limb(d,elbow,(hx,hy),5,'shade')
    rect((hx-2,hy-2,hx+2,hy+2),'gold');rect((hx-1,hy-2,hx+1,hy),'metal')
    weapon(d,(hx,hy),angle,22,frame)
    return im

def boss(state,f):
    im=Image.new('RGBA',(80,80));d=ImageDraw.Draw(im);lower,lean,angle,knee=BOSS[state][f]
    poly=lambda pts,c:d.polygon([ip(p) for p in pts],fill=P.get(c,c),outline=P['ink'])
    rect=lambda box,c:d.rectangle(tuple(round(x) for x in box),fill=P.get(c,c))
    sy=29+lower;cx=38+lean
    # The back leg folds under the body during break; the planted front knee lowers.
    lhip=(31+lean*.2,55+lower*.35);rhip=(43+lean*.2,55+lower*.35)
    limb(d,lhip,(26,66+knee*.35),8,'shade');limb(d,(26,66+knee*.35),(24+knee*.15,74),7,'plate')
    limb(d,rhip,(49+knee*.25,65+knee*.3),9,'shade');limb(d,(49+knee*.25,65+knee*.3),(48+knee*.5,74),7,'plate')
    rect((21,73,31+knee*.15,75),'metal');rect((45,73,56+knee*.5,75),'gold')
    poly([(cx-14,sy-2),(cx+11,sy-4),(cx+20,sy+17),(cx+24,73),(cx+5,69),(cx-14,75),(cx-24,68),(cx-19,sy+18)],'red')
    poly([(cx-13,sy+2),(cx+10,sy),(cx+14,sy+24),(cx+5,68),(cx-16,69),(cx-20,sy+23)],'shade')
    d.line([(int(cx-17),sy+8),(int(cx-17),68)],fill=P['gold'],width=2)
    poly([(cx-13,sy),(cx+9,sy),(cx+13,sy+13),(cx+8,sy+25),(cx-10,sy+28),(cx-15,sy+15)],'shade')
    poly([(cx-6,sy+3),(cx+2,sy),(cx+8,sy+7),(cx+4,sy+20),(cx-2,sy+25),(cx-10,sy+16)],'plate')
    rect((cx-2,sy+7,cx+1,sy+20),'gold');rect((cx-10,sy+23,cx+8,sy+25),'gold')
    poly([(cx-18,sy),(cx-11,sy-4),(cx-6,sy+2),(cx-11,sy+9),(cx-20,sy+9),(cx-23,sy+5)],'gold')
    poly([(cx+7,sy-1),(cx+14,sy-3),(cx+21,sy+4),(cx+17,sy+11),(cx+7,sy+9),(cx+3,sy+4)],'gold')
    # Head tilt is rebuilt from a slanted helm and crown polygon, not rotated art.
    x=cx-1;y=17+lower+(-1 if state=='parry_recoil' and f in (1,2) else 0)
    tilt=-3 if state=='parry_recoil' and f in (1,2) else (2 if state=='guard_break' else 0)
    poly([(x-8+tilt,y-5),(x+5+tilt,y-6),(x+11,y+2),(x+8,y+13),(x,y+18),(x-9,y+11),(x-12,y+3)],'plate')
    poly([(x-5+tilt,y-3),(x+4+tilt,y-3),(x+7,y+3),(x+4,y+12),(x-2,y+14),(x-7,y+8)],'skin')
    rect((x-1+tilt,y+1,x+1+tilt,y+9),'ink');rect((x-1+tilt,y+1,x+1+tilt,y+2),'white')
    poly([(x-9+tilt,y-1),(x-15+tilt,y-7),(x-16+tilt,y-15),(x-11+tilt,y-12),(x-10+tilt,y-7),(x-5+tilt,y-5),(x-2+tilt,y-9),(x+1+tilt,y-5),(x+8+tilt,y-6),(x+14+tilt,y-15),(x+17+tilt,y-13),(x+14+tilt,y-4),(x+8+tilt,y+1)],'gold')
    # Halberd hilt, hands and offset blade describe deflection away from the clash.
    hand=(cx+15-max(0,knee)*.1,sy+14)
    elbow=(cx+18,sy+10) if state=='parry_recoil' else (cx+15,sy+18)
    limb(d,(cx+13,sy+4),elbow,7,'plate');limb(d,elbow,hand,6,'shade')
    a=math.radians(angle);u=(math.cos(a),math.sin(a));shaft0=(hand[0]-u[0]*19,hand[1]-u[1]*19);tip=(hand[0]+u[0]*34,hand[1]+u[1]*34)
    d.line([ip(shaft0),ip(tip)],fill=P['ink'],width=5);d.line([ip(shaft0),ip(tip)],fill=P['gold'],width=3)
    nx,ny=-u[1],u[0]
    poly([(tip[0]+nx*5,tip[1]+ny*5),(tip[0]+u[0]*6,tip[1]+u[1]*6),(tip[0]-nx*7,tip[1]-ny*7),(tip[0]-u[0]*4,tip[1]-u[1]*4)],'metal')
    rect((hand[0]-2,hand[1]-2,hand[0]+2,hand[1]+2),'gold')
    return im

def gradient_line(d,points,width=2,shift=0):
    for i in range(1,len(points)):
        color=FLOW[(int((i-1)*len(FLOW)/max(1,len(points)-1))+shift)%len(FLOW)]
        d.line([ip(points[i-1]),ip(points[i])],fill=color,width=width)

def effect(kind,f):
    size={'blade_parry':80,'projectile_parry':40,'guard_break':96}[kind];im=Image.new('RGBA',(size,size));d=ImageDraw.Draw(im);c=size//2
    white=P['white'];gold='#ffce73';orange='#f29b4b'
    if f==0:
        arm=9 if kind=='blade_parry' else (5 if kind=='projectile_parry' else 12)
        d.polygon([(c-2,c-2),(c,c-arm),(c+2,c-2),(c+arm,c),(c+2,c+2),(c,c+arm),(c-2,c+2),(c-arm,c)],fill=white)
    # The orange core is local and short. Peripheral color never fills this contact.
    if f<3:
        r=3+f;d.line((c-r,c+2,c+r,c-2),fill=gold,width=2);d.line((c-1,c-r,c+1,c+r),fill=orange,width=1)
    if kind=='blade_parry':
        radius=[14,19,24,29,32,34][f]
        pts=[]
        for i in range(17):
            a=-1.2+2.4*i/16+.12*f;pts.append((c+math.cos(a)*radius,c+math.sin(a)*radius))
        gradient_line(d,pts,2 if f<3 else 1,shift=f)
        # A second, shorter blade flow band sweeps toward the contact direction.
        pts2=[(c-14+i*3,c+8-i+f%2) for i in range(10)]
        gradient_line(d,pts2,1,shift=f+2)
    elif kind=='projectile_parry':
        radius=[6,9,12,14,16,17][f]
        pts=[(c+math.cos(-1.0+i*math.tau/12)*radius,c+math.sin(-1.0+i*math.tau/12)*radius) for i in range(13)]
        gradient_line(d,pts,1,shift=f)
        if f<3:d.polygon([(c+4,c-2),(c+8,c),(c+4,c+2)],fill=gold)
    else:
        radius=[10,18,25,32,39,43][f]
        # Broken ring segments leave the kneeling body visible through the center.
        for k in range(6):
            pts=[]
            for i in range(5):
                a=k*math.tau/6+.1+i*.105;pts.append((c+math.cos(a)*radius,c+math.sin(a)*radius*.8))
            gradient_line(d,pts,2 if f<3 else 1,shift=k+f)
        for k in range(8):
            a=k*math.tau/8+.2;r=radius+2;x=round(c+math.cos(a)*r);y=round(c+math.sin(a)*r*.8)
            d.rectangle((x,y,x+2,y+1),fill=gold if k%2 else orange)
    return im

def main():
    OUT.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True);report={}
    for kind,states,size,anchor in [('hero',list(HERO),64,(28,58)),('boss',list(BOSS),80,(40,76))]:
        atlas=Image.new('RGBA',(size*4,size*3));frames=[]
        for row,state in enumerate(states):
            for f in range(4):
                image=hero(state,f) if kind=='hero' else boss(state,f);frames.append(image);atlas.alpha_composite(image,(f*size,row*size))
        atlas.save(OUT/f'{kind}_parry.png');flash=Image.new('RGBA',atlas.size,'#e8fff0');flash.putalpha(atlas.getchannel('A'));flash.save(OUT/f'{kind}_flash.png')
        report[kind]={'canvas':[size,size],'anchor':list(anchor),'states':{name:row for row,name in enumerate(states)},'frames_per_state':4,'unique_frames':len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames})}
        sheet=Image.new('RGB',(size*4*3+120,size*3*3+35),'#0c1025');sd=ImageDraw.Draw(sheet)
        for row,state in enumerate(states):
            sd.text((4,43+row*size*3),state,fill='#e9bb68')
            for f in range(4):
                im=frames[row*4+f].resize((size*3,size*3),Image.Resampling.NEAREST);sheet.paste(im,(120+f*size*3,30+row*size*3),im)
        sheet.save(ART/f'parry-{kind}-contact.png')
    for kind,size in [('blade_parry',80),('projectile_parry',40),('guard_break',96)]:
        strip=Image.new('RGBA',(size*6,size))
        for f in range(6):strip.alpha_composite(effect(kind,f),(f*size,0))
        strip.save(OUT/f'{kind}.png');report[kind]={'canvas':[size,size],'frames':6,'white_core_frames':1}
    report.update({'license':'MIT','source':'Original integer-grid poses and contact effects in tools/generate_parry_frames.py. No video pixels.','flow_palette':FLOW,'timing_note':'Actor pose progress is bound to real parry/reaction stages. Contact effects use short real-time lifetimes; no audio or clock writes.'})
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    effects=Image.new('RGB',(96*6*2+105,96*3*2+35),'#0c1025');ed=ImageDraw.Draw(effects)
    for row,(kind,size) in enumerate([('blade_parry',80),('projectile_parry',40),('guard_break',96)]):
        ed.text((3,45+row*192),kind,fill='#e9bb68')
        for f in range(6):
            im=effect(kind,f).resize((size*2,size*2),Image.Resampling.NEAREST);effects.paste(im,(105+f*192,30+row*192),im)
    effects.save(ART/'parry-gradient-contact.png')
    study=Image.new('RGB',(256*3,176),'#101323');sd=ImageDraw.Draw(study)
    labels=['RAISE / MEET','BLADE RECOIL','POSTURE BREAK']
    for i in range(3):
        ox=i*256
        sd.rectangle((ox,139,ox+255,175),fill='#24354e');sd.line((ox,138,ox+255,138),fill='#7a98ae')
        sd.text((ox+8,9),'STATIC POSE: '+labels[i],fill='#d0a65b')
        hstate,hf=[('parry_ready',2),('parry_recoil',2),('parry_recover',1)][i]
        bstate,bf=[('parry_recoil',0),('parry_recoil',2),('guard_break',3)][i]
        hi=hero(hstate,hf);bi=boss(bstate,bf).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        study.paste(bi,(ox+125-40,138-76),bi);study.paste(hi,(ox+80-28,138-58),hi)
        if i>0:
            fx=effect('blade_parry' if i==1 else 'guard_break',0 if i==1 else 2)
            study.paste(fx,(ox+105-fx.width//2,115-fx.height//2),fx)
        sd.line((ox+255,0,ox+255,175),fill='#39475e')
    study.resize((1536,352),Image.Resampling.NEAREST).save(ART/'parry-static-keyframes.png')
    print('Generated 24 original actor reaction frames and 18 contact-effect frames')
if __name__=='__main__':main()
