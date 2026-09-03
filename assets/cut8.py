from PIL import Image
import numpy as np, os
im=Image.open('iconsheet.webp').convert('RGB')
A=np.asarray(im).astype(int)
BANDS=[(55,259),(384,590),(706,904)]
COLS=[[(40,220),(258,436),(474,645),(680,852),(888,1055),(1092,1257),(1293,1460)],
      [(41,215),(256,432),(472,643),(680,848),(887,1052),(1090,1256),(1296,1461)],
      [(27,192),(224,394),(421,584),(609,766),(790,957),(981,1142),(1167,1324),(1347,1510)]]
NAMES=[['sh_audit','review','k1118','bank','ai_dots','tax_check','bulb'],
       ['calendar','megaphone','aud_doc','folder_doc','fin_won','ai_brain','tax_pie'],
       ['shield_ins','cloud_its','doc_ftn','bell','robot','report','dashboard','memo']]
os.makedirs('icons',exist_ok=True)
SS=4
LUM=lambda c: .299*c[...,0]+.587*c[...,1]+.114*c[...,2]
def rounded(n, r=.23):                     # 정사각형 + 둥근 모서리
    N=n*SS; R=r*N
    y,x=np.mgrid[0:N,0:N]+.5
    dx=np.maximum(np.maximum(R-x, x-(N-R)),0)
    dy=np.maximum(np.maximum(R-y, y-(N-R)),0)
    m=((dx*dx+dy*dy)<=R*R).astype(float)
    return (m.reshape(n,SS,n,SS).mean(axis=(1,3))*255).astype('uint8')
def span(count, frac=.45):
    idx=np.where(count>=count.max()*frac)[0]; return idx.min(), idx.max()
def tile_box(x0,x1,y0,y1):
    sub=A[y0:y1+1, x0:x1+1]
    mx=sub.max(axis=2); mn=sub.min(axis=2); sat=mx-mn
    strong=(sat>55)|(mn<130)
    dw,dh=x1-x0+1,y1-y0+1
    if strong.sum() > .22*dw*dh:
        cx0,cx1=span(strong.sum(axis=0)); cy0,cy1=span(strong.sum(axis=1))
    else:
        light=(mn<236)
        cx0,cx1=span(light.sum(axis=0),.6); cy0,cy1=span(light.sum(axis=1),.6)
    side=max(cx1-cx0+1, cy1-cy0+1); cx,cy=(cx0+cx1)/2,(cy0+cy1)/2
    return x0+int(round(cx-side/2)), y0+int(round(cy-side/2)), int(side)
def bandmed(box, lo, hi):                  # 테두리에서 lo~hi 픽셀 깊이 띠의 밝기 중앙값
    S=box.shape[0]; L=LUM(box)
    sel=np.zeros((S,S),bool)
    sel[lo:hi, lo:S-lo]=True; sel[S-hi:S-lo, lo:S-lo]=True
    sel[lo:S-lo, lo:hi]=True; sel[lo:S-lo, S-hi:S-lo]=True
    return np.median(L[sel])
boxes={}
for bi,(y0,y1) in enumerate(BANDS):
    for ci,(x0,x1) in enumerate(COLS[bi]): boxes[(bi,ci)]=tile_box(x0,x1,y0,y1)
med=sorted(s for _,_,s in boxes.values())[len(boxes)//2]
for (bi,ci),(L,T,S) in list(boxes.items()):
    if S < .8*med:
        x0,x1=COLS[bi][ci]; y0,y1=BANDS[bi]
        S=med; L=int(round((x0+x1)/2-S/2)); T=y0
        boxes[(bi,ci)]=(L,T,S)
out=[]
for bi,(y0,y1) in enumerate(BANDS):
    for ci,(x0,x1) in enumerate(COLS[bi]):
        L,T,S=boxes[(bi,ci)]
        for k in range(0,13):                       # 밝은 베젤이 사라질 때까지 최대 12%
            ins=int(round(S*k/100))
            box=A[T+ins:T+S-ins, L+ins:L+S-ins]
            if box.shape[0]<60: break
            ring=bandmed(box,1,4); ref=bandmed(box,12,22)
            if ring-ref < 14: break
        L+=ins; T+=ins; S-=2*ins
        tile=Image.fromarray(A[T:T+S, L:L+S].astype('uint8'),'RGB').resize((160,160),Image.LANCZOS)
        tile.putalpha(Image.fromarray(rounded(160),'L'))
        name=NAMES[bi][ci]
        tile.convert('RGBA').quantize(colors=110,method=Image.FASTOCTREE,dither=Image.NONE).save(f'icons/{name}.png',optimize=True)
        out.append((name,Image.open(f'icons/{name}.png').convert('RGBA'),S,ins))
print('trim%', {n:round(i/(s+2*i)*100) for n,_,s,i in out})
sheet=Image.new('RGB',(8*180,3*200+40),(26,32,40))
for i,(n,img,_,_) in enumerate(out):
    r,c=divmod(i,8); sheet.paste(img,(c*180+10,r*200+10),img)
sheet.save('contact_dark8.png')
print('total',sum(os.path.getsize(f'icons/{n}.png') for n,_,_,_ in out)//1024,'KB')
