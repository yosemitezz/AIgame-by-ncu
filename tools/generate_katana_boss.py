"""Original adult katana swordswoman: editable native-pixel seed candidates.
All points are authored on a 128x128 integer grid. No source images, 3D renders,
commercial character assets, resampled body parts or API credentials are used.
A is approved; full poses follow the pure PR1 state/progress contract, never a wall clock.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'presentation/katana_frames'
SIZE=128
ANCHOR=(48,116)
P={'ink':'#111420','deep':'#202535','hair_dark':'#34394e','hair_mid':'#7c8797',
   'silver':'#bdc8cf','hair_light':'#e1e3d4','armor':'#293341','armor_light':'#536374',
   'gold_dark':'#765644','gold':'#b89159','gold_light':'#e3c286','cloth_dark':'#352331',
   'wine':'#713d50','wine_light':'#ad6372','skin_shadow':'#b58b83','skin':'#e4bd9d',
   'white':'#f6efdb','steel':'#9eb7c7','edge':'#dcebf0','eye':'#a3e3df'}
# Main body height 65-68 px, face/head about 10-11 px: approximately 6.5 heads. Adult proportions,
# covered torso/legs and restrained 1px eyes keep the face from reading as a child.
POSES={
 'A':{'name':'INK-SILVER / TWIN HEM','head':(48,55),'shoulder':(47,69),'hip':(47,86),
      'far_knee':(39,100),'far_foot':(36,115),'near_knee':(56,101),'near_foot':(60,115),
      'near_elbow':(58,80),'far_elbow':(48,81),'hand':(64,91),'support':(57,89),
      'guard':(68,91),'weapon_tip':(121,94),'guard_point':(69,90)},
 'B':{'name':'CHARCOAL KNOT / ONE MANTLE','head':(48,54),'shoulder':(47,68),'hip':(48,86),
      'far_knee':(42,101),'far_foot':(38,115),'near_knee':(56,101),'near_foot':(62,115),
      'near_elbow':(59,79),'far_elbow':(49,80),'hand':(65,89),'support':(57,88),
      'guard':(69,89),'weapon_tip':(122,92),'guard_point':(70,89)},
 'C':{'name':'WINE TAIL / LOW DRAW','head':(49,56),'shoulder':(48,70),'hip':(47,87),
      'far_knee':(37,101),'far_foot':(31,115),'near_knee':(56,102),'near_foot':(63,115),
      'near_elbow':(61,82),'far_elbow':(49,83),'hand':(67,92),'support':(59,89),
      'guard':(71,92),'weapon_tip':(122,97),'guard_point':(71,91)}}

def seed(candidate, pose=None, state="idle", frame=0):
    pose=POSES[candidate] if pose is None else pose
    im=Image.new('RGBA',(SIZE,SIZE));d=ImageDraw.Draw(im)
    col=lambda name:P.get(name,name)
    def poly(points,key,outline='ink'):d.polygon([(round(x),round(y)) for x,y in points],fill=col(key),outline=col(outline))
    def line(points,key,width=1):d.line([(round(x),round(y)) for x,y in points],fill=col(key),width=width)
    def rect(box,key):d.rectangle(tuple(round(v) for v in box),fill=col(key))
    def limb(a,b,width,key):
        dx=b[0]-a[0];dy=b[1]-a[1];length=max(1,math.hypot(dx,dy));nx=-dy/length*width*.5;ny=dx/length*width*.5
        poly([(a[0]+nx,a[1]+ny),(b[0]+nx,b[1]+ny),(b[0]-nx,b[1]-ny),(a[0]-nx,a[1]-ny)],key)
    hx,hy=pose['head'];sx,sy=pose['shoulder'];px,py=pose['hip'];hand=pose['hand'];support=pose['support'];wind=pose.get('hair_swing',0)
    # Separate hair masses with a tied silhouette; each candidate changes the outline.
    if candidate=='A':
        poly([(hx-8,hy-8),(hx-12,hy-5),(hx-13,hy+5),(hx-18-wind,hy+14),(hx-17-wind,hy+25),(hx-10-wind*.5,hy+19),(hx-8,hy+9),(hx-4,hy-2)],'hair_dark')
        poly([(hx-10,hy-5),(hx-10,hy+7),(hx-15-wind,hy+16),(hx-15-wind,hy+21),(hx-11-wind*.5,hy+16),(hx-7,hy+4)],'silver')
        line([(hx-11,hy+3),(hx-15-wind,hy+14)],'hair_light')
        rect((hx-12,hy-2,hx-8,hy),'gold')
    elif candidate=='B':
        poly([(hx-6,hy-8),(hx-10,hy-12),(hx-8,hy-15),(hx-3,hy-15),(hx,hy-11),(hx-1,hy-7)],'hair_dark')
        line([(hx-8,hy-13),(hx-4,hy-13)],'silver');rect((hx-7,hy-9,hx-2,hy-8),'gold')
        poly([(hx-8,hy-6),(hx-13,hy+1),(hx-10,hy+9),(hx-15,hy+18),(hx-10,hy+15),(hx-6,hy+7),(hx-3,hy-2)],'hair_mid')
    else:
        poly([(hx-9,hy-4),(hx-12,hy+4),(hx-11,hy+17),(hx-18,hy+27),(hx-19,hy+36),(hx-12,hy+29),(hx-6,hy+14),(hx-4,hy+3)],'hair_dark')
        line([(hx-10,hy+7),(hx-10,hy+17),(hx-16,hy+29)],'silver')
        rect((hx-11,hy+6,hx-7,hy+7),'wine_light')
    # Far leg is opaque cloth; fitted greaves and steel-toed boots define the stance.
    limb((px-5,py),pose['far_knee'],6,'deep');limb(pose['far_knee'],pose['far_foot'],5,'armor')
    fx,fy=pose['far_foot'];poly([(fx-3,fy-3),(fx+2,fy-4),(fx+5,fy),(fx+5,fy+1),(fx-4,fy+1)],'deep');line([(fx-2,fy),(fx+4,fy)],'gold_dark')
    # Two tailored long coat tails with a central negative space. No skirt fan/cone.
    if candidate=='A':
        # Hems stay near the floor during collapse; two independent panels retain their gap.
        left_x=px-18-pose.get('hem_swing',0);right_x=px+18-pose.get('hem_swing',0)*.45
        left_y=min(115,py+28-pose.get('hem_lift',0));right_y=min(115,py+27-pose.get('hem_lift',0)*.5)
        poly([(px-8,py-2),(px-14,py+4),(left_x-4,left_y-4),(left_x,left_y),(px-8,min(py+17,left_y-3)),(px-3,py+5)],'wine')
        poly([(px+1,py),(px+9,py-1),(right_x,right_y-6),(right_x+3,right_y),(px+9,right_y-3),(px+5,py+8)],'cloth_dark')
        line([(px-12,py+6),(left_x,left_y-2)],'wine_light');line([(px+10,py+5),(right_x-1,right_y-4)],'gold')
    elif candidate=='B':
        poly([(px-7,py-2),(px-16,py+6),(px-21,py+25),(px-14,py+29),(px-7,py+20),(px-2,py+6)],'cloth_dark')
        poly([(px+4,py),(px+10,py-1),(px+15,py+26),(px+10,py+30),(px+6,py+16)],'wine')
        line([(px-15,py+8),(px-18,py+24)],'gold');line([(px+10,py+5),(px+13,py+24)],'wine_light')
    else:
        poly([(px-8,py-2),(px-13,py+7),(px-21,py+26),(px-17,py+28),(px-8,py+19),(px-2,py+7)],'wine')
        poly([(px+2,py),(px+10,py),(px+20,py+24),(px+21,py+28),(px+13,py+25),(px+6,py+13)],'wine')
        line([(px-12,py+7),(px-18,py+26)],'gold');line([(px+10,py+5),(px+19,py+27)],'wine_light')
    limb((px+5,py),pose['near_knee'],7,'deep');limb(pose['near_knee'],pose['near_foot'],6,'armor')
    nx,ny=pose['near_knee'];line([(nx+1,ny+2),(pose['near_foot'][0]+1,pose['near_foot'][1]-3)],'armor_light')
    fx,fy=pose['near_foot'];poly([(fx-3,fy-4),(fx+2,fy-3),(fx+6,fy),(fx+6,fy+1),(fx-3,fy+1)],'armor');line([(fx-1,fy-1),(fx+4,fy)],'steel')
    # Tailored high-neck torso, small overlapping armor plates and 1px fastening hardware.
    poly([(sx-7,sy-3),(sx+5,sy-3),(sx+9,sy+5),(px+5,py+2),(px-6,py+2),(sx-9,sy+5)],'deep')
    poly([(sx-4,sy),(sx+3,sy-1),(sx+5,sy+7),(px+1,py-2),(px-4,py-3),(sx-5,sy+7)],'armor')
    line([(sx-3,sy+1),(sx-2,sy+8),(px-1,py-4)],'armor_light')
    line([(sx+3,sy+2),(sx+5,sy+7)],'gold');rect((sx+1,sy+3,sx+1,sy+3),'gold_light')
    rect((px-7,py-3,px+6,py-1),'gold_dark');rect((px-2,py-4,px+1,py),'gold');rect((px-1,py-3,px,py-2),'gold_light')
    poly([(sx-7,sy-4),(sx-2,sy-5),(sx+1,sy-1),(sx-5,sy+5),(sx-11,sy+4)],'armor')
    line([(sx-8,sy-2),(sx-4,sy-3)],'gold')
    if candidate=='B':
        poly([(sx-8,sy-5),(sx-14,sy-1),(sx-21,sy+12),(sx-20,sy+22),(sx-11,sy+15),(sx-7,sy+4)],'cloth_dark')
        line([(sx-13,sy+2),(sx-18,sy+14)],'gold')
    # Neck, adult face profile and long bangs: one narrow eye, no large anime eye clusters.
    rect((hx-1,hy+5,hx+2,sy-3),'skin_shadow')
    poly([(hx-5,hy-4),(hx+2,hy-5),(hx+6,hy-2),(hx+7,hy+1),(hx+5,hy+2),(hx+5,hy+3),(hx+1,hy+5),(hx-3,hy+4),(hx-5,hy+1)],'skin')
    poly([(hx-7,hy-4),(hx-4,hy-6),(hx+2,hy-6),(hx+6,hy-4),(hx+6,hy-2),(hx+2,hy-3),(hx,hy),(hx-2,hy-2),(hx-3,hy+3),(hx-6,hy+3)],'hair_dark')
    poly([(hx-5,hy-4),(hx-3,hy-5),(hx+2,hy-5),(hx+4,hy-4),(hx+1,hy-4),(hx-1,hy-1),(hx-2,hy-3),(hx-4,hy+1)],'silver')
    line([(hx-3,hy-5),(hx+1,hy-5)],'hair_light');rect((hx+3,hy,hx+5,hy),'deep');rect((hx+4,hy,hx+4,hy),'eye');rect((hx+3,hy+3,hx+4,hy+3),'skin_shadow')
    rect((hx-4,hy+3,hx-3,hy+4),'skin_shadow')
    # A plain collar and one original diamond fastener; no imported insignia or ear ornament.
    poly([(sx-4,sy-5),(sx,sy-6),(sx+4,sy-3),(sx+1,sy),(sx-4,sy-1)],'wine')
    rect((sx+1,sy-3,sx+1,sy-2),'gold_light')
    # Backward scabbard remains visibly separate from the front sword.
    sheath_y=min(114,py+25)
    poly([(px-3,py+2),(px-5,py),(px-30,sheath_y-2),(px-28,sheath_y+1)],'deep')
    line([(px-6,py+4),(px-27,sheath_y-1)],'gold_dark');rect((px-29,sheath_y-1,px-27,sheath_y+1),'gold')
    # Two covered arms brace the hilt; fingers are small and the sleeve is fully closed.
    limb((sx-4,sy+2),pose['far_elbow'],5,'deep');limb(pose['far_elbow'],support,5,'armor')
    rect((support[0]-2,support[1]-1,support[0]+2,support[1]+2),'skin_shadow')
    limb((sx+6,sy),pose['near_elbow'],6,'armor');limb(pose['near_elbow'],hand,5,'deep')
    ex,ey=pose['near_elbow'];rect((ex-1,ey-1,ex+1,ey+1),'gold_dark')
    # Slightly curved, genuinely thin katana. Its source hand/guard/tip are explicit landmarks.
    gx,gy=pose['guard'];tx,ty=pose['weapon_tip'];dx=tx-gx;dy=ty-gy
    line([(support[0]-2,support[1]),(gx,gy)],'ink',4);line([(support[0]-2,support[1]),(gx,gy)],'gold_dark',2)
    for k in range(3):rect((gx-9+k*3,gy-1,gx-9+k*3,gy),'gold_light')
    rect((hand[0]-2,hand[1]-2,hand[0]+1,hand[1]+1),'skin');rect((hand[0]-2,hand[1]-2,hand[0]-1,hand[1]-1),'white')
    line([(gx,gy-3),(gx,gy+3)],'gold',2);rect((gx-1,gy-2,gx,gy-1),'gold_light')
    curve=[(gx+1,gy),(gx+dx*.45,gy+dy*.45-2),(tx-5,ty-1),(tx,ty)]
    line(curve,'ink',3);line(curve,'steel',2);line([(x,y-1) for x,y in curve],'edge',1)
    rect((tx-1,ty-1,tx,ty),'white')
    return im

def local(point):return [point[0]-ANCHOR[0],point[1]-ANCHOR[1]]
def make_seeds():
    OUT.mkdir(parents=True,exist_ok=True);manifest={'version':1,'status':'SEED_ONLY_WAITING_FOR_VISUAL_AND_PR1_TIMING_REVIEW','canvas':[128,128],'anchor':list(ANCHOR),'body_height_px':[65,68],'native_filter':'nearest','license':'MIT','source':'Original integer-grid drawing and editable pose dictionaries in tools/generate_katana_boss.py. No external raster or 3D source.','selected_candidate':None,'candidates':{},'pending_states':['idle','approach','shift','draw','cut_a','cut_b','retreat','cast','parry_recoil','armored_recoil','guard_break','guard_recover','hurt','dead'],'pending_timing':'PR1 get_presentation_pose returns state/progress/strike/armored/contact_serial. Cut A/B frame zero must already extend to contact; never inherit old Boss timing.'}
    board=Image.new('RGB',(3*272,740),'#101321');d=ImageDraw.Draw(board)
    d.text((12,8),'ORIGINAL ADULT KATANA BOSS / 128px SOURCE / SEEDS ONLY',fill=P['gold_light'])
    report={}
    for index,(candidate,pose) in enumerate(POSES.items()):
        im=seed(candidate);im.save(OUT/f'seed_{candidate.lower()}.png')
        alpha=im.getchannel('A');body_box=alpha.getbbox()
        record={'file':f'seed_{candidate.lower()}.png','name':pose['name'],'state':'representative_ready','frame':0,'hit_window':False,'hand':local(pose['hand']),'support_hand':local(pose['support']),'guard':local(pose['guard']),'weapon_tip':local(pose['weapon_tip']),'guard_point':local(pose['guard_point']),'joints':{key:local(value) for key,value in pose.items() if isinstance(value,tuple)},'bbox':list(body_box)}
        manifest['candidates'][candidate]=record
        report[candidate]={'sha256':hashlib.sha256(im.tobytes()).hexdigest(),'opaque_colors':len({pixel[:3] for pixel in im.get_flattened_data() if pixel[3]}),'alpha_values':sorted(set(alpha.get_flattened_data())),'bbox':body_box,'hand_guard_tip_in_bounds':all(0<=x<128 and 0<=y<128 for x,y in [pose['hand'],pose['guard'],pose['weapon_tip']]),'forward_tip_distance_px':record['weapon_tip'][0],'main_body_height_px':ANCHOR[1]-(pose['head'][1]-6),'feet_anchor_preserved':body_box[3]==117}
        x=index*272+8;d.text((x,30),candidate+'  '+pose['name'],fill=P['gold_light'])
        scaled=im.resize((256,256),Image.Resampling.NEAREST);board.paste(scaled,(x,48),scaled)
        white=Image.new('RGBA',im.size,'#dfe8de');white.putalpha(alpha);white=white.resize((256,256),Image.Resampling.NEAREST);board.paste(white,(x,310),white)
        board.paste(im,(x+64,576),im)
        d.text((x,716),'TOP: 2x COLOUR / MID: SILHOUETTE',fill='#a0adbc')
    board.save(OUT/'seed-candidates-contact.png')
    (OUT/'seed-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    (OUT/'seed-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))



STATES=[('idle',4),('approach',6),('shift',4),('draw',4),('cut_a',4),('cut_b',4),('recover',4),('cast',4),('parry_recoil',4),('parry_recover',4),('armored_recoil',4),('guard_break',4),('guard_recover',4),('hurt',4),('dead',4)]

def body(head=(48,55),shoulder=(47,69),hip=(47,86),far_knee=(39,100),far_foot=(36,115),near_knee=(56,101),near_foot=(60,115),hand=(64,91),support=(57,89),guard=(68,91),tip=(121,94),near_elbow=(58,80),far_elbow=(48,81),hair=0,hem=0,lift=0):
    return dict(name='A / INK-SILVER TWIN HEM',head=head,shoulder=shoulder,hip=hip,far_knee=far_knee,far_foot=far_foot,near_knee=near_knee,near_foot=near_foot,hand=hand,support=support,guard=guard,weapon_tip=tip,guard_point=(guard[0]+1,guard[1]-1),near_elbow=near_elbow,far_elbow=far_elbow,hair_swing=hair,hem_swing=hem,hem_lift=lift)

# Keyed joint drawings. Changes are in anatomy, wrists, knee support and cloth, never image transforms.
FAMILY={
'idle':[
 body(),body(head=(48,54),shoulder=(47,68),hand=(64,90),guard=(68,90),tip=(121,93),hair=1,hem=1),
 body(head=(48,55),shoulder=(47,70),hand=(64,92),guard=(68,92),tip=(120,95),hair=2,hem=2),
 body(head=(48,55),shoulder=(47,69),hand=(65,91),guard=(69,91),tip=(121,94),hair=1,hem=1)],
'approach':[
 body(head=(51,54),shoulder=(50,68),hip=(48,85),far_knee=(38,97),far_foot=(30,113),near_knee=(58,99),near_foot=(65,115),hand=(66,88),guard=(70,88),tip=(121,87),hair=4,hem=5,lift=3),
 body(head=(52,53),shoulder=(51,67),hip=(49,84),far_knee=(41,101),far_foot=(43,115),near_knee=(59,95),near_foot=(62,105),hand=(65,87),guard=(69,87),tip=(121,88),hair=5,hem=7,lift=4),
 body(head=(52,54),shoulder=(51,68),hip=(49,85),far_knee=(52,101),far_foot=(58,114),near_knee=(48,95),near_foot=(43,106),hand=(64,88),guard=(68,88),tip=(120,90),hair=4,hem=6,lift=4),
 body(head=(51,54),shoulder=(50,68),hip=(48,85),far_knee=(58,99),far_foot=(65,115),near_knee=(38,97),near_foot=(30,113),hand=(65,89),guard=(69,89),tip=(121,91),hair=3,hem=4,lift=2),
 body(head=(52,53),shoulder=(51,67),hip=(49,84),far_knee=(59,95),far_foot=(62,105),near_knee=(41,101),near_foot=(43,115),hand=(67,88),guard=(71,88),tip=(122,88),hair=5,hem=6,lift=4),
 body(head=(52,54),shoulder=(51,68),hip=(49,85),far_knee=(48,95),far_foot=(43,106),near_knee=(52,101),near_foot=(58,114),hand=(67,89),guard=(71,89),tip=(122,90),hair=6,hem=7,lift=4)],
'shift':[
 body(head=(47,57),shoulder=(46,71),hip=(46,88),far_knee=(35,101),far_foot=(27,115),near_knee=(55,99),near_foot=(65,112),hand=(61,88),guard=(65,88),tip=(113,73),hair=-2,hem=-3,lift=3),
 body(head=(43,56),shoulder=(42,70),hip=(43,87),far_knee=(31,98),far_foot=(25,112),near_knee=(54,101),near_foot=(63,115),hand=(57,84),guard=(61,84),tip=(111,70),hair=-3,hem=-4,lift=6),
 body(head=(44,56),shoulder=(43,70),hip=(43,87),far_knee=(34,101),far_foot=(30,115),near_knee=(52,98),near_foot=(59,110),hand=(58,86),guard=(62,86),tip=(113,78),hair=-2,hem=-3,lift=4),
 body(head=(47,55),shoulder=(46,69),hip=(46,86),far_knee=(38,100),far_foot=(34,115),near_knee=(54,100),near_foot=(60,115),hand=(62,90),guard=(66,90),tip=(119,91),hair=-1,hem=-1)],
'draw':[
 body(head=(48,56),shoulder=(47,70),hip=(47,87),hand=(59,85),support=(49,87),guard=(63,85),tip=(112,75),near_elbow=(56,76),hair=1,hem=1),
 body(head=(46,57),shoulder=(45,71),hip=(46,88),far_knee=(36,102),near_knee=(57,102),hand=(54,79),support=(48,83),guard=(58,79),tip=(103,57),near_elbow=(52,71),hair=2,hem=2),
 body(head=(44,58),shoulder=(43,72),hip=(45,89),far_knee=(34,102),far_foot=(31,115),near_knee=(57,102),hand=(49,75),support=(45,79),guard=(53,75),tip=(84,39),near_elbow=(48,68),far_elbow=(42,78),hair=3,hem=3),
 body(head=(45,58),shoulder=(44,72),hip=(45,89),far_knee=(34,102),far_foot=(31,115),near_knee=(58,101),hand=(50,73),support=(45,77),guard=(54,73),tip=(88,37),near_elbow=(48,67),far_elbow=(42,77),hair=4,hem=4)],
'cut_a':[
 body(head=(54,56),shoulder=(53,70),hip=(49,87),far_knee=(36,101),far_foot=(29,115),near_knee=(62,100),near_foot=(69,115),hand=(58,91),support=(52,89),guard=(62,91),tip=(121,95),near_elbow=(61,80),far_elbow=(49,81),hair=7,hem=8,lift=4),
 body(head=(55,57),shoulder=(54,71),hip=(50,88),far_knee=(36,102),far_foot=(28,115),near_knee=(63,101),near_foot=(70,115),hand=(59,92),support=(53,90),guard=(63,92),tip=(121,96),near_elbow=(62,81),hair=9,hem=10,lift=5),
 body(head=(54,57),shoulder=(53,71),hip=(50,88),far_knee=(37,102),far_foot=(29,115),near_knee=(62,101),near_foot=(69,115),hand=(58,94),support=(52,92),guard=(62,94),tip=(120,94),near_elbow=(61,83),hair=8,hem=9,lift=4),
 body(head=(52,56),shoulder=(51,70),hip=(49,87),far_knee=(38,101),far_foot=(31,115),near_knee=(60,101),near_foot=(66,115),hand=(57,95),support=(51,93),guard=(61,95),tip=(119,93),near_elbow=(60,84),hair=6,hem=6,lift=2)],
'cut_b':[
 body(head=(52,56),shoulder=(51,70),hip=(49,87),far_knee=(37,101),far_foot=(30,115),near_knee=(61,100),near_foot=(68,115),hand=(58,97),support=(52,95),guard=(62,97),tip=(121,91),near_elbow=(60,85),far_elbow=(48,84),hair=5,hem=-3,lift=4),
 body(head=(54,55),shoulder=(53,69),hip=(50,86),far_knee=(37,101),far_foot=(30,115),near_knee=(62,99),near_foot=(69,115),hand=(59,95),support=(53,93),guard=(63,95),tip=(120,91),near_elbow=(61,83),hair=2,hem=-5,lift=5),
 body(head=(53,54),shoulder=(52,68),hip=(50,85),far_knee=(38,100),far_foot=(32,115),near_knee=(61,98),near_foot=(67,115),hand=(58,93),support=(52,91),guard=(62,93),tip=(119,92),near_elbow=(60,81),hair=-1,hem=-4,lift=4),
 body(head=(51,54),shoulder=(50,68),hip=(49,85),far_knee=(39,100),far_foot=(34,115),near_knee=(59,99),near_foot=(64,115),hand=(57,91),support=(51,89),guard=(61,91),tip=(118,94),near_elbow=(59,79),hair=-2,hem=-2,lift=2)],
'recover':[
 body(head=(50,55),shoulder=(49,69),hip=(48,86),far_knee=(37,100),far_foot=(31,115),near_knee=(58,101),near_foot=(65,115),hand=(60,93),guard=(64,93),tip=(115,99),near_elbow=(58,82),hair=4,hem=4),
 body(head=(46,56),shoulder=(45,70),hip=(45,87),far_knee=(33,101),far_foot=(27,115),near_knee=(54,100),near_foot=(60,113),hand=(57,89),guard=(61,89),tip=(102,112),near_elbow=(54,80),hair=2,hem=-1,lift=2),
 body(head=(45,55),shoulder=(44,69),hip=(44,86),far_knee=(35,100),far_foot=(31,115),near_knee=(53,101),near_foot=(57,115),hand=(54,87),support=(47,88),guard=(58,87),tip=(91,115),near_elbow=(51,78),hair=1,hem=-2),
 body(head=(47,55),shoulder=(46,69),hip=(46,86),hand=(59,89),support=(52,88),guard=(63,89),tip=(109,104),near_elbow=(55,79),hair=0,hem=-1)],
'cast':[
 body(hand=(63,82),support=(51,77),guard=(67,82),tip=(113,105),near_elbow=(56,73),far_elbow=(43,72),hair=1,hem=1),
 body(head=(48,54),shoulder=(47,68),hand=(62,79),support=(54,68),guard=(66,79),tip=(110,106),near_elbow=(56,72),far_elbow=(45,67),hair=3,hem=2),
 body(head=(49,54),shoulder=(48,68),hand=(63,79),support=(58,66),guard=(67,79),tip=(111,106),near_elbow=(57,72),far_elbow=(47,64),hair=4,hem=3),
 body(head=(49,55),shoulder=(48,69),hand=(64,84),support=(56,74),guard=(68,84),tip=(114,106),near_elbow=(58,76),far_elbow=(47,70),hair=2,hem=1)],
'parry_recoil':[
 body(head=(47,56),shoulder=(46,70),hip=(46,87),hand=(61,87),support=(54,86),guard=(65,87),tip=(105,61),near_elbow=(55,77),hair=-1,hem=-1),
 body(head=(44,58),shoulder=(43,72),hip=(44,89),far_knee=(35,102),far_foot=(31,115),near_knee=(55,102),near_foot=(61,115),hand=(55,81),support=(48,82),guard=(59,81),tip=(87,43),near_elbow=(49,73),hair=-3,hem=-3),
 body(head=(41,60),shoulder=(40,74),hip=(42,90),far_knee=(32,103),far_foot=(27,115),near_knee=(53,102),near_foot=(59,115),hand=(50,80),support=(44,81),guard=(54,80),tip=(75,38),near_elbow=(45,73),hair=-4,hem=-5),
 body(head=(43,59),shoulder=(42,73),hip=(43,89),far_knee=(33,103),far_foot=(28,115),near_knee=(54,102),near_foot=(60,115),hand=(53,84),support=(47,83),guard=(57,84),tip=(90,48),near_elbow=(48,76),hair=-2,hem=-3)],
'armored_recoil':[
 body(hand=(61,87),support=(54,86),guard=(65,87),tip=(104,61),near_elbow=(55,77),hair=-1,hem=0),
 body(head=(47,56),shoulder=(46,70),hand=(57,82),support=(50,82),guard=(61,82),tip=(92,43),near_elbow=(51,74),hair=-2,hem=1),
 body(head=(47,55),shoulder=(46,69),hand=(59,84),support=(52,84),guard=(63,84),tip=(98,48),near_elbow=(53,75),hair=-1,hem=1),
 body(hand=(63,89),support=(56,88),guard=(67,89),tip=(114,72),near_elbow=(57,79),hair=0,hem=0)],
'guard_break':[
 body(head=(46,61),shoulder=(45,75),hip=(45,91),far_knee=(34,105),far_foot=(31,115),near_knee=(57,105),near_foot=(64,115),hand=(61,95),support=(53,94),guard=(65,95),tip=(117,105),near_elbow=(54,85),hair=-2,hem=-2),
 body(head=(46,70),shoulder=(45,84),hip=(44,98),far_knee=(32,111),far_foot=(29,115),near_knee=(59,112),near_foot=(65,115),hand=(61,103),support=(53,102),guard=(65,103),tip=(116,111),near_elbow=(55,94),hair=-3,hem=-3),
 body(head=(48,80),shoulder=(47,94),hip=(44,104),far_knee=(32,113),far_foot=(28,115),near_knee=(60,114),near_foot=(67,115),hand=(62,110),support=(54,108),guard=(66,110),tip=(117,115),near_elbow=(56,102),hair=-2,hem=-2),
 body(head=(50,84),shoulder=(49,98),hip=(44,106),far_knee=(32,113),far_foot=(28,115),near_knee=(61,114),near_foot=(68,115),hand=(62,112),support=(55,110),guard=(66,112),tip=(118,115),near_elbow=(57,105),hair=-1,hem=-1)],
'hurt':[
 body(head=(45,57),shoulder=(44,71),hip=(45,88),hand=(58,94),support=(51,92),guard=(62,94),tip=(111,107),near_elbow=(53,83),hair=-2,hem=-2),
 body(head=(41,60),shoulder=(40,74),hip=(43,90),far_knee=(33,103),far_foot=(28,115),near_knee=(55,103),near_foot=(62,115),hand=(53,98),support=(47,94),guard=(57,98),tip=(105,115),near_elbow=(48,86),hair=-4,hem=-5),
 body(head=(43,59),shoulder=(42,73),hip=(44,89),far_knee=(35,102),far_foot=(31,115),hand=(55,96),support=(49,93),guard=(59,96),tip=(109,111),near_elbow=(50,84),hair=-3,hem=-3),
 body(head=(46,56),shoulder=(45,70),hip=(46,87),hand=(61,93),support=(54,91),guard=(65,93),tip=(117,100),near_elbow=(56,81),hair=-1,hem=-1)]}
# Recovery stages restore the anatomical support, with independent hand/clothing adjustments.
FAMILY['parry_recover']=[dict(FAMILY['parry_recoil'][3]),dict(FAMILY['parry_recoil'][1]),body(head=(46,56),shoulder=(45,70),hip=(45,87),hand=(60,88),support=(53,87),guard=(64,88),tip=(110,72),hair=-1,hem=-1),body()]
FAMILY['guard_recover']=[dict(FAMILY['guard_break'][3]),dict(FAMILY['guard_break'][1]),dict(FAMILY['guard_break'][0]),body(hand=(63,92),guard=(67,92),tip=(120,97),hair=1,hem=1)]
FAMILY['dead']=[dict(FAMILY['guard_break'][2]),body(head=(69,100),shoulder=(63,107),hip=(43,110),far_knee=(31,112),far_foot=(21,115),near_knee=(40,113),near_foot=(28,115),hand=(86,112),support=(77,112),guard=(90,112),tip=(123,114)),body(head=(74,105),shoulder=(64,110),hip=(43,111),far_knee=(30,113),far_foot=(20,115),near_knee=(39,114),near_foot=(27,115),hand=(89,113),support=(79,114),guard=(93,113),tip=(123,115)),body(head=(75,107),shoulder=(64,111),hip=(43,112),far_knee=(29,114),far_foot=(19,115),near_knee=(38,114),near_foot=(26,115),hand=(90,114),support=(79,115),guard=(94,114),tip=(123,115))]

def prone(pose,frame):
    # Explicit horizontal collapse drawings; no rotation of a standing frame.
    im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im)
    def poly(pts,key):d.polygon(pts,fill=P[key],outline=P['ink'])
    hx,hy=pose['head'];sx,sy=pose['shoulder'];px,py=pose['hip'];gx,gy=pose['guard'];tx,ty=pose['weapon_tip']
    poly([(20,111),(32,108),(48,106),(61,108),(65,114),(55,116),(27,116)],'cloth_dark')
    poly([(24,109),(37,106),(49,108),(47,112),(30,114),(18,115)],'wine')
    d.line([(24,111),(39,108),(47,110)],fill=P['wine_light'])
    for knee,foot in [(pose['far_knee'],pose['far_foot']),(pose['near_knee'],pose['near_foot'])]:
        d.line([(px,py),knee,foot],fill=P['ink'],width=7);d.line([(px,py),knee,foot],fill=P['armor'],width=5)
        fx,fy=foot;d.rectangle((fx-4,fy-2,fx+3,fy+1),fill=P['deep']);d.line([(fx-3,fy),(fx+2,fy)],fill=P['gold_dark'])
    poly([(px-4,py-6),(sx-2,sy-7),(sx+7,sy-2),(sx+5,sy+4),(px-3,py+4)],'deep')
    poly([(sx-5,sy-6),(sx+3,sy-5),(sx+6,sy),(sx-1,sy+3),(sx-7,sy+1)],'armor')
    d.line([(sx-4,sy-4),(sx+2,sy-3)],fill=P['gold'])
    poly([(hx-8,hy-4),(hx-3,hy-8),(hx+4,hy-6),(hx+8,hy-1),(hx+7,hy+4),(hx,hy+6),(hx-7,hy+3)],'hair_dark')
    poly([(hx-2,hy-4),(hx+4,hy-3),(hx+6,hy+1),(hx+3,hy+4),(hx-1,hy+2)],'skin')
    d.line([(hx+1,hy-1),(hx+4,hy)],fill=P['skin_shadow'])
    poly([(hx-8,hy-3),(hx-4,hy-6),(hx+2,hy-5),(hx-1,hy-2),(hx-3,hy+2),(hx-7,hy+1)],'silver')
    poly([(hx-8,hy),(hx-17,hy+2),(hx-23,hy+5),(hx-13,hy+6),(hx-7,hy+4)],'hair_dark')
    d.line([(hx-10,hy+2),(hx-18,hy+4)],fill=P['silver'])
    for hand in [pose['support'],pose['hand']]:
        d.line([(sx+1,sy-1),(hand[0]-7,hand[1]-2),hand],fill=P['ink'],width=6)
        d.line([(sx+1,sy-1),(hand[0]-7,hand[1]-2),hand],fill=P['armor'],width=4)
        d.rectangle((hand[0]-2,hand[1]-1,hand[0]+2,min(116,hand[1]+1)),fill=P['skin'])
    d.line([(gx-8,gy),(gx,gy)],fill=P['gold_dark'],width=2);d.line([(gx,gy-2),(gx,gy+2)],fill=P['gold'],width=1)
    d.line([(gx+1,gy),(tx,ty)],fill=P['steel'],width=2);d.line([(gx+1,gy-1),(tx,ty-1)],fill=P['edge'],width=1)
    return im

def make_family():
    frames=[];mapping={};qa=[]
    for state,count in STATES:
        poses=FAMILY[state];assert len(poses)==count,(state,len(poses),count)
        records=[];start=len(frames)
        for index,pose in enumerate(poses):
            im=prone(pose,index) if state=='dead' and index>0 else seed('A',pose,state,index)
            record={'name':f'{state}_{index:02d}','state':state,'frame':index,'progress':index/max(1,count-1),'hand':local(pose['hand']),'support_hand':local(pose['support']),'guard':local(pose['guard']),'weapon_tip':local(pose['weapon_tip']),'guard_point':local(pose['guard_point']),'hit_window':state in ['cut_a','cut_b'],'joints':{key:local(value) for key,value in pose.items() if isinstance(value,tuple)}}
            frames.append((state,index,im,record));records.append(record)
            alpha=im.getchannel('A');qa.append({'name':record['name'],'bbox':alpha.getbbox(),'colors':len({rgb[:3] for rgb in im.get_flattened_data() if rgb[3]}),'alpha_values':sorted(set(alpha.get_flattened_data())),'landmarks_in_bounds':all(0<=x<128 and 0<=y<128 for x,y in [pose['hand'],pose['guard'],pose['weapon_tip'],pose['guard_point']]),'no_cell_edge_clipping':alpha.getbbox()[0]>0 and alpha.getbbox()[1]>0 and alpha.getbbox()[2]<128 and alpha.getbbox()[3]<128,'sha256':hashlib.sha256(im.tobytes()).hexdigest()})
        mapping[state]={'start':start,'count':count,'frames':records}
    columns=8;atlas=Image.new('RGBA',(128*columns,128*math.ceil(len(frames)/columns)))
    for index,(_,_,im,_) in enumerate(frames):atlas.alpha_composite(im,((index%columns)*128,(index//columns)*128))
    atlas.save(OUT/'boss_atlas.png')
    for filename,color in [('boss_flash.png','#e8fff0'),('boss_silhouette.png','#73d7df')]:
        flash=Image.new('RGBA',atlas.size,color);flash.putalpha(atlas.getchannel('A'));flash.save(OUT/filename)
    manifest={'version':2,'status':'APPROVED_A_COMPLETE_KEYFRAME_FAMILY','license':'MIT','selected_candidate':'A','source':'Original integer-pixel joint/clothing/blade drawing in tools/generate_katana_boss.py; no imported image or 3D input.','canvas':[128,128],'anchor':list(ANCHOR),'columns':columns,'atlas':'boss_atlas.png','flash':'boss_flash.png','total_frames':len(frames),'states':mapping,'boss':{'canvas':[128,128],'anchor':list(ANCHOR),'columns':columns,'states':mapping,'total_frames':len(frames)},'pose_contract':{'method':'get_presentation_pose','fields':['state','progress','strike','armored','contact_serial'],'clock':'Actual controller stage; local freeze holds progress. No fixed animation seconds.','cut_contact':'cut_a/b frame 0 already spans local x=14..73 at y=-26..-18; draw owns anticipation.'},'constraints':{'antialias':False,'whole_frame_rotation':False,'native_scale':1,'max_colors':32,'alpha_values':[0,255]}}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    cut0={}
    for state in ['cut_a','cut_b']:
        pose=FAMILY[state][0];g=local(pose['guard']);tip=local(pose['weapon_tip']);image=seed('A',pose,state,0)
        blade_colors={tuple(bytes.fromhex(P[key][1:])) for key in ['steel','edge','white','gold','gold_light']}
        covered=[x for x in range(14,61) if any(image.getpixel((ANCHOR[0]+x,ANCHOR[1]+y))[:3] in blade_colors and image.getpixel((ANCHOR[0]+x,ANCHOR[1]+y))[3]==255 for y in range(-26,-17))]
        cut0[state]={'guard':g,'tip':tip,'covers_contact_x14_60':g[0]<=14 and tip[0]>=60,'blade_y_band':-26<=g[1]<=-18 and -26<=tip[1]<=-18,'actual_raster_contact_columns':len(covered),'expected_contact_columns':47}
    report={'frames':len(frames),'unique_frames':len({im.tobytes() for _,_,im,_ in frames}),'all_alpha_binary':all(q['alpha_values']==[0,255] for q in qa),'all_landmarks_in_bounds':all(q['landmarks_in_bounds'] for q in qa),'all_frames_no_clipping':all(q['no_cell_edge_clipping'] for q in qa),'max_frame_colors':max(q['colors'] for q in qa),'cut_first_frame':cut0,'states':{name:count for name,count in STATES},'frame_checks':qa}
    assert report['all_alpha_binary'] and report['all_landmarks_in_bounds'] and report['all_frames_no_clipping'] and report['max_frame_colors']<=32
    assert all(c['covers_contact_x14_60'] and c['blade_y_band'] and c['actual_raster_contact_columns']==47 for c in cut0.values())
    (OUT/'family-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    # Contact sheets have all authored frames, with native-pixel source and nearest-only previews.
    for filename,names in [('katana-motion-contact.png',['idle','approach','shift','draw','cut_a','cut_b','recover','cast']),('katana-reaction-contact.png',['parry_recoil','parry_recover','armored_recoil','guard_break','guard_recover','hurt','dead'])]:
        sheet=Image.new('RGB',(128*6+120,128*len(names)+26),'#101321');d=ImageDraw.Draw(sheet)
        for row,state in enumerate(names):
            d.text((3,36+row*128),state,fill=P['gold_light'])
            for index,pose in enumerate(FAMILY[state]):
                im=prone(pose,index) if state=='dead' and index>0 else seed('A',pose,state,index)
                sheet.paste(im,(120+index*128,22+row*128),im)
        sheet.save(OUT/filename)
    sample=[('idle',0),('draw',3),('cut_a',0),('cut_b',0),('parry_recoil',2),('armored_recoil',2),('guard_break',3),('dead',3)]
    sheet=Image.new('RGB',(256*4,256*2+48),'#101321');d=ImageDraw.Draw(sheet)
    for slot,(state,index) in enumerate(sample):
        pose=FAMILY[state][index];im=prone(pose,index) if state=='dead' and index>0 else seed('A',pose,state,index)
        im=im.resize((256,256),Image.Resampling.NEAREST);x=(slot%4)*256;y=(slot//4)*256+24
        sheet.paste(im,(x,y),im);d.text((x+6,y),f'{state} / {index}',fill=P['gold_light'])
    sheet.save(OUT/'katana-keyposes-2x.png')
    print(json.dumps({key:value for key,value in report.items() if key!='frame_checks'}))

def main():
    make_seeds()
    make_family()
if __name__=='__main__':main()
