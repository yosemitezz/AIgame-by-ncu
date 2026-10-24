"""Original broken-crown dungeon hero. Native integer pixels; no 3D or external assets.
Reuses our authored joint/weapon pose tables, redraws helmet, armor, cape and climb limbs.
Run from any cwd; all outputs stay in presentation/dungeon_frames.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math, json, hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'presentation/dungeon_frames'; EVIDENCE=OUT
S=64; ANCHOR=(28,58)
P={'ink':'#111323','shade':'#273146','cloak':'#493c72','fold':'#775c9c','edge':'#c58ea8','plate':'#b8c5c4','metal':'#e0eadb','white':'#fff3d2','gold':'#cb9861','skin':'#9fa9b6','cyan':'#72f0eb','coral':'#e5797b','darkgold':'#725049'}
STATES=[('idle',4),('run',6),('jump',4),('fall',4),('dash',4),('parry',4),('hurt',4),('dead',4)]
for combo in range(1,4):
    for phase in ('windup','attack','recover'): STATES.append((f'cut_{combo}_{phase}',4))

PARRY={'parry_ready':[(34,37,-35,0,1),(37,35,-55,-1,1),(38,35,-66,-1,2),(37,35,-70,-1,2)],
'parry_recoil':[(38,35,-66,-1,2),(33,31,-100,-3,3),(30,30,-119,-5,4),(31,32,-104,-3,3)],
'parry_recover':[(32,34,-92,-2,3),(34,35,-70,-1,2),(35,35,-40,0,1),(34,33,15,0,0)]}

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
    if state=='parry':state='parry_ready'
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
    elif state in PARRY:
        hx,hy,angle,lean,crouch=PARRY[state][f];hand=(hx,hy);elbow=(28+lean+4,29+crouch+2)
        trail=min(2+abs(lean)*2,10);left_foot=(19,57);right_foot=(36,57)
        left_knee=(21-lean*.25,49+crouch*.4);right_knee=(34+lean*.25,48+crouch*.4)
    elif state in ('climb','climb_idle'):
        # Six articulated rungs: hands exchange load while the opposite knee lifts.
        climb=[((38,18),(20,30),(35,45),(37,55),(21,40),(18,48)),
               ((38,16),(21,25),(37,42),(39,51),(21,43),(18,52)),
               ((37,20),(21,16),(37,39),(39,47),(22,46),(21,56)),
               ((37,29),(21,15),(36,40),(38,48),(21,46),(20,56)),
               ((38,26),(20,19),(35,44),(37,53),(20,43),(18,53)),
               ((38,22),(20,27),(34,46),(36,56),(20,40),(17,49))]
        hand,far_hand,right_knee,right_foot,left_knee,left_foot=climb[f]
        if state=='climb_idle':
            hand=(38,19+(f//3));far_hand=(20,27-(f//3));right_knee=(35,44);right_foot=(37,54)
            left_knee=(21,42+(f%3)//2);left_foot=(18,51+(f%3)//2)
        crouch=[0,-1,-2,-1,0,1][f] if state=='climb' else f%2
        lean=0;trail=[1,2,3,2,1,0][f];elbow=(35,26 if hand[1]<25 else 32)
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
    # Overlapping ivory armor, copper seams and a dark central enamel keel.
    poly([(sx-7,sy-3),(sx+4,sy-3),(sx+8,sy+5),(hip[0]+6,hip[1]+2),(hip[0]-6,hip[1]+2),(sx-8,sy+6)],'plate')
    poly([(sx-3,sy-2),(sx+3,sy-1),(sx+5,sy+6),(hip[0]+2,hip[1]-1),(hip[0]-2,hip[1]-1),(sx-5,sy+5)],'shade')
    poly([(sx-7,sy+1),(sx-3,sy+2),(sx-4,sy+8),(sx-7,sy+6)],'metal')
    d.line([point((sx-5,sy+8)),point((sx+4,sy+8))],fill=P['gold'])
    d.line([point((sx-4,sy+10)),point((sx+3,sy+10))],fill=P['ink'])
    rect((sx,sy+1,sx+1,sy+5),'cyan');rect((sx-5,sy,sx-5,sy),'white');rect((sx+4,sy+1,sx+4,sy+1),'white')
    poly([(sx+1,sy-3),(sx+7,sy-4),(sx+10,sy),(sx+8,sy+4),(sx+2,sy+3)],'gold')
    d.line([point((sx+3,sy-2)),point((sx+7,sy-2))],fill=P['white'])
    rect((hip[0]-6,hip[1]-2,hip[0]+5,hip[1]),'gold');rect((hip[0],hip[1]-3,hip[0]+2,hip[1]+1),'white')
    poly([(hip[0]-5,hip[1]+1),(hip[0],hip[1]+2),(hip[0]-3,hip[1]+7),(hip[0]-7,hip[1]+5)],'plate')
    # A torn split cape, one fine copper hem and an original three-pixel clasp.
    d.line([point((sx-10-trail,sy+16)),point((sx-8,sy+20))],fill=P['gold'])
    rect((sx-6,sy-3,sx-4,sy-2),'gold');rect((sx-5,sy-4,sx-5,sy-1),'white')
    # Broken crown helm: stepped rear prong, missing front tine, bright asymmetric faceplate.
    hx=sx+1;hy=sy-13
    poly([(hx-9,hy-4),(hx-6,hy-8),(hx+3,hy-8),(hx+8,hy-3),(hx+10,hy+4),(hx+6,hy+9),(hx-5,hy+8),(hx-10,hy+3)],'shade')
    poly([(hx-7,hy-5),(hx-8,hy-13),(hx-5,hy-12),(hx-3,hy-6),(hx,hy-8),(hx+2,hy-12),(hx+5,hy-10),(hx+4,hy-6)],'gold')
    rect((hx-7,hy-12,hx-6,hy-9),'white');rect((hx+2,hy-11,hx+3,hy-10),'metal')
    poly([(hx-4,hy-5),(hx+4,hy-5),(hx+8,hy-1),(hx+8,hy+4),(hx+3,hy+8),(hx-3,hy+6),(hx-5,hy+1)],'plate')
    poly([(hx+2,hy-4),(hx+6,hy-2),(hx+6,hy+3),(hx+2,hy+5),(hx,hy+2)],'metal')
    d.line([point((hx-3,hy)),point((hx+7,hy))],fill=P['ink'],width=2)
    rect((hx+1,hy,hx+6,hy),'cyan');rect((hx+4,hy,hx+5,hy),'white')
    d.line([point((hx-2,hy+4)),point((hx+1,hy+7))],fill=P['gold'])
    rect((hx-4,hy-3,hx-4,hy-3),'white')
    poly([(hx-7,hy+5),(hx+1,hy+8),(hx-1,hy+12),(hx-10,hy+9),(hx-15-trail//2,hy+10),(hx-13,hy+6)],'cloak')
    d.line([point((hx-8,hy+7)),point((hx-2,hy+9))],fill=P['edge'])
    # Rear arm on heavy windup / parry supports two-hand poses.
    if combo==3 or state in PARRY:
        limb((sx-4,sy+1),(sx+1,sy+7),5,'plate');limb((sx+1,sy+7),(hand[0]-3,hand[1]+1),4,'shade')
    if state in ('climb','climb_idle'):
        limb((sx-4,sy),(sx-7,sy-1),5,'plate');limb((sx-7,sy-1),far_hand,4,'shade')
        rect((far_hand[0]-2,far_hand[1]-2,far_hand[0]+2,far_hand[1]+1),'gold')
        rect((far_hand[0]-1,far_hand[1]-3,far_hand[0]+2,far_hand[1]-2),'metal')
    limb((sx+3,sy),elbow,6,'plate');limb(elbow,hand,5,'shade')
    hx2,hy2=hand;rect((hx2-2,hy2-2,hx2+2,hy2+2),'gold');rect((hx2-1,hy2-2,hx2+1,hy2),'metal')
    if state not in ('climb','climb_idle'):
        # A real pixel sword: outlined blade, inner steel, single bright leading edge.
        a=math.radians(angle);u=(math.cos(a),math.sin(a));n=(-u[1],u[0]);length=22 if combo!=3 else 23
        tip=(hx2+u[0]*length,hy2+u[1]*length);base=(hx2+u[0]*3,hy2+u[1]*3)
        poly([(base[0]+n[0]*2,base[1]+n[1]*2),(tip[0]-u[0]*3+n[0]*1,tip[1]-u[1]*3+n[1]*1),tip,(tip[0]-u[0]*3-n[0]*1,tip[1]-u[1]*3-n[1]*1),(base[0]-n[0]*2,base[1]-n[1]*2)],'metal')
        d.line([point((base[0]+n[0],base[1]+n[1])),point(tip)],fill=P['white'],width=1)
        d.line([point((hx2+n[0]*4,hy2+n[1]*4)),point((hx2-n[0]*4,hy2-n[1]*4))],fill=P['gold'],width=2)
        if state=='parry':
            poly([(42,22),(44,25),(42,28),(40,25)],'cyan', 'edge')
    else:
        poly([(sx-10,sy+1),(sx-8,sy+2),(sx-13,sy+20),(sx-16,sy+24),(sx-15,sy+17)],'shade')
        d.line([point((sx-10,sy+2)),point((sx-15,sy+20))],fill=P['gold'])
    return im

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    states=STATES+[('climb',6),('climb_idle',6)]
    frames=[];mapping={}
    for state,count in states:
        mapping[state]={'start':len(frames),'count':count}
        for f in range(count):frames.append((state,f,hero(state,f)))
    cols=8;rows=math.ceil(len(frames)/cols);atlas=Image.new('RGBA',(cols*S,rows*S))
    for i,(_,_,im) in enumerate(frames):atlas.alpha_composite(im,((i%cols)*S,(i//cols)*S))
    atlas.save(OUT/'hero_atlas.png')
    for name,color in [('hero_silhouette.png','#72ece2'),('hero_flash.png','#e8fff0')]:
        tint=Image.new('RGBA',atlas.size,color);tint.putalpha(atlas.getchannel('A'));tint.save(OUT/name)
    parry=Image.new('RGBA',(S*4,S*3))
    for row,state in enumerate(PARRY):
        for f in range(4):parry.alpha_composite(hero(state,f),(f*S,row*S))
    parry.save(OUT/'hero_parry.png')
    flash=Image.new('RGBA',parry.size,'#e8fff0');flash.putalpha(parry.getchannel('A'));flash.save(OUT/'hero_parry_flash.png')
    old=json.loads((ROOT/'presentation/feel_frames/manifest.json').read_text())
    info={'version':2,'source':'Original integer-grid broken-crown armor family in tools/generate_dungeon_hero.py. Reuses our previous authored pose/weapon tables; no outside art or 3D.',
      'license':'MIT','hero':{'canvas':[64,64],'anchor':list(ANCHOR),'columns':cols,'states':mapping,'total_frames':len(frames),'palette_rgb':list(P.values()),'weapon_tips':old['hero']['weapon_tips']},
      'parry':{'states':list(PARRY),'count':4,'canvas':[64,64],'anchor':list(ANCHOR)},'constraints':{'anti_alias':False,'whole_frame_transforms':False,'3d_sources':False}}
    (OUT/'manifest.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
    contact_states=['idle','run','climb','climb_idle','cut_1_attack','cut_2_attack','cut_3_attack','parry_recoil']
    contact=Image.new('RGB',(100+6*128,24+len(contact_states)*128),'#111323');d=ImageDraw.Draw(contact)
    for row,state in enumerate(contact_states):
        d.text((4,34+row*128),state,fill=P['gold']);n=6 if state in ['run','climb','climb_idle'] else 4
        for f in range(n):
            im=hero(state,f).resize((128,128),Image.Resampling.NEAREST);contact.paste(im,(100+f*128,24+row*128),im)
    contact.save(OUT/'dungeon-hero-contact.png')
    comparison=Image.new('RGB',(640,180),'#111323');d=ImageDraw.Draw(comparison)
    before=Image.open(ROOT/'presentation/feel_frames/hero_atlas.png').crop((0,0,64,64))
    for i,(label,im) in enumerate([('PREVIOUS',before),('BROKEN CROWN',hero('idle',0)),('CLIMB A',hero('climb',0)),('CLIMB B',hero('climb',3))]):
        d.text((i*160+8,5),label,fill=P['gold']);big=im.resize((128,128),Image.Resampling.NEAREST);comparison.paste(big,(i*160+8,30),big)
    comparison.save(OUT/'dungeon-hero-comparison.png')
    report={'frames':len(frames),'unique_frames':len({hashlib.sha256(im.tobytes()).hexdigest() for _,_,im in frames}),'climb_unique':len({hero('climb',f).tobytes() for f in range(6)}),'climb_idle_unique':len({hero('climb_idle',f).tobytes() for f in range(6)}),'colors':len({pixel[:3] for pixel in atlas.get_flattened_data() if pixel[3]}),'weapon_tip_table_preserved':info['hero']['weapon_tips']==old['hero']['weapon_tips'],'parry_frames':12,'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}}
    (OUT/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in report.items() if k!='sha256'}))
if __name__=='__main__':main()
