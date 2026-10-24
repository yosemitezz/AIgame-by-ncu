"""Original Bellkeep enemy cast: six distinct integer-pixel silhouettes and articulated key poses.
All source is editable geometry in this file. No commercial sprite, rendered model, scaling,
whole-frame rotations, network call or outside bitmap is used. Outputs stay beside the project on D.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import math,json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'presentation/enemy_frames'
CELL=80;ANCHOR=(40,76)
KINDS=['sentry','wisp','elite','lantern','jailer','bat']
STATES=['idle','run','windup','attack','recover','hurt','parry','dead']
P={'ink':'#141725','deep':'#242b3b','slate':'#49566b','steel':'#8193a3','edge':'#c6d7d9',
'bone':'#d5cda9','bone_hi':'#f3e5bd','rust':'#97715a','gold':'#bd925c','gold_hi':'#f4b95f',
'cloth':'#493b55','fold':'#7b6179','wine':'#854e61','teal':'#4e8c9e','water':'#81c4ca','water_hi':'#d4f5da',
'violet':'#8860aa','wing':'#4f405f','wing_hi':'#b58fca','pink':'#e59bff','seed':'#c69aff','lime':'#cce675','black':'#20232c'}

def canvas():
 im=Image.new('RGBA',(CELL,CELL));d=ImageDraw.Draw(im)
 def poly(points,c,outline='ink'):d.polygon([(round(x),round(y)) for x,y in points],fill=P.get(c,c),outline=P.get(outline,outline))
 def line(points,c,w=1):d.line([(round(x),round(y)) for x,y in points],fill=P.get(c,c),width=w)
 def rect(box,c):d.rectangle(tuple(round(v) for v in box),fill=P.get(c,c))
 def limb(a,b,w,c):
  dx=b[0]-a[0];dy=b[1]-a[1];dist=max(1,math.hypot(dx,dy));nx=-dy/dist*w*.5;ny=dx/dist*w*.5
  poly([(a[0]+nx,a[1]+ny),(b[0]+nx,b[1]+ny),(b[0]-nx,b[1]-ny),(a[0]-nx,a[1]-ny)],c)
 return im,d,poly,line,rect,limb

def pose(state,f):
 lean={'idle':[0,0,1,0],'run':[1,2,1,0],'windup':[0,-1,-2,-3],'attack':[2,3,2,0],'recover':[2,1,0,-1],'hurt':[0,-2,-3,-1],'parry':[0,-1,-2,-1],'dead':[0,0,0,0]}[state][f]
 crouch={'idle':[0,1,0,0],'run':[0,1,0,1],'windup':[0,1,2,2],'attack':[1,0,1,2],'recover':[2,1,0,0],'hurt':[0,1,2,1],'parry':[1,2,2,1],'dead':[0,0,0,0]}[state][f]
 left=(33,75);right=(47,75);lk=(34,66);rk=(45,66)
 if state=='run':
  left,right,lk,rk=[((28,75),(50,72),(32,65),(47,63)),((38,75),(45,68),(35,68),(47,61)),((50,72),(28,75),(47,63),(32,65)),((45,68),(38,75),(47,61),(35,68))][f]
 elif state in ['windup','attack','parry']:
  left=(29,75);right=(50,75);lk=(32,67+crouch);rk=(47,66+crouch)
 angles={'idle':[-20,-18,-15,-20],'run':[10,16,5,-1],'windup':[-66,-90,-116,-130],'attack':[-8,12,28,40],'recover':[42,28,8,-15],'hurt':[50,65,80,55],'parry':[-30,-75,-104,-60]}
 angle=angles.get(state,[0,0,0,0])[f]
 return dict(lean=lean,crouch=crouch,left=left,right=right,lk=lk,rk=rk,angle=angle)

def dead(kind,f):
 im,d,poly,line,rect,limb=canvas();y=60+f*4
 if kind=='wisp':
  r=[10,13,17,21][f];poly([(40-r,73),(33,69+f),(40,70),(47,68+f),(40+r,73),(48,75),(31,75)],'teal')
  for j in range(4):rect((28+j*7,69+f%2,29+j*7,70+f%2),'water')
 elif kind=='bat':
  spread=[23,19,16,13][f];poly([(40-spread,65+f*2),(32,69),(39,67+f),(43,69),(49,67),(40+spread,66+f*2),(51,75),(41,73),(31,75)],'wing')
  poly([(38,69+f),(45,70+f),(46,74),(40,75),(36,73)],'violet');rect((42,71+f//2,43,71+f//2),'pink')
 else:
  if kind=='sentry':
   poly([(31,y),(37,y-2),(42,y+1),(42,min(74,y+7)),(35,min(75,y+9)),(31,min(74,y+4))],'bone')
   rect((34,y+2,35,y+3),'ink');rect((39,y+2,40,y+3),'ink')
   for j in range(4):line([(24+j*9,73-f%2),(30+j*9,74)],'bone',2)
   line([(48,72),(69,74)],'steel',2)
  elif kind=='elite':
   poly([(27,70),(31,62+f*2),(47,64+f),(55,73),(50,76),(29,76)],'deep')
   poly([(32,63+f*2),(44,64+f),(47,72),(37,75),(29,71)],'steel')
   poly([(48,65+f),(56,66+f),(59,72),(53,75),(47,72)],'slate');line([(23,74),(68,74)],'rust',2)
  elif kind=='lantern':
   poly([(26,74),(34,57+f*4),(42,55+f*4),(51,72),(58,75)],'cloth');poly([(34,57+f*4),(42,58+f*3),(45,67+f*2),(37,69+f),(31,65+f*2)],'fold')
   rect((55,68,63,75),'deep');rect((57,70,61,73),'gold_hi');rect((58,70,59,71),'bone_hi')
  else:
   poly([(26,68+f),(32,61+f*3),(48,63+f*2),(55,74),(48,76),(28,76)],'deep')
   rect((28,62+f*2,49,66+f*2),'slate');line([(22,71),(27,74),(34,71),(41,74),(47,71),(56,74),(63,71)],'steel',2)
   rect((35,67+f,40,70+f),'lime')
 return im,{'hand':None,'weapon_tip':None,'guard_point':None}

def draw(kind,state,f):
 if state=='dead':return dead(kind,f)
 im,d,poly,line,rect,limb=canvas();q=pose(state,f);lean=q['lean'];c=q['crouch'];sx=40+lean;sy=49+c;hip=(40,62+c)
 hand=(50+lean,57+c);tip=None;guard=None
 if kind=='sentry':
  # Exposed jointed bones and ribs, round rusted buckler, chipped straight sword.
  for knee,foot,x in [(q['lk'],q['left'],37),(q['rk'],q['right'],43)]:
   line([(x,62+c),knee,foot],'ink',4);line([(x,62+c),knee,foot],'bone',2);rect((knee[0]-1,knee[1]-1,knee[0]+1,knee[1]+1),'rust');line([(foot[0]-2,foot[1]),(foot[0]+3,foot[1])],'bone_hi',2)
  poly([(sx-5,sy-2),(sx+5,sy-2),(sx+6,sy+7),(sx+3,62+c),(sx-4,62+c),(sx-6,sy+6)],'deep')
  line([(sx,sy),(40,61+c)],'bone',2)
  for rib in range(3):line([(sx-4,sy+1+rib*3),(sx,sy+2+rib*3),(sx+4,sy+1+rib*3)],'bone',1)
  poly([(sx-5,sy-11),(sx-2,sy-14),(sx+5,sy-13),(sx+7,sy-8),(sx+5,sy-3),(sx-3,sy-3),(sx-6,sy-7)],'bone')
  rect((sx-3,sy-9,sx-1,sy-7),'ink');rect((sx+3,sy-9,sx+5,sy-7),'ink');rect((sx,sy-5,sx+1,sy-4),'rust')
  shield=(sx-11-(f%2),sy+7);d.ellipse((shield[0]-7,shield[1]-8,shield[0]+7,shield[1]+8),fill=P['rust'],outline=P['ink']);d.ellipse((shield[0]-5,shield[1]-6,shield[0]+5,shield[1]+6),fill=P['slate']);rect((shield[0]-1,shield[1]-2,shield[0]+1,shield[1]+2),'steel')
  elbow=(sx+7,sy+5-c);limb((sx+4,sy+1),elbow,3,'bone');limb(elbow,hand,3,'bone')
  a=math.radians(q['angle']);blade_length=17 if state=='hurt' else 23;end=(hand[0]+math.cos(a)*blade_length,hand[1]+math.sin(a)*blade_length);n=(-math.sin(a),math.cos(a))
  line([hand,end],'ink',3);line([hand,end],'steel',2);line([(hand[0]+n[0],hand[1]+n[1]),end],'edge');line([(hand[0]+n[0]*3,hand[1]+n[1]*3),(hand[0]-n[0]*3,hand[1]-n[1]*3)],'rust',2);tip=end;guard=hand
 elif kind=='elite':
  # Square iron mass with separate knees, high shield and a long single-bladed axe.
  sy=43+c;hip=(40,61+c);hand=(51+lean,56+c)
  for knee,foot,x in [(q['lk'],q['left'],35),(q['rk'],q['right'],45)]:
   limb((x,62+c),knee,7,'deep');limb(knee,foot,6,'slate');rect((foot[0]-4,foot[1]-3,foot[0]+5,foot[1]),'steel')
  poly([(sx-10,sy-1),(sx+8,sy-1),(sx+12,sy+9),(45,64+c),(34,64+c),(sx-12,sy+9)],'deep')
  poly([(sx-6,sy+2),(sx+4,sy+2),(sx+8,sy+11),(42,61+c),(35,61+c),(sx-8,sy+9)],'steel');line([(sx,sy+3),(40,60+c)],'gold',2)
  poly([(sx-15,sy-2),(sx-8,sy-5),(sx-3,sy+2),(sx-9,sy+9),(sx-17,sy+5)],'slate');poly([(sx+5,sy-3),(sx+12,sy-4),(sx+17,sy+3),(sx+12,sy+8),(sx+4,sy+5)],'slate')
  poly([(sx-6,sy-13),(sx+4,sy-14),(sx+8,sy-8),(sx+5,sy-2),(sx-6,sy-2),(sx-9,sy-8)],'slate');line([(sx-3,sy-8),(sx+5,sy-8)],'gold_hi',1)
  poly([(sx-17,sy+6),(sx-8,sy+4),(sx-5,sy+23),(sx-12,sy+27),(sx-20,sy+19)],'slate');line([(sx-13,sy+8),(sx-11,sy+22)],'gold')
  elbow=(sx+9,sy+12);limb((sx+7,sy+4),elbow,6,'slate');limb(elbow,hand,5,'deep')
  angle=q['angle']-36 if state!='attack' else q['angle']-25;a=math.radians(angle);end=(hand[0]+math.cos(a)*17,hand[1]+math.sin(a)*17);n=(-math.sin(a),math.cos(a))
  line([hand,end],'ink',4);line([hand,end],'rust',2)
  poly([(end[0]-n[0]*6,end[1]-n[1]*6),(end[0]+n[0]*8,end[1]+n[1]*8),(end[0]+math.cos(a)*6+n[0]*5,end[1]+math.sin(a)*6+n[1]*5),(end[0]+math.cos(a)*7-n[0]*3,end[1]+math.sin(a)*7-n[1]*3)],'steel');tip=end;guard=hand
 elif kind=='lantern':
  # Tall narrow hood, split robe and a freely swinging caged lamp; no skeleton/armor reuse.
  sy=42+c;head=(sx,sy-7);swing=[-3,0,3,1][f]
  poly([(sx-6,sy),(sx+6,sy),(sx+10,sy+17),(sx+13,74),(sx+4,73),(sx,67),(sx-4,75),(sx-13,75),(sx-9,sy+17)],'cloth')
  poly([(sx-4,sy+4),(sx,sy+5),(sx-1,70),(sx-7,73),(sx-6,sy+13)],'fold');line([(sx+3,sy+5),(sx+7,72)],'gold')
  poly([(sx-7,sy-7),(sx-2,sy-14),(sx+5,sy-10),(sx+9,sy-3),(sx+6,sy+4),(sx-5,sy+3),(sx-9,sy-1)],'fold')
  poly([(sx-3,sy-7),(sx+3,sy-6),(sx+5,sy),(sx-3,sy)],'ink');rect((sx,sy-4,sx+3,sy-4),'gold_hi')
  hand=(52+lean,52+c);lamp=(60+swing+lean,64+c)
  if state=='windup':hand=(49+lean,50-f*2);lamp=(57+swing+lean,60-f*2)
  elif state=='attack':hand=(56+lean,52+c);lamp=(65+swing+lean,61+c-f)
  elif state=='parry':hand=(49+lean,49+c);lamp=(56+swing,60+c)
  limb((sx+5,sy+5),(sx+9,sy+12),5,'deep');limb((sx+9,sy+12),hand,4,'fold');rect((hand[0]-1,hand[1]-1,hand[0]+1,hand[1]+1),'bone')
  lx,ly=lamp;line([hand,(lx,ly-8)],'gold');d.arc((lx-4,ly-10,lx+4,ly-4),180,360,fill=P['steel'],width=1)
  poly([(lx-5,ly-6),(lx+4,ly-6),(lx+5,ly+4),(lx-4,ly+4)],'deep');rect((lx-3,ly-4,lx+2,ly+2),'gold_hi');poly([(lx-1,ly+1),(lx-2,ly-1),(lx,ly-5),(lx+1,ly-1)],'bone_hi');line([(lx-2,ly-4),(lx-2,ly+2)],'rust');line([(lx+1,ly-4),(lx+1,ly+2)],'rust');tip=(lx,ly);guard=hand
 elif kind=='jailer':
  # Broad iron stocks, staggered shackles and a visibly segmented chain ending in an iron weight.
  sy=45+c;hand=(52+lean,57+c)
  for knee,foot,x in [(q['lk'],q['left'],35),(q['rk'],q['right'],46)]:
   limb((x,61+c),knee,7,'deep');limb(knee,foot,5,'slate');rect((foot[0]-3,foot[1]-3,foot[0]+4,foot[1]),'slate')
  poly([(sx-10,sy),(sx+7,sy),(sx+11,sy+16),(43,65+c),(32,64+c),(sx-12,sy+12)],'deep');rect((sx-7,sy+4,sx+4,sy+12),'slate');line([(sx-4,sy+6),(sx+2,sy+10)],'rust',2)
  poly([(sx-6,sy-12),(sx+3,sy-13),(sx+7,sy-6),(sx+4,sy-2),(sx-5,sy-3),(sx-8,sy-8)],'rust');rect((sx-3,sy-8,sx+3,sy-7),'lime')
  poly([(sx-16,sy-3),(sx+12,sy-4),(sx+15,sy+3),(sx-17,sy+5)],'slate');rect((sx-11,sy-2,sx-8,sy+2),'ink');rect((sx+5,sy-2,sx+8,sy+2),'ink');line([(sx-15,sy+3),(sx+12,sy+1)],'steel')
  limb((sx+7,sy+6),(sx+10,sy+11),6,'slate');limb((sx+10,sy+11),hand,5,'deep');rect((hand[0]-3,hand[1]-2,hand[0]+3,hand[1]+2),'steel')
  end=(66+f%2,67+c)
  if state=='windup':end=[(63,48),(59,38),(48,32),(41,34)][f]
  elif state=='attack':end=[(73,56),(74,59),(72,64),(69,68)][f]
  elif state=='parry':end=(55-f*2,44+f)
  for j in range(7):
   t=j/6;x=hand[0]+(end[0]-hand[0])*t;y=hand[1]+(end[1]-hand[1])*t+math.sin(t*math.pi)*(6 if state!='attack' else 2)
   if j%2:d.ellipse((round(x)-2,round(y)-1,round(x)+2,round(y)+1),outline=P['steel'])
   else:rect((x-1,y-2,x+1,y+2),'slate');rect((x,y-1,x,y+1),'ink')
  ex,ey=end;poly([(ex-3,ey-4),(ex+3,ey-3),(ex+4,ey+2),(ex,ey+5),(ex-4,ey+2)],'slate');rect((ex-1,ey-2,ex+1,ey+1),'lime');tip=end;guard=hand
 elif kind=='wisp':
  # Floating water lantern: shifting drop silhouette and three separately curling streamers.
  cy=58+[0,-2,0,1][f]+c//2;cx=40+lean
  if state=='windup':cy-=f;cx-=1
  spread=7+(f%2)*2+(3 if state=='attack' else 0)
  poly([(cx,cy-18),(cx+4,cy-10),(cx+spread,cy-4),(cx+9,cy+5),(cx+4,cy+12),(cx-5,cy+12),(cx-10,cy+4),(cx-spread,cy-5),(cx-4,cy-10)],'teal')
  poly([(cx,cy-12),(cx+4,cy-6),(cx+5,cy+2),(cx+1,cy+7),(cx-5,cy+3),(cx-6,cy-3)],'water')
  rect((cx-4,cy-3,cx-2,cy-2),'deep');rect((cx+2,cy-3,cx+4,cy-2),'deep');rect((cx,cy,cx+1,cy+2),'water_hi')
  for j in range(3):
   x=cx-8+j*8;endx=x+[[-5,0,5,2],[4,6,0,-4],[0,-4,-6,3]][j][f];endy=min(74,cy+14+(j%2)*3)
   poly([(x-2,cy+5),(x+2,cy+5),(endx+2,endy-3),(endx,endy),(endx-3,endy-2),(x-3,cy+10)],'teal');line([(x,cy+7),(endx,endy-2)],'water')
  if state in ['windup','attack','parry']:
   extent=[12,15,18,14][f];poly([(cx+extent,cy-3),(cx+extent+3,cy),(cx+extent,cy+3),(cx+extent-3,cy)],'water_hi')
  hand=(cx+8,cy);tip=(cx+16+(f%2)*3,cy);guard=hand
 else:
  # V/W membrane cycle, long fingers and a compact horned demon core; wings are decoration.
  cy=58+[0,-2,0,1][f]+c//2;cx=40+lean
  wing=[((13,37),(18,57),(27,48)),((10,48),(14,64),(25,56)),((14,66),(20,72),(28,61)),((11,47),(15,59),(26,53))][f]
  if state=='windup':wing=[((18,46),(22,62),(29,53)),((24,43),(22,61),(30,52)),((27,44),(25,62),(31,53)),((28,42),(25,61),(31,51))][f]
  for sign in [-1,1]:
   def w(pt):return(cx+sign*(40-pt[0]),cy+pt[1]-58)
   a,b,inner=[w(pt) for pt in wing]
   poly([(cx+sign*5,cy-4),a,b,inner,(cx+sign*6,cy+7)],'wing')
   line([(cx+sign*4,cy-2),a,b],'wing_hi',1);line([a,inner],'violet')
  poly([(cx-5,cy-8),(cx-7,cy-14),(cx-1,cy-10),(cx+2,cy-10),(cx+7,cy-14),(cx+5,cy-6),(cx+8,cy),(cx+4,cy+10),(cx-4,cy+10),(cx-8,cy)],'violet')
  rect((cx-4,cy-3,cx-2,cy-2),'gold_hi');rect((cx+2,cy-3,cx+4,cy-2),'gold_hi');line([(cx-2,cy+2),(cx+2,cy+2)],'deep')
  line([(cx-3,cy+8),(cx-5-f%2,min(74,cy+14))],'steel',2);line([(cx+3,cy+8),(cx+5+f%2,min(74,cy+14))],'steel',2)
  hand=None;tip=(cx+6,cy-2);guard=None
 return im,{'hand':hand,'weapon_tip':tip,'guard_point':guard}

def local(p):return [round(p[0])-40,round(p[1])-76] if p else None

def main():
 OUT.mkdir(parents=True,exist_ok=True);manifest={'version':1,'license':'MIT','source':'Original integer-pixel geometry and pose tables in tools/generate_enemy_cast.py. No outside images or 3D.','canvas':[80,80],'anchor':list(ANCHOR),'columns':4,'kinds':{},'states':STATES,'runtime_states':['idle','run','windup','attack','recover','hurt','dead'],'phase_contract':{'windup':'windup','release':'attack','recover':'recover'},'constraints':{'alpha':[0,255],'native_scale':1,'whole_frame_rotation':False,'filter':'nearest'}};checks={};contact=Image.new('RGB',(6*320+90,8*160+40),'#111523');cd=ImageDraw.Draw(contact)
 for column,kind in enumerate(KINDS):
  atlas=Image.new('RGBA',(320,640));records={};hashes=set();all_colors=set();frame_meta=[]
  for row,state in enumerate(STATES):
   per=[]
   for f in range(4):
    im,points=draw(kind,state,f);atlas.alpha_composite(im,(f*80,row*80));hashes.add(hashlib.sha256(im.tobytes()).hexdigest());colors={rgb[:3] for rgb in im.get_flattened_data() if rgb[3]};all_colors|=colors
    record={'name':f'{kind}_{state}_{f:02d}','frame':f,'progress':f/3,'body_bbox':list(im.getbbox()),'hurt_center':[0,-16 if kind in ['wisp','bat'] else -18],**{name:local(value) for name,value in points.items()}};per.append(record);frame_meta.append(record)
    for key,value in points.items():
     assert value is None or (0<=round(value[0])<80 and 0<=round(value[1])<80),(kind,state,f,key,value)
    assert set(im.getchannel('A').get_flattened_data())<={0,255}
    box=im.getbbox();assert box[0]>0 and box[1]>0 and box[2]<80 and box[3]<80,(kind,state,f,'clipped',box)
   records[state]={'start':row*4,'count':4,'frames':per,'optional':state=='parry'}
   if column==0:cd.text((4,45+row*160),state,fill=P['gold_hi'])
   # Two key poses per row at 2x show every state and independent four-frame strips stay in assets.
   for j,f in enumerate([0,2]):
    im,_=draw(kind,state,f);large=im.resize((160,160),Image.Resampling.NEAREST);contact.paste(large,(90+column*320+j*160,28+row*160),large)
  atlas.save(OUT/f'{kind}_atlas.png');flash=Image.new('RGBA',atlas.size,'#e7f4d7');flash.putalpha(atlas.getchannel('A'));flash.save(OUT/f'{kind}_flash.png')
  # Full-frame individual native contact sheets are readable without playing the game.
  sheet=Image.new('RGB',(100+4*160,24+8*160),'#111523');sd=ImageDraw.Draw(sheet)
  for row,state in enumerate(STATES):
   sd.text((4,34+row*160),state,fill=P['gold_hi'])
   for f in range(4):
    im,_=draw(kind,state,f);large=im.resize((160,160),Image.Resampling.NEAREST);sheet.paste(large,(100+f*160,24+row*160),large)
  sheet.save(OUT/f'{kind}_contact.png')
  manifest['kinds'][kind]={'atlas':f'{kind}_atlas.png','flash':f'{kind}_flash.png','states':records,'flying':kind in ['wisp','bat'],'total_frames':32}
  checks[kind]={'frames':32,'unique_frames':len(hashes),'opaque_palette_colors':len(all_colors),'all_landmarks_in_bounds':True,'alpha_binary':True,'atlas_sha256':hashlib.sha256(atlas.tobytes()).hexdigest()}
  assert len(hashes)>=24 and len(all_colors)<=32,(kind,checks[kind])
  cd.text((94+column*320,8),kind.upper(),fill=P['gold_hi'])
 contact.save(OUT/'cast-contact.png')
 silhouettes=Image.new('RGB',(6*160,190),'#111523');sd=ImageDraw.Draw(silhouettes)
 for i,kind in enumerate(KINDS):
  im,_=draw(kind,'idle',0);white=Image.new('RGBA',im.size,'#e1e9da');white.putalpha(im.getchannel('A'));white=white.resize((160,160),Image.Resampling.NEAREST);silhouettes.paste(white,(i*160,25),white);sd.text((i*160+8,7),kind.upper(),fill=P['gold_hi'])
 silhouettes.save(OUT/'cast-silhouettes.png')
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8');(OUT/'asset-report.json').write_text(json.dumps({'total_frames':192,'kinds':checks},indent=2)+'\n',encoding='utf-8');print(json.dumps(checks))
if __name__=='__main__':main()
