"""Original articulated attack revision for our broken-crown pixel hero.
No external assets, 3D, whole-image rotation, resampling, or generated-art source.
Only preview sheets are enlarged, using exact nearest-neighbor duplication.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import hashlib, json, math
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'presentation' / 'hero_attack_frames'
SIZE = (128, 96)
ANCHOR = (48, 88)
P = {'ink':'#111323','shade':'#273146','cloak':'#493c72','fold':'#775c9c',
     'edge':'#c58ea8','plate':'#b8c5c4','metal':'#e0eadb','white':'#fff3d2',
     'gold':'#cb9861','skin':'#9fa9b6','cyan':'#72f0eb','coral':'#e5797b','darkgold':'#725049'}
# Every row is authored: hip, shoulder, hand, blade angle, rear foot, front foot,
# rear knee, front knee, cloth lag, torso width/twist, elbow counter-rotation.
def pose(hip, shoulder, hand, angle, rear, front, rk, fk, cloth, twist=0, elbow=(0,0)):
    return dict(hip=hip, shoulder=shoulder, hand=hand, angle=angle,
                rear_foot=rear, front_foot=front, rear_knee=rk, front_knee=fk,
                cloth=cloth, twist=twist, elbow_bias=elbow)
POSES = {
1: {
'windup': [
 pose((47,72),(49,59),(64,63),5,(37,87),(60,87),(40,79),(55,79),3,0,(-2,3)),
 pose((46,73),(46,61),(59,59),-28,(35,87),(61,85),(39,81),(55,77),5,-1,(-2,-1)),
 pose((45,74),(43,62),(51,52),-86,(33,87),(63,86),(38,82),(56,78),7,-2,(-3,-2)),
 pose((44,75),(41,63),(44,51),-126,(32,87),(64,87),(37,83),(56,79),9,-2,(-4,-2)),
],
'attack': [
 pose((47,74),(48,62),(56,55),-78,(32,87),(65,85),(38,82),(57,77),7,-1,(-2,-2)),
 pose((53,73),(55,61),(73,64),-18,(30,87),(74,87),(39,82),(62,77),13,2,(1,-1)),
 pose((57,74),(64,64),(76,64),18,(28,87),(77,87),(39,82),(67,79),18,3,(2,3)),
 pose((58,75),(66,67),(72,63),42,(29,87),(78,87),(40,83),(68,80),20,2,(3,4)),
],
'recover': [
 pose((57,75),(64,67),(70,56),62,(29,87),(77,87),(40,83),(67,81),18,2,(2,4)),
 pose((54,74),(60,64),(67,59),46,(31,87),(72,87),(40,82),(63,80),13,1,(1,3)),
 pose((51,73),(55,62),(63,62),25,(34,87),(66,87),(41,80),(59,79),8,0,(0,3)),
 pose((49,72),(51,60),(62,63),8,(37,87),(61,87),(42,79),(56,79),4,0,(-1,3)),
]},
2: {
'windup': [
 pose((50,72),(53,60),(64,58),56,(36,87),(63,87),(40,80),(58,78),4,1,(1,2)),
 pose((49,73),(50,62),(58,55),72,(34,87),(65,86),(39,82),(59,77),6,-1,(-1,2)),
 pose((48,74),(46,63),(51,53),92,(32,87),(66,87),(38,83),(60,79),8,-2,(-2,3)),
 pose((47,75),(43,65),(45,52),104,(31,87),(67,87),(37,83),(61,81),10,-3,(-3,4)),
],
'attack': [
 pose((49,75),(48,65),(57,51),72,(31,87),(68,85),(38,83),(60,78),8,-3,(-3,3)),
 pose((54,73),(59,62),(72,62),18,(30,87),(73,87),(39,82),(64,78),14,-2,(0,4)),
 pose((56,72),(64,59),(74,55),-18,(31,87),(75,87),(41,81),(66,77),19,2,(1,3)),
 pose((55,71),(61,56),(67,48),-46,(33,87),(73,87),(42,80),(64,77),21,3,(3,0)),
],
'recover': [
 pose((54,71),(59,56),(61,46),-68,(33,87),(72,87),(42,80),(63,77),18,2,(2,-1)),
 pose((52,72),(56,58),(59,51),-43,(34,87),(68,87),(42,80),(61,78),13,1,(1,0)),
 pose((50,72),(53,59),(61,57),-16,(36,87),(64,87),(42,79),(58,78),8,0,(0,2)),
 pose((49,72),(51,60),(62,63),8,(37,87),(61,87),(42,79),(56,79),4,0,(-1,3)),
]},
3: {
'windup': [
 pose((48,73),(49,61),(62,55),-50,(35,87),(64,87),(39,81),(57,80),4,0,(-2,-2)),
 pose((46,75),(45,64),(55,52),-82,(32,87),(67,86),(37,84),(59,79),7,-1,(-4,-2)),
 pose((44,77),(40,67),(46,48),-112,(29,87),(69,87),(35,85),(60,82),10,-2,(-4,-3)),
 pose((43,78),(38,68),(40,47),-136,(27,87),(71,87),(34,85),(61,83),13,-3,(-5,-4)),
],
'attack': [
 pose((48,76),(50,65),(58,48),-64,(27,87),(72,84),(35,85),(61,77),9,-1,(-3,-4)),
 pose((56,75),(61,65),(77,54),-8,(26,87),(79,87),(37,84),(68,79),17,2,(0,-2)),
 pose((61,76),(70,68),(77,58),4,(25,87),(82,87),(38,85),(72,80),25,3,(2,1)),
 pose((62,78),(71,71),(74,59),26,(26,87),(83,87),(39,85),(73,82),28,2,(4,2)),
],
'recover': [
 pose((61,78),(70,71),(72,56),50,(26,87),(82,87),(39,85),(72,83),25,2,(3,3)),
 pose((57,76),(64,67),(69,58),36,(29,87),(77,87),(40,83),(68,81),18,1,(2,3)),
 pose((53,74),(58,63),(65,61),20,(33,87),(69,87),(41,81),(62,79),11,0,(0,3)),
 pose((49,72),(51,60),(62,63),8,(37,87),(61,87),(42,79),(56,79),5,0,(-1,3)),
]}}

# The return cut settles onto a different rear heel, retaining its own recovery silhouette.
POSES[2]["recover"][3]["rear_foot"] = (38,87)

def ip(p): return (round(p[0]), round(p[1]))
def draw_frame(combo, phase, frame):
    airborne = phase == 'air_attack'
    source = POSES[combo]['attack' if airborne else phase][frame]
    q = dict(source)
    if airborne:
        # Fully separate airborne limb arrangement; no planted boots on an invisible floor.
        for key in ('hip','shoulder','hand'):
            q[key]=(q[key][0]+(frame%2),q[key][1]-5)
        q['rear_knee']=[(43,72),(44,73),(45,74),(44,75)][frame]
        q['rear_foot']=[(33,77),(34,79),(35,80),(33,79)][frame]
        q['front_knee']=[(62,67),(66,66),(69,68),(68,70)][frame]
        q['front_foot']=[(70,75),(76,73),(79,74),(78,77)][frame]
        q['cloth'] += 5 + frame
    im=Image.new('RGBA',SIZE); d=ImageDraw.Draw(im)
    def poly(points,fill,outline='ink'):
        d.polygon([ip(v) for v in points],fill=P.get(fill,fill),outline=P.get(outline,outline))
    def rect(box,fill): d.rectangle(tuple(round(v) for v in box),fill=P.get(fill,fill))
    def line(points,fill,width=1): d.line([ip(v) for v in points],fill=P.get(fill,fill),width=width)
    def limb(a,b,width,fill):
        dx=b[0]-a[0];dy=b[1]-a[1];length=max(1,math.hypot(dx,dy));nx=-dy/length*width/2;ny=dx/length*width/2
        poly([(a[0]+nx,a[1]+ny),(b[0]+nx,b[1]+ny),(b[0]-nx,b[1]-ny),(a[0]-nx,a[1]-ny)],fill)
    hip=q['hip'];sx,sy=q['shoulder'];hx,hy=q['hand'];tw=q['twist'];cloth=q['cloth']
    head=(sx+2+max(0,tw)//2,sy-9)
    # Far arm counterbalances the cut; the two-handed heavy cut will reappear over the chest.
    rear_shoulder=(sx-5,sy+1)
    rear_elbow=(sx-9-cloth//5,sy+7)
    rear_hand=(sx-15-cloth//4,sy+4+frame%2)
    if combo==3:
        rear_elbow=(sx-4,sy+9)
        rear_hand=(hx-5,hy+3)
    limb(rear_shoulder,rear_elbow,5,'shade');limb(rear_elbow,rear_hand,4,'plate')
    rect((rear_hand[0]-2,rear_hand[1]-2,rear_hand[0]+2,rear_hand[1]+2),'gold')
    # Far leg compresses and opens independently of the near leg.
    limb((hip[0]-3,hip[1]),q['rear_knee'],6,'shade')
    limb(q['rear_knee'],q['rear_foot'],5,'shade')
    lx,ly=q['rear_foot']
    poly([(lx-4,ly-4),(lx+1,ly-4),(lx+6,ly),(lx+6,ly+1),(lx-4,ly+1)],'plate')
    line([(lx-2,ly-1),(lx+5,ly-1)],'metal')
    # Cloth attachment is stable, but lag and separate torn folds reverse with the torso.
    tail=(sx-14-cloth,sy+19)
    poly([(sx-5,sy-6),(sx-11,sy-1),(sx-13-cloth*.6,sy+10),tail,(sx-8,sy+22),(sx-4,sy+17),(sx+1,sy+9)],'cloak')
    poly([(sx-9,sy-1),(sx-9-cloth*.5,sy+10),(tail[0]+5,tail[1]-1),(sx-6,sy+17),(sx-3,sy+10)],'fold')
    line([(tail[0]+2,tail[1]-2),(tail[0],tail[1]),(sx-9,sy+21)],'edge')
    line([(sx-12-cloth*.5,sy+13),(tail[0]+5,tail[1]-2)],'gold')
    limb((hip[0]+3,hip[1]),q['front_knee'],7,'shade')
    limb(q['front_knee'],q['front_foot'],6,'plate')
    kx,ky=q['front_knee'];rect((kx-2,ky-2,kx+2,ky+1),'gold')
    rx,ry=q['front_foot'];poly([(rx-4,ry-4),(rx+2,ry-4),(rx+7,ry),(rx+7,ry+1),(rx-4,ry+1)],'shade')
    line([(rx-2,ry-1),(rx+5,ry-1)],'metal',2)
    # Independent hip/shoulder axes produce a compressed, twisting adult armor core.
    poly([(sx-7,sy-3),(sx+5+tw,sy-2),(sx+8+tw,sy+4),(hip[0]+6,hip[1]+2),(hip[0]-6,hip[1]+2),(sx-8,sy+6)],'plate')
    poly([(sx-2,sy-2),(sx+3+tw,sy),(sx+4+tw,sy+7),(hip[0]+2,hip[1]-2),(hip[0]-2,hip[1]-1),(sx-4,sy+4)],'shade')
    line([(sx-6,sy+2),(sx-4,sy+7),(hip[0]-4,hip[1]-3)],'metal',2)
    line([(sx-4,sy+9),(sx+4+tw,sy+8)],'gold')
    line([(hip[0]-6,hip[1]-1),(hip[0]+6,hip[1]-1)],'gold',2)
    rect((hip[0]-1,hip[1]-3,hip[0]+2,hip[1]+1),'white')
    poly([(hip[0]-5,hip[1]+1),(hip[0],hip[1]+3),(hip[0]-3,hip[1]+7),(hip[0]-7,hip[1]+4)],'plate')
    poly([(sx+2,sy-4),(sx+7+tw,sy-4),(sx+10+tw,sy),(sx+7+tw,sy+4),(sx+2,sy+2)],'gold')
    line([(sx+3,sy-3),(sx+7+tw,sy-2)],'white')
    rect((sx,sy+1,sx+1,sy+4),'cyan')
    # Broken-crown helm: same pale plate, cyan slit and plum scarf, redrawn per body pose.
    cx,cy=head
    poly([(cx-8,cy-5),(cx-5,cy-8),(cx+3,cy-7),(cx+8,cy-3),(cx+9,cy+2),(cx+5,cy+7),(cx-4,cy+6),(cx-8,cy+2)],'shade')
    poly([(cx-6,cy-5),(cx-7,cy-11),(cx-4,cy-10),(cx-2,cy-6),(cx+1,cy-7),(cx+3,cy-11),(cx+5,cy-9),(cx+4,cy-6)],'gold')
    rect((cx-6,cy-10,cx-5,cy-8),'white')
    poly([(cx-4,cy-5),(cx+4,cy-5),(cx+7,cy-1),(cx+7,cy+3),(cx+2,cy+6),(cx-3,cy+4)],'plate')
    poly([(cx+2,cy-4),(cx+5,cy-2),(cx+5,cy+2),(cx+1,cy+4),(cx,cy+1)],'metal')
    line([(cx-3,cy),(cx+6,cy)],'ink',2)
    line([(cx+1,cy),(cx+6,cy)],'cyan')
    rect((cx+4,cy,cx+5,cy),'white')
    line([(cx-2,cy+3),(cx+1,cy+5)],'gold')
    poly([(cx-6,cy+4),(cx+1,cy+6),(cx-1,cy+10),(cx-9,cy+8),(cx-13-cloth//5,cy+9),(cx-11,cy+5)],'cloak')
    line([(cx-8,cy+6),(cx-2,cy+8)],'edge')
    # Shoulder, elbow and hand rotate around distinct joints. No full-frame rotation.
    front_shoulder=(sx+4+tw/2,sy)
    eb=q['elbow_bias']
    elbow=((front_shoulder[0]+hx)/2+eb[0],(front_shoulder[1]+hy)/2+eb[1])
    limb(front_shoulder,elbow,6,'plate');limb(elbow,(hx,hy),5,'shade')
    rect((hx-2,hy-2,hx+2,hy+2),'gold');rect((hx-1,hy-2,hx+1,hy),'metal')
    body=im.copy()
    angle=q['angle'];a=math.radians(angle);u=(math.cos(a),math.sin(a));n=(-u[1],u[0]);length=42 if combo==3 else 40
    tip=(hx+u[0]*length,hy+u[1]*length);base=(hx+u[0]*3,hy+u[1]*3)
    # Steel is long and narrow; the much larger energy sweep is owned by the shared VFX profile.
    line([(hx-u[0]*5,hy-u[1]*5),(hx+u[0]*2,hy+u[1]*2)],'shade',3)
    poly([(base[0]+n[0]*2,base[1]+n[1]*2),(tip[0]-u[0]*4+n[0],tip[1]-u[1]*4+n[1]),tip,
          (tip[0]-u[0]*4-n[0],tip[1]-u[1]*4-n[1]),(base[0]-n[0]*2,base[1]-n[1]*2)],'metal')
    line([(base[0]+n[0],base[1]+n[1]),tip],'white')
    line([(hx+n[0]*5,hy+n[1]*5),(hx-n[0]*5,hy-n[1]*5)],'gold',2)
    meta={k:list(ip(q[k])) for k in ('hip','shoulder','hand','rear_foot','front_foot','rear_knee','front_knee')}
    meta.update({'head':list(ip(head)),'elbow':list(ip(elbow)),'rear_elbow':list(ip(rear_elbow)),
      'rear_hand':list(ip(rear_hand)),'tip':list(ip(tip)),'tip_local':[round(tip[0])-ANCHOR[0],round(tip[1])-ANCHOR[1]],
      'hand_local':[round(hx)-ANCHOR[0],round(hy)-ANCHOR[1]],'blade_angle_degrees':angle,'steel_length_pixels':length,
      'body_axes':{'hip':list(ip(hip)),'shoulder':list(ip((sx,sy))),'head':list(ip(head))},
      'body_bbox':list(body.getbbox()),'airborne':airborne,'ground_contact':not airborne,
      'planted_feet':[] if airborne else [name for name in ('rear_foot','front_foot') if q[name][1]+1==ANCHOR[1]],
      'body_sha256':hashlib.sha256(body.tobytes()).hexdigest(),'cloth_lag_pixels':cloth})
    return im,meta

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    frames=[];states={};metadata={};tips={}
    for combo in range(1,4):
        for phase in ('windup','attack','recover','air_attack'):
            state=f'cut_{combo}_{phase}';states[state]={'start':len(frames),'count':4};metadata[state]=[]
            for frame in range(4):
                im,m=draw_frame(combo,phase,frame);frames.append((state,frame,im));metadata[state].append(m)
            tips[state]=[m['tip_local'] for m in metadata[state]]
    columns=8;atlas=Image.new('RGBA',(columns*SIZE[0],math.ceil(len(frames)/columns)*SIZE[1]))
    for i,(_,_,im) in enumerate(frames):atlas.alpha_composite(im,((i%columns)*SIZE[0],(i//columns)*SIZE[1]))
    atlas.save(OUT/'hero_atlas.png')
    for name,color in [('hero_flash.png','#e8fff0'),('hero_silhouette.png','#72ece2')]:
        tint=Image.new('RGBA',atlas.size,color);tint.putalpha(atlas.getchannel('A'));tint.save(OUT/name)
    manifest={'version':1,'source':'Original articulated broken-crown armor family; tools/generate_hero_attack_revision.py; no external assets or 3D.','license':'MIT',
       'hero':{'canvas':list(SIZE),'anchor':list(ANCHOR),'columns':columns,'total_frames':len(frames),'states':states,'weapon_tips':tips,'frame_data':metadata,
               'nominal_armor_body_height':44,'palette_rgb':list(P.values())},
       'timing':{'samples':[0,.25,.5,.75],'first_contact_frame':1,'phase_frames':4},
       'constraints':{'anti_alias':False,'whole_frame_rotation':False,'whole_frame_translation':False,'3d_sources':False,'ground_feet_line':88}}
    profile_path=ROOT/'data/hero_attack_profiles.json'
    profile=json.loads(profile_path.read_text(encoding='utf-8-sig'))
    profile_matches=all([m['blade_angle_degrees'] for m in metadata[f'cut_{c}_attack']]==[k[1] for k in profile['combos'][str(c)]['angle_keys'][:4]] and metadata[f'cut_{c}_recover'][0]['blade_angle_degrees']==profile['combos'][str(c)]['angle_keys'][-1][1] for c in range(1,4))
    manifest['attack_profile']={'resource':'res://data/hero_attack_profiles.json','sha256':hashlib.sha256(profile_path.read_bytes()).hexdigest(),'origin':profile['origin'],'contact_start':profile['contact_start'],'combos':profile['combos']}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    # Fixed native-scale and exact 2x sheets. Production frames themselves are never resized.
    sheet=Image.new('RGB',(104+4*128,24+len(states)*96),'#151728');d=ImageDraw.Draw(sheet)
    for row,state in enumerate(states):
        d.text((4,30+row*96),state,fill=P['gold'])
        for frame in range(4):
            im,_=draw_frame(int(state[4]),state[6:],frame)
            x=104+frame*128;y=24+row*96
            d.line([(x+ANCHOR[0],y+88),(x+ANCHOR[0]+1,y+88)],fill='#54616b')
            sheet.paste(im,(x,y),im)
    sheet.save(OUT/'hero_attack_contact_native.png')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(OUT/'hero_attack_contact_2x.png')
    active=Image.new('RGB',(4*256,3*192),'#151728')
    for combo in range(1,4):
        for frame in range(4):
            im,_=draw_frame(combo,'attack',frame);im=im.resize((256,192),Image.Resampling.NEAREST)
            active.paste(im,(frame*256,(combo-1)*192),im)
    active.save(OUT/'hero_active_contact_2x.png')
    adjacency={};body_adjacency={};border=[];ground=[];air=[]
    for state,desc in states.items():
        images=[frames[desc['start']+i][2] for i in range(4)]
        adjacency[state]=[sum(a!=b for a,b in zip(images[i].get_flattened_data(),images[i+1].get_flattened_data())) for i in range(3)]
        body_adjacency[state]=len({m['body_sha256'] for m in metadata[state]})
        for frame,im in enumerate(images):
            b=im.getbbox()
            if b and (b[0]<=0 or b[1]<=0 or b[2]>=128 or b[3]>=96):border.append([state,frame,list(b)])
            m=metadata[state][frame]
            (air if m['airborne'] else ground).append(m)
    colors={px[:3] for px in atlas.get_flattened_data() if px[3]}
    alpha={px[3] for px in atlas.get_flattened_data()}
    report={'frames':len(frames),'unique_frames':len({hashlib.sha256(im.tobytes()).hexdigest() for _,_,im in frames}),
      'opaque_palette_colors':len(colors),'alpha_levels':sorted(alpha),'anchor':list(ANCHOR),
      'clipped_frames':border,'adjacent_changed_pixels':adjacency,'unique_body_frames_per_state':body_adjacency,
      'all_ground_frames_have_support':all(m['planted_feet'] for m in ground),
      'all_air_frames_have_tucked_feet':all(max(m['rear_foot'][1],m['front_foot'][1])<84 for m in air),
      'attack_angles':{str(c):[m['blade_angle_degrees'] for m in metadata[f'cut_{c}_attack']] for c in range(1,4)},
      'shared_profile_origin':[0,-24],'shared_energy_radii':{'1':[180,72],'2':[204,84],'3':[228,96]},
      'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}}
    report['shared_profile_angles_match']=profile_matches
    report['first_contact_fully_extended']=all(metadata[f'cut_{c}_attack'][1]['hand_local'][0]>=20 and metadata[f'cut_{c}_attack'][1]['tip_local'][0]>=60 for c in range(1,4))
    report['passed']=profile_matches and report['first_contact_fully_extended'] and report['frames']==48 and report['unique_frames']==48 and len(colors)<=32 and alpha=={0,255} and not border and all(min(v)>0 for v in adjacency.values()) and all(v==4 for v in body_adjacency.values()) and report['all_ground_frames_have_support'] and report['all_air_frames_have_tucked_feet']
    (OUT/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('sha256','adjacent_changed_pixels','unique_body_frames_per_state')}))
    if not report['passed']:raise SystemExit(1)
if __name__=='__main__':main()
