from PIL import Image
import numpy as np, glob, os, sys
from scipy.ndimage import distance_transform_edt
LUM=lambda c:.299*c[...,0]+.587*c[...,1]+.114*c[...,2]
SAT=lambda c:c.max(axis=-1)-c.min(axis=-1)
rows=[]
for f in sorted(glob.glob((sys.argv[1] if len(sys.argv)>1 else 'icons')+'/*.png')):
    n=os.path.basename(f)[:-4]
    a=np.asarray(Image.open(f).convert('RGBA')).astype(float)
    rgb,al=a[...,:3],a[...,3]
    solid=al>250; d=distance_transform_edt(solid)
    L,S=LUM(rgb),SAT(rgb)
    body=np.median(L[(d>=14)&(d<28)]); bodyS=np.median(S[(d>=14)&(d<28)])
    rim=(d>=1)&(d<4)
    whiteish=(L>214)&(S<26)                      # 밝고 채도 없는 = 흰색
    rimwhite=int((rim&whiteish).sum()); rimN=int(rim.sum())
    H,W=al.shape; cor=np.zeros_like(solid)
    cor[:24,:24]=cor[:24,-24:]=cor[-24:,:24]=cor[-24:,-24:]=True
    corner=int(((al>40)&cor&whiteish).sum())
    tilewhite = body>210 and bodyS<26            # 원래 흰 타일(일정·대시보드)
    pct=100*rimwhite/max(1,rimN)
    ok = tilewhite or (pct<3 and corner<25)
    rows.append((n,round(body),round(bodyS),pct,corner,tilewhite,ok))
print(f"{'아이콘':12s} {'본체밝기':>6s} {'채도':>5s} {'테두리 흰비율':>10s} {'모서리흰':>7s}  판정")
for n,b,s,p,c,tw,ok in rows:
    tag='OK (원래 흰 타일)' if tw and ok else ('OK' if ok else '← 흰 테 남음')
    print(f"{n:12s} {b:6d} {s:5d} {p:9.1f}% {c:7d}  {tag}")
bad=[r[0] for r in rows if not r[6]]
print('\n흰 테 남은 아이콘:', bad or '없음', f'({len(rows)}개 검사)')
