"""Integer-grid pixel animation authored for Bellkeep's combat revision.
No rendered model, interpolation, external sheet, or generated raster is used.
Every body, limb, cloak and blade is drawn from pose data at native resolution.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math, json, hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'presentation/feel_frames'; EVIDENCE=ROOT/'artifacts'
S=64; ANCHOR=(28,58)
P={'ink':'#101626','shade':'#24354e','cloak':'#326e89','fold':'#4a98aa','edge':'#8bc6c9','plate':'#7a98ae','metal':'#b5d6da','white':'#eff6d8','gold':'#d0a65b','skin':'#c8bf93','cyan':'#71ece1','coral':'#e5797b','darkgold':'#6e624b'}
STATES=[('idle',4),('run',6),('jump',4),('fall',4),('dash',4),('parry',4),('hurt',4),('dead',4)]
for combo in range(1,4):
    for phase in ('windup','attack','recover'): STATES.append((f'cut_{combo}_{phase}',4))

# hand x/y, blade angle; each entry has a deliberately authored active direction.
SWORDS={
1:{'windup':[(35,26,-80),(31,23,-110),(26,21,-135),(23,21,-145)],
   'attack':[(33,23,-65),(38,28,-20),(38,33,20),(34,36,63)],
   'recover':[(33,35,66),(32,34,45),(33,32,24),(34,31,10)]},
2:{'windup':[(34,33,35),(32,35,60),(30,35,75),(29,35,90)],
   'attack':[(36,35,38),(39,30,-8),(35,24,-56),(29,22,-110)],
   'recover':[(30,23,-95),(31,25,-65),(33,28,-30),(34,31,10)]},
3:{'windup':[(30,24,-100),(26,23,-125),(24,22,-142),(23,22,-147)],
   'attack':[(32,24,-62),(38,28,-10),(39,32,1),(39,33,8)],
   'recover':[(37,34,15),(35,34,25),(34,33,22),(34,31,10)]}}

def point(p): return (round(p[0]),round(p[1]))
def hero(state,f):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im)
    def poly(ps,key,out='ink'): d.polygon([point(p) for p in ps],fill=P.get(key,key),outline=P.get(out,out))
    def rect(box,key):d.rectangle(tuple(round(v) for v in box),fill=P.get(key,key))
    def limb(a,b,width,key):
        ax,ay=a;bx,by=b;dx=bx-ax;dy=by-ay;l=max(1,math.hypot(dx,dy));nx=-dy/l;ny=dx/l
        ps=[(ax+nx*width/2,ay+ny*width/2),(bx+nx*width/2,by+ny*width/2),(bx-nx*width/2,by-ny*width/2),(ax-nx*width/2,ay-ny*width/2)]
        poly(ps,key)
    combo=0;phase='';shift=0;lean=0;crouch=0;trail=0
    hand=(34,31);angle=10;elbow=(33,31)
    left_foot=(21,57);right_foot=(34,57);left_knee=(22,48);right_knee=(32,48)
    if state.startswith('cut_'):
        _,cs,phase=state.split('_');combo=int(cs)
        hand=tuple(SWORDS[combo][phase][f][:2]);angle=SWORDS[combo][phase][f][2]
        if phase=='windup':lean=[0,-1,-2,-2][f];crouch=[0,1,2,2][f];shift=-1
        elif phase=='attack':lean=[0,2,3,2][f];shift=[0,1,2,2][f];trail=[1,5,7,5][f];crouch=[1,1,0,1][f]
        else:lean=[2,1,1,0][f];shift=[2,1,0,0][f];trail=3-f
        if combo==2:lean-=1;crouch=max(0,crouch-1)
        if combo==3:
            crouch+=2 if phase=='windup' else 1
            if phase=='attack':lean+=2;shift+=1
        left_foot=(17-shift,57);right_foot=(36+shift,57)
        left_knee=(22-shift,49+crouch);right_knee=(31+shift,48+crouch)
        elbow=((hand[0]+29+lean)/2,30+crouch+(3 if phase=='recover' else -2))
    elif state=='run':
        lean=3;shift=1;crouch=[0,1,0,0,1,0][f];trail=[4,6,5,3,5,6][f]
        feet=[((16,56),(37,57),(21,46),(33,48)),((24,57),(33,53),(21,50),(35,46)),((33,56),(25,54),(28,50),(26,46)),((37,57),(16,56),(33,48),(21,46)),((33,53),(24,57),(35,46),(21,50)),((25,54),(33,56),(26,46),(28,50))][f]
        left_foot,right_foot,left_knee,right_knee=feet
        hand=[(32,29),(31,28),(29,28),(30,29),(33,30),(34,30)][f];angle=40
        elbow=(29,33)
    elif state=='idle':
        crouch=[0,0,1,0][f];trail=[0,1,2,1][f]
        hand=(34,31+crouch);angle=18
    elif state in ('jump','fall'):
        lean=2 if state=='jump' else 0;trail=5;crouch=-1 if state=='jump' else 1
        left_knee=(23,45);left_foot=(17,50+f%2);right_knee=(34,43);right_foot=(33,52-f%2)
        hand=(36,27 if state=='jump' else 31);angle=-20 if state=='jump' else 25
        elbow=(33,28)
    elif state=='dash':
        lean=[4,6,7,5][f];trail=[9,12,14,10][f];crouch=[3,5,4,3][f]
        left_knee=(19-f%2,48);left_foot=(12-f%2,52+f%2);right_knee=(34+f%2,49);right_foot=(40+f%3,55)
        hand=(37+f%2,34+f%2);angle=[-3,0,4,1][f];elbow=(33+f%2,35+f%2)
    elif state=='parry':
        lean=-1;crouch=[1,0,0,1][f]
        hand=(37,28);angle=-85;elbow=(31,31)
    elif state=='hurt':
        lean=-4;shift=-2;crouch=2;trail=4
        hand=(31,35);angle=55;elbow=(28,34)
        right_foot=(32,57);left_foot=(16,54)
    elif state=='dead':
        # Four hand-drawn collapsing silhouettes; no whole-frame rotation.
        poly([(9,53),(15,49),(33,51),(44,55),(44,58),(14,58)],'cloak')
        poly([(15,48),(22,46),(27,49),(25,54),(16,54)],'shade')
        rect((21,48,26,51),'skin');rect((10,55,18,57),'plate')
        limb((31,55),(42+f,57),5,'shade');limb((35,52),(49,54),3,'metal')
        return im
    hip=(27+shift,42+crouch);shoulder=(28+shift+lean,29+crouch)
    # Far leg and articulated steel boot.
    limb((hip[0]-3,hip[1]),left_knee,6,'shade');limb(left_knee,left_foot,5,'shade')
    lx,ly=left_foot;poly([(lx-3,ly-3),(lx+2,ly-3),(lx+5,ly),(lx+5,ly+1),(lx-3,ly+1)],'plate');rect((lx-2,ly-1,lx+4,ly),'metal')
    # Cape has a fixed shoulder attachment but different cloth folds in every phase.
    sx,sy=shoulder
    cape=[(sx-4,sy-7),(sx-10,sy-1),(sx-11-trail,sy+9),(sx-17-trail,sy+20-crouch),(sx-8,sy+21),(sx-5,sy+16),(sx+1,sy+11)]
    poly(cape,'cloak');poly([(sx-8,sy-1),(sx-7-trail*.4,sy+8),(sx-13-trail,sy+17),(sx-5,sy+14)],'fold')
    d.line([point((sx-10-trail,sy+16)),point((sx-15-trail,sy+19-crouch)),point((sx-8,sy+20))],fill=P['edge'],width=1)
    # Near thigh and shinguard expose a two-sided stance instead of a sliding block.
    limb((hip[0]+3,hip[1]),right_knee,7,'shade');limb(right_knee,right_foot,6,'plate')
    rx,ry=right_foot;poly([(rx-3,ry-4),(rx+2,ry-3),(rx+5,ry),(rx+5,ry+1),(rx-3,ry+1)],'shade');rect((rx-2,ry-2,rx+4,ry-1),'metal')
    # Cuirass and a separate hip plate shift with chest commitment.
    poly([(sx-6,sy-3),(sx+4,sy-2),(sx+7,sy+7),(hip[0]+6,hip[1]+2),(hip[0]-6,hip[1]+2),(sx-7,sy+7)],'shade')
    poly([(sx-3,sy),(sx+4,sy),(sx+4,sy+7),(hip[0]+3,hip[1]-2),(hip[0]-1,hip[1]-1),(sx-4,sy+6)],'cloak')
    rect((sx-2,sy+1,sx,sy+6),'fold');rect((hip[0]-6,hip[1]-2,hip[0]+5,hip[1]),'gold');rect((hip[0]+1,hip[1]-3,hip[0]+3,hip[1]+1),'white')
    poly([(hip[0]-5,hip[1]+1),(hip[0],hip[1]+2),(hip[0]-3,hip[1]+7),(hip[0]-7,hip[1]+5)],'cloak')
    # Hood: pointed rear, asymmetric face profile, narrow eye and lower scarf.
    hx=sx+1;hy=sy-13
    poly([(hx-8,hy-3),(hx-4,hy-8),(hx+4,hy-7),(hx+9,hy-2),(hx+10,hy+5),(hx+6,hy+10),(hx-5,hy+8),(hx-10,hy+3)],'shade')
    poly([(hx-3,hy-5),(hx+4,hy-5),(hx+7,hy-1),(hx+7,hy+5),(hx+3,hy+8),(hx-2,hy+5),(hx-4,hy+1)],'skin')
    rect((hx+4,hy-1,hx+8,hy+1),'ink');rect((hx+5,hy-1,hx+7,hy-1),'cyan')
    d.line([point((hx-7,hy-2)),point((hx-5,hy-5)),point((hx,hy-6))],fill=P['fold'],width=1)
    poly([(hx-7,hy+5),(hx+1,hy+8),(hx-1,hy+12),(hx-10,hy+9),(hx-15-trail//2,hy+10),(hx-13,hy+6)],'fold')
    d.line([point((hx-8,hy+7)),point((hx-2,hy+9))],fill=P['edge'],width=1)
    # Rear arm on heavy windup / parry supports two-hand poses.
    if combo==3 or state=='parry':
        limb((sx-4,sy+1),(sx+1,sy+7),5,'plate');limb((sx+1,sy+7),(hand[0]-3,hand[1]+1),4,'shade')
    limb((sx+3,sy),elbow,6,'plate');limb(elbow,hand,5,'shade')
    hx2,hy2=hand;rect((hx2-2,hy2-2,hx2+2,hy2+2),'gold');rect((hx2-1,hy2-2,hx2+1,hy2),'metal')
    # A real pixel sword: outlined blade, inner steel, single bright leading edge.
    a=math.radians(angle);u=(math.cos(a),math.sin(a));n=(-u[1],u[0]);length=22 if combo!=3 else 23
    tip=(hx2+u[0]*length,hy2+u[1]*length);base=(hx2+u[0]*3,hy2+u[1]*3)
    poly([(base[0]+n[0]*2,base[1]+n[1]*2),(tip[0]-u[0]*3+n[0]*1,tip[1]-u[1]*3+n[1]*1),tip,(tip[0]-u[0]*3-n[0]*1,tip[1]-u[1]*3-n[1]*1),(base[0]-n[0]*2,base[1]-n[1]*2)],'metal')
    d.line([point((base[0]+n[0],base[1]+n[1])),point(tip)],fill=P['white'],width=1)
    d.line([point((hx2+n[0]*4,hy2+n[1]*4)),point((hx2-n[0]*4,hy2-n[1]*4))],fill=P['gold'],width=2)
    if state=='parry':
        poly([(42,22),(44,25),(42,28),(40,25)],'cyan', 'edge')
    return im

def make_arc_points(offset,size,rotation=0):
    # Adapted from CodingQuests/godot-hitbox-hurtbox WeaponController.gd
    # commit 7ccc10925a07960772d83db970d56fef875a983d, MIT (2026 CodingQuests).
    # License: third_party/codingquests/LICENSE.
    # Same outer/inner radius and 10-step crescent algorithm; round to pixel grid.
    r_out=offset+size[0]*.5;r_in=r_out*.45
    span=max(.4,min(1,size[1]/40))*math.radians(130);steps=10
    outer=[(math.cos(-span*.5+span*i/steps+rotation)*r_out,math.sin(-span*.5+span*i/steps+rotation)*r_out) for i in range(steps+1)]
    inner=[(math.cos(span*.5-span*i/steps+rotation)*r_in,math.sin(span*.5-span*i/steps+rotation)*r_in) for i in range(steps+1)]
    return outer+inner,outer

def arc(combo,f):
    im=Image.new('RGBA',(96,96));d=ImageDraw.Draw(im)
    if combo==3:
        fronts=[55,71,84,89,91];length=[12,31,48,35,12];end=fronts[f];start=end-length[f]
        y=48+(f%2)
        d.polygon([(start,y-1),(end-8,y-5),(end,y),(end-8,y+5),(start,y+1)],fill=P['fold'])
        d.polygon([(start+4,y),(end-8,y-2),(end-2,y),(end-8,y+2)],fill=P['white'])
        for k in range(3): d.line((max(6,start-5-k*8),y-8+k*8,start+3,y-8+k*8),fill=P['edge'],width=1)
        return im
    # Apply the ported crescent geometry to successive authored sweep angles.
    rotate=[-.9,-.5,.05,.6,1.0][f];size_y=[16,28,40,28,16][f]
    polygon,edge=make_arc_points(8,(48,size_y),rotate)
    flip=-1 if combo==2 else 1
    points=[(round(42+x),round(48+y*flip)) for x,y in polygon]
    # Low-value body plus bright leading edge keeps gold projectiles readable.
    d.polygon(points,fill='#294e63')
    line=[(round(42+x),round(48+y*flip)) for x,y in edge]
    d.line(line,fill=P['fold'],width=5 if f<3 else 3)
    d.line(line,fill=P['white'],width=2 if f<3 else 1)
    if f>=2:
        for k in range(3):
            x,y=line[-1-k*2];d.rectangle((x+3,y,x+4,y+2),fill=P['edge'])
    return im

def impact(kind,f):
    size=80 if kind=='parry' else 48;im=Image.new('RGBA',(size,size));d=ImageDraw.Draw(im);c=size//2
    col=P['cyan'] if kind=='parry' else P['gold'];bright=P['white'];radius=[5,13,21,27,32][f] if kind=='parry' else [4,9,14,19,21][f]
    if kind=='parry':
        d.line([(c,c-radius),(c+radius,c),(c,c+radius),(c-radius,c),(c,c-radius)],fill=col,width=2 if f<3 else 1)
        if f<3:
            arm=[17,24,11][f];d.polygon([(c-2,c-2),(c,c-arm),(c+2,c-2),(c+arm,c),(c+2,c+2),(c,c+arm),(c-2,c+2),(c-arm,c)],fill=bright)
        for x,y in [(c-radius,c),(c+radius,c),(c,c-radius),(c,c+radius)]:d.rectangle((x-1,y-1,x+1,y+1),fill=bright if f<2 else col)
    else:
        if f<2:
            d.polygon([(c-2,c-2),(c-8,c-11),(c+1,c-4),(c+11,c-7),(c+4,c+1),(c+8,c+10),(c-1,c+3),(c-11,c+7)],fill=bright)
        for k in range(6):
            a=k*math.pi/3+.2;start=radius*.55;end=radius+2
            d.line((round(c+math.cos(a)*start),round(c+math.sin(a)*start),round(c+math.cos(a)*end),round(c+math.sin(a)*end)),fill=col,width=2 if f<3 else 1)
    return im

def main():
    OUT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    count=sum(n for _,n in STATES);cols=8;rows=math.ceil(count/cols);atlas=Image.new('RGBA',(cols*S,rows*S));mapping={};index=0;frames=[]
    for state,n in STATES:
        mapping[state]={'start':index,'count':n}
        for f in range(n):
            frame=hero(state,f);frames.append((state,f,frame));atlas.alpha_composite(frame,((index%cols)*S,(index//cols)*S));index+=1
    atlas.save(OUT/'hero_atlas.png')
    for name,color in [('hero_silhouette.png','#63c5d2'),('hero_flash.png','#e8fff0')]:
        tint=Image.new('RGBA',atlas.size,color);tint.putalpha(atlas.getchannel('A'));tint.save(OUT/name)
    for combo in range(1,4):
        sheet=Image.new('RGBA',(96*5,96))
        for f in range(5):sheet.alpha_composite(arc(combo,f),(96*f,0))
        sheet.save(OUT/f'slash_{combo}.png')
    for kind in ('hit','parry'):
        size=80 if kind=='parry' else 48;sheet=Image.new('RGBA',(size*5,size))
        for f in range(5):sheet.alpha_composite(impact(kind,f),(size*f,0))
        sheet.save(OUT/f'{kind}.png')
    # Hit silhouettes for the existing original enemy/Boss atlases.
    for kind in ('sentry','elite','wisp','boss'):
        src=Image.open(ROOT/f'assets/art/placeholder_{kind}.png').convert('RGBA');fl=Image.new('RGBA',src.size,'#e8fff0');fl.putalpha(src.getchannel('A'));fl.save(OUT/f'{kind}_flash.png')
    info={'version':1,'source':'Original integer-grid pose and effect drawings in tools/generate_combat_frames.py','license':'MIT','hero':{'canvas':[64,64],'anchor':list(ANCHOR),'columns':cols,'states':mapping,'total_frames':count,'palette_rgb':list(P.values())},'vfx':{'slash_1':{'frame':[96,96],'count':5},'slash_2':{'frame':[96,96],'count':5},'slash_3':{'frame':[96,96],'count':5},'hit':{'frame':[48,48],'count':5},'parry':{'frame':[80,80],'count':5}},'constraints':{'anti_alias':False,'whole_frame_transforms':False,'3d_sources':False,'max_dash_ghosts':3,'max_effect_entries':64}}
    info['ported_geometry']={'repository':'https://github.com/CodingQuests/godot-hitbox-hurtbox','commit':'7ccc10925a07960772d83db970d56fef875a983d','source':'scripts/WeaponController.gd','functions':['make_arc_points','start_trail','update_trail','end_trail'],'license':'MIT','adaptation':'Rasterize rounded 10-step crescent at 5 authored sweep poses; actual blade tip sampling capped at 8, post-active fade 0.16 seconds.'}
    tips={}
    for combo in range(1,4):
        for phase in ('windup','attack','recover'):
            tips[f'cut_{combo}_{phase}']=[[round(x+math.cos(math.radians(angle))*(23 if combo==3 else 22)-ANCHOR[0]),round(y+math.sin(math.radians(angle))*(23 if combo==3 else 22)-ANCHOR[1])] for x,y,angle in SWORDS[combo][phase]]
    info['hero']['weapon_tips']=tips
    (OUT/'manifest.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
    # Show all twelve poses for each attack, grouped by the real gameplay phase.
    contact=Image.new('RGB',(64*12*2+120,64*3*2+42),'#0c1025');cd=ImageDraw.Draw(contact)
    for combo in range(1,4):
        cd.text((8,45+(combo-1)*128),f'CUT {combo}',fill='#d0a65b')
        for phase_i,phase in enumerate(('windup','attack','recover')):
            for f in range(4):
                frame=hero(f'cut_{combo}_{phase}',f).resize((128,128),Image.Resampling.NEAREST)
                contact.paste(frame,(120+(phase_i*4+f)*128,40+(combo-1)*128),frame)
    cd.text((120,10),'WINDUP 0..3                                      ACTIVE 0..3                                        RECOVER 0..3',fill='#8bc6c9')
    contact.save(EVIDENCE/'feel-combo-contact.png')
    motion=Image.new('RGB',(64*6*3+80,64*4*3+35),'#0c1025');md=ImageDraw.Draw(motion)
    for row,state in enumerate(('idle','run','dash','parry')):
        md.text((5,45+row*192),state,fill='#d0a65b')
        for f in range(6 if state=='run' else 4):
            frame=hero(state,f).resize((192,192),Image.Resampling.NEAREST);motion.paste(frame,(80+f*192,30+row*192),frame)
    motion.save(EVIDENCE/'feel-motion-contact.png')
    effects=Image.new('RGB',(96*5*2+90,96*5*2+30),'#0c1025');ed=ImageDraw.Draw(effects)
    for row,name in enumerate(('slash_1','slash_2','slash_3','hit','parry')):
        ed.text((3,45+row*192),name,fill='#d0a65b');src=Image.open(OUT/f'{name}.png').convert('RGBA');sz=src.height
        for f in range(5):
            frame=src.crop((f*sz,0,(f+1)*sz,sz)).resize((sz*2,sz*2),Image.Resampling.NEAREST);effects.paste(frame,(90+f*192,30+row*192),frame)
    effects.save(EVIDENCE/'feel-vfx-contact.png')
    # Native-scale before/after poses against the same dark playfield.
    cmp=Image.new('RGB',(480,210),'#101323');dd=ImageDraw.Draw(cmp)
    dd.text((12,9),'BEFORE: SINGLE GENERIC ATTACK',fill='#d0a65b');dd.text((252,9),'AFTER: WINDUP / ACTIVE / RECOVER',fill='#8bc6c9')
    old=Image.open(ROOT/'assets/art/placeholder_hero.png').convert('RGBA')
    for f in range(3):
        base=old.crop((f*40,5*48,(f+1)*40,6*48));cmp.paste(base,(20+f*63,73),base)
    for f,phase in enumerate(('windup','attack','recover')):
        frame=hero(f'cut_1_{phase}',1);cmp.paste(frame,(245+f*70,57),frame)
    cmp=cmp.resize((960,420),Image.Resampling.NEAREST);cmp.save(EVIDENCE/'feel-before-after.png')
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}
    (EVIDENCE/'feel-asset-report.json').write_text(json.dumps({'total_hero_frames':count,'unique_frame_hashes':len({hashlib.sha256(im.tobytes()).hexdigest() for _,_,im in frames}),'hero_rgb_colors':len({rgb[:3] for rgb in atlas.get_flattened_data() if rgb[3]}),'png_sha256':hashes},indent=2)+'\n',encoding='utf-8')
    print('Generated',count,'hero frames, 25 effect frames and contact comparisons')
if __name__=='__main__':main()
