# 로봇 아이콘 누끼 — 어두운 바탕을 가장자리에서부터 흘려 채워(flood fill) 지우고, 흰 윤곽의 안티앨리어싱은 알파로 살린다
from PIL import Image; import numpy as np
from scipy import ndimage
im=Image.open('icons/robot.png').convert('RGBA'); a=np.array(im).astype(float)
rgb=a[...,:3]; lum=rgb.mean(axis=2)
dark=lum<70                                    # 바탕(진남색)과 비슷한 어두운 픽셀
edge=np.zeros_like(dark); edge[0,:]=edge[-1,:]=edge[:,0]=edge[:,-1]=True
lab,n=ndimage.label(dark); bg_ids=set(np.unique(lab[edge&dark])); bg_ids.discard(0)
bg=np.isin(lab,list(bg_ids))                   # 가장자리와 이어진 어두운 영역만 바탕
band=ndimage.binary_dilation(bg,iterations=1)&~bg   # 바탕과 맞닿은 윤곽 띠 → 밝기를 알파로
alpha=np.where(bg,0,255).astype(float)
t=np.clip((lum-40)/(130-40),0,1)
alpha[band]=(t[band]*255)
alpha=np.minimum(alpha,a[...,3]); out=a.copy(); out[...,3]=alpha
# 띠 픽셀은 바탕색이 섞여 있으니 흰색으로 되돌린다(눈 등 파란 픽셀은 그대로)
blue=(rgb[...,2]>rgb[...,0]+40)
w=band&~blue; out[w,0:3]=np.maximum(out[w,0:3],235)
ys,xs=np.where(alpha>8); pad=2
crop=out[max(0,ys.min()-pad):ys.max()+pad+1, max(0,xs.min()-pad):xs.max()+pad+1]
Image.fromarray(crop.astype('uint8'),'RGBA').save('icons/robot_cut.png')
print('cut',crop.shape, 'bg px',bg.sum())
