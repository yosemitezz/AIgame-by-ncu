"""Static original-pixel contact sheets, never an input playback or playthrough."""
from pathlib import Path
import json, sys
from PIL import Image, ImageDraw
sys.path.insert(0,str(Path(__file__).resolve().parent))
import hero_rig as R
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/weapon-motion'
OUT.mkdir(parents=True,exist_ok=True)
SAMPLES=[('windup',0),('windup',3),('attack',0),('attack',2),('attack',4),('attack',7),('recover',0),('recover',3)]
CW,CH=144,154
sheet=Image.new('RGB',(CW*8,CH*9+32),'#11151f')
d=ImageDraw.Draw(sheet)
d.text((8,8),'NATIVE144x128 / ORIGIN feet66,108 / 2x NEAREST / scripted static poses',fill='#e2eaf6')
checks=[]
for wi,wid in enumerate(('light','heavy','great')):
    R.use_weapon(wid)
    for combo in (1,2,3):
        row=wi*3+combo-1
        for col,(phase,frame) in enumerate(SAMPLES):
            im,joints,tip=R.render(R.cut(combo,phase,frame))
            pos=(col*CW,32+row*CH+20)
            sheet.paste(im,pos,im)
            label=f'{wid} {combo} {phase[:3]}{frame}'
            d.text((col*CW+3,32+row*CH+3),label,fill='#b3c6dd')
            ax,ay=R.ANCHOR
            d.line((pos[0]+ax-3,pos[1]+ay,pos[0]+ax+3,pos[1]+ay),fill='#4a6884')
            bb=im.getchannel('A').getbbox()
            checks.append({'weapon':wid,'combo':combo,'phase':phase,'frame':frame,'bounds':bb,'inside':bool(bb and bb[0]>0 and bb[1]>0 and bb[2]<R.W and bb[3]<R.H)})
sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(OUT/'weapon-contact-sheet.png')
air=Image.new('RGB',(CW*8,CH*3+30),'#11151f'); d=ImageDraw.Draw(air)
d.text((8,7),'AIR FINISHERS / eight active frames, re-articulated free legs',fill='#e2eaf6')
for row,wid in enumerate(('light','heavy','great')):
    R.use_weapon(wid)
    for frame in range(8):
        im,_,_=R.render(R.cut(3,'attack',frame,True));pos=(frame*CW,30+row*CH+20)
        air.paste(im,pos,im);d.text((frame*CW+3,30+row*CH+3),f'{wid} air3 active{frame}',fill='#b3c6dd')
air.resize((air.width*2,air.height*2),Image.Resampling.NEAREST).save(OUT/'air-finisher-contact-sheet.png')
(OUT/'pose-audit.json').write_text(json.dumps({'original_procedural_pixels':True,'no_3d':True,'static_only':True,'samples':checks,'all_samples_inside':all(c['inside'] for c in checks)},indent=2)+'\n',encoding='utf8')
print('Static sheets saved:', OUT, 'all samples inside:',all(c['inside'] for c in checks))
