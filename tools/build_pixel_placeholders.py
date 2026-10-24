"""Original program-authored pixel placeholders; no rendered models or external art.
Run from project root. Pillow is used only to draw integer pixel clusters.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets' / 'art'
OUT = ROOT / 'artifacts'
STATES = ['idle','run','jump','fall','dash','attack','parry','hurt','dead','windup']
PAL = {'ink':'#101426','shadow':'#29334f','coat':'#416d86','cloth':'#5c9cab','light':'#b5e3db','mask':'#ecdfb0','gold':'#e9bb68','bright':'#fff1bd','cyan':'#72ece2','red':'#c25969','metal':'#788eaa','stone':'#3d4967'}

def hero(state, f, kind='hero'):
    im=Image.new('RGBA',(40,48)); d=ImageDraw.Draw(im)
    c=PAL.copy()
    if kind=='sentry': c.update(coat='#3d4967',cloth='#788eaa',light='#a9b6c8',mask='#bfcccd',cyan='#e9bb68')
    if kind=='elite': c.update(coat='#713f5d',cloth='#c25969',light='#e9bb68',mask='#fff1bd',cyan='#e9bb68')
    bob= -1 if state=='run' and f%3==1 else 0
    if state=='jump': bob=-2
    if state=='hurt': bob=1
    def p(points, fill, outline='ink'): d.polygon([(x,y+bob) for x,y in points],fill=c.get(fill,fill),outline=c.get(outline,outline))
    def r(box,fill): x,y,x2,y2=box; d.rectangle((x,y+bob,x2,y2+bob),fill=c.get(fill,fill))
    # Leading scarf and layered cape are recognizable at native 40x48 scale.
    trail=3+(f%3) if state in ('run','dash') else 1
    p([(14,18),(21,20),(19,33),(8-trail,35),(12,27),(10-trail,23)],'coat')
    r((11,23,13,29),'cloth'); r((9-trail,33,15,34),'light')
    stride=[-3,-1,3,4,1,-3][f] if state=='run' else 0
    if state in ('jump','fall','dash'): stride=3 if state!='fall' else -2
    p([(16,31),(21,31),(20-stride,41),(13-stride,42),(14-stride,39)],'shadow')
    p([(21,31),(26,31),(28+stride//2,42),(21+stride//2,42),(20,38)],'coat')
    r((12-stride,41,19-stride,43),'metal'); r((22+stride//2,42,29+stride//2,44),'metal')
    p([(15,19),(25,19),(27,30),(24,35),(16,34),(13,26)],'coat')
    r((17,21,19,30),'cloth'); r((17,31,25,32),'gold'); r((23,30,24,33),'bright')
    # Hood and a narrow pale visor, with a bright eye cluster.
    p([(15,9),(22,7),(28,12),(28,20),(24,23),(15,21),(12,17)],'shadow')
    p([(20,10),(26,12),(27,18),(23,21),(18,19),(17,14)],'mask')
    r((25,14,28,16),'ink'); r((25,14,26,14),'cyan'); r((14,12,16,17),'coat')
    p([(14,18),(18,19),(16,23),(10-trail,21),(5-trail,22),(8,18)],'cloth')
    r((12,19,16,20),'light')
    # Distinct hand-authored weapon poses: anticipation -> strike -> follow through.
    if state=='attack':
        poses=[([(25,25),(29,22),(26,17)],[(26,19),(23,8),(25,5),(29,18)]),
               ([(25,24),(29,20),(32,20)],[(31,21),(34,9),(36,7),(35,22)]),
               ([(25,24),(31,23),(32,26)],[(31,25),(38,19),(39,21),(34,28)]),
               ([(24,25),(30,28),(31,30)],[(30,29),(39,29),(39,32),(30,33)]),
               ([(24,25),(28,29),(29,31)],[(29,31),(35,39),(34,42),(26,33)]),
               ([(24,25),(27,27),(28,29)],[(28,29),(32,37),(30,39),(25,31)])]
        arm,blade=poses[f]; p(arm,'cloth'); p(blade,'light');
        if f in (2,3): d.line((33,18+bob,39,24+bob),fill=c['bright'],width=1)
    elif state in ('parry','windup'):
        p([(24,23),(28,20),(31,23),(26,27)],'cloth'); p([(27,25),(28,9),(30,6),(31,24)],'light'); r((25,23,33,24),'gold')
        if state=='parry': p([(30,12),(33,16),(30,20),(27,16)],'cyan')
    else:
        p([(24,22),(28,26),(27,30),(24,28)],'cloth'); p([(28,28),(36,36),(35,39),(26,30)],'metal'); r((26,28,29,30),'gold')
    if state=='hurt':
        for x,y in [(31,9),(8,16),(33,25)]: d.rectangle((x,y,x+1,y+1),fill=c['red'])
    if state=='dead':
        im=im.transpose(Image.Transpose.ROTATE_90).resize((40,48),Image.Resampling.NEAREST)
        a=im.getchannel('A').point(lambda v: int(v*(1-f/8)))
        im.putalpha(a)
    return im

def boss(state,f):
    im=Image.new('RGBA',(80,80)); d=ImageDraw.Draw(im); c=PAL
    bob=-1 if f%3==1 else 0
    def p(points,fill,outline='ink'): d.polygon([(x,y+bob) for x,y in points],fill=c.get(fill,fill),outline=c.get(outline,outline))
    def r(box,fill): x,y,x2,y2=box; d.rectangle((x,y+bob,x2,y2+bob),fill=c.get(fill,fill))
    p([(22,26),(47,23),(57,44),(63,72),(45,69),(28,75),(14,69),(20,49)],'red')
    p([(25,31),(48,29),(52,57),(45,66),(25,68),(20,55)],'shadow')
    r((23,38,25,60),'gold'); r((50,41,52,63),'gold')
    stride=3 if state=='run' and f%2 else -2
    p([(29,54),(37,54),(36-stride,72),(24-stride,75),(22-stride,72)],'metal')
    p([(39,54),(47,53),(53+stride,73),(43+stride,75),(40,65)],'metal')
    r((25-stride,72,33-stride,74),'light'); r((44+stride,72,52+stride,74),'gold')
    p([(25,29),(47,29),(51,42),(47,56),(29,59),(24,46)],'stone')
    p([(32,33),(40,29),(45,36),(42,50),(35,55),(29,46)],'metal')
    r((35,36,38,49),'gold'); r((30,53,46,55),'gold')
    p([(21,29),(28,26),(33,31),(29,38),(20,38),(17,34)],'gold')
    p([(45,28),(52,26),(59,32),(56,39),(46,38),(42,33)],'gold')
    p([(31,12),(44,11),(50,19),(47,30),(39,35),(30,28),(27,20)],'metal')
    p([(34,14),(43,14),(46,20),(43,29),(37,31),(32,25)],'mask')
    r((38,18,40,26),'ink'); r((38,18,40,19),'bright')
    p([(30,16),(24,10),(23,2),(28,5),(29,10),(34,12),(37,8),(40,12),(47,11),(53,2),(56,4),(53,13),(47,18)],'gold')
    r((25,4,26,9),'bright'); r((50,8,52,10),'bright')
    if state in ('attack','windup'):
        # Halberd sweeps horizontally during active frames; anticipation stays high.
        if state=='windup' or f<2:
            p([(50,37),(58,30),(62,32),(56,42)],'metal'); r((59,6,61,60),'gold')
            p([(57,7),(63,5),(70,10),(63,17),(58,15)],'light')
        else:
            p([(49,37),(58,39),(61,42),(53,45)],'metal'); r((44,39,77,41),'gold')
            p([(68,34),(77,32),(78,40),(74,49),(69,44)],'light')
    else:
        p([(50,37),(57,46),(55,51),(49,45)],'metal'); r((59,24,61,75),'gold')
        p([(57,23),(62,21),(69,28),(63,35),(58,32)],'light')
    if state=='hurt': r((30,15,33,25),'bright')
    if state=='dead': im.putalpha(im.getchannel('A').point(lambda v:int(v*(1-f/8))))
    return im

def wisp(state,f):
    im=Image.new('RGBA',(40,48));d=ImageDraw.Draw(im);y=f%3
    d.polygon([(19,7+y),(27,15+y),(25,28+y),(20,36+y),(12,29+y),(10,18+y)],fill=PAL['ink'])
    d.polygon([(19,11+y),(24,17+y),(23,25+y),(19,30+y),(14,25+y),(14,17+y)],fill=PAL['gold'])
    d.rectangle((17,17+y,21,22+y),fill=PAL['bright']);d.rectangle((14,28+y,17,31+y),fill=PAL['cyan'])
    d.line([(19,8+y),(20,4+y),(24,3+y)],fill=PAL['metal'],width=2)
    return im

def main():
    ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    report={}
    for kind in ['hero','sentry','elite','wisp','boss']:
        size=80 if kind=='boss' else 40;h=80 if kind=='boss' else 48
        atlas=Image.new('RGBA',(size*6,h*len(STATES)))
        for row,state in enumerate(STATES):
            for f in range(6):
                frame=boss(state,f) if kind=='boss' else wisp(state,f) if kind=='wisp' else hero(state,f,kind)
                atlas.alpha_composite(frame,(f*size,row*h))
        atlas.save(ART/f'placeholder_{kind}.png')
        report[kind]={'size':list(atlas.size),'frame':[size,h],'frames_per_state':6,'states':STATES,'colors':len(set(atlas.getdata())),'source':'original integer pixel drawing in tools/build_pixel_placeholders.py','license':'MIT'}
        # Contact sheets remain local review evidence, not shipped art assets.
        sheet=Image.new('RGB',(size*12+110,h*len(STATES)*2+36),'#0c1025');sd=ImageDraw.Draw(sheet)
        sheet.paste(atlas.resize((size*12,h*len(STATES)*2),Image.Resampling.NEAREST),(100,30),atlas.resize((size*12,h*len(STATES)*2),Image.Resampling.NEAREST))
        sd.text((8,8),kind.upper()+' / ORIGINAL PIXEL PLACEHOLDER',fill='#e9bb68')
        for row,state in enumerate(STATES):sd.text((5,36+row*h*2),state,fill='#a1adc9')
        sheet.save(OUT/f'contact_{kind}.png')
    (ART/'placeholder_manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:{'size':v['size'],'colors':v['colors']} for k,v in report.items()}))
if __name__=='__main__':main()
