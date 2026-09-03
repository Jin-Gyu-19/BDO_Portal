from PIL import Image
import numpy as np, glob, os, sys
from scipy.ndimage import distance_transform_edt
lum=lambda c: .299*c[...,0]+.587*c[...,1]+.114*c[...,2]
def prof(f):
    a=np.asarray(Image.open(f).convert('RGBA')).astype(float)
    rgb,al=a[...,:3],a[...,3]
    solid=al>250
    d=distance_transform_edt(solid)          # 가장자리로부터의 깊이
    L=lum(rgb)
    band=lambda lo,hi: np.median(L[(d>=lo)&(d<hi)])
    return band(1,3), band(3,6), band(8,14), band(20,40)
def report(dirname='icons'):
    print(f"{'아이콘':12s} {'d1-3':>6s} {'d3-6':>6s} {'d8-14':>6s} {'d20+':>6s}  차이  판정")
    bad=[]
    for f in sorted(glob.glob(dirname+'/*.png')):
        n=os.path.basename(f)[:-4]
        e1,e2,mid,deep=prof(f)
        diff=e1-mid
        ok=diff<18
        if not ok: bad.append((n,round(diff)))
        print(f"{n:12s} {e1:6.0f} {e2:6.0f} {mid:6.0f} {deep:6.0f} {diff:+6.0f}  {'OK' if ok else '← 밝은 테두리'}")
    print('\n밝은 테두리 남은 아이콘:', bad or '없음')
    return bad
if __name__=='__main__': report(sys.argv[1] if len(sys.argv)>1 else 'icons')
