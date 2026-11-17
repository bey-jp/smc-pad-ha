import subprocess,re,sys,numpy as np
from PIL import Image, ImageDraw
from collections import deque
font="Noto Sans CJK JP:style=Bold"; ts=27*0.8
R=10; S=40; N=S*R
def glyph_mask(ch):
    open("g.scad","w").write(f'text("{ch}",size={ts},font="{font}",halign="center",valign="center");')
    subprocess.run(["openscad","-o","g.svg","g.scad"],capture_output=True)
    s=open("g.svg").read()
    m=np.zeros((N,N),bool)
    for path in re.findall(r' d="([^"]+)"',s):
        for sub in re.split(r'(?=M)',path):
            pts=[(float(a),float(b)) for a,b in re.findall(r'(-?[\d.]+),(-?[\d.]+)',sub)]
            if len(pts)<3: continue
            im=Image.new("1",(N,N),0)
            ImageDraw.Draw(im).polygon([((x+S/2)*R,(y+S/2)*R) for x,y in pts],fill=1)  # svg y down
            m^=np.array(im,bool)
    return m  # row index = svg y (down)
def label(free):
    lab=-np.ones(free.shape,int); k=0
    for i in range(N):
        for j in range(N):
            if free[i,j] and lab[i,j]<0:
                q=deque([(i,j)]); lab[i,j]=k
                while q:
                    a,b=q.popleft()
                    for da,db in((1,0),(-1,0),(0,1),(0,-1)):
                        c,d=a+da,b+db
                        if 0<=c<N and 0<=d<N and free[c,d] and lab[c,d]<0:
                            lab[c,d]=k;q.append((c,d))
                k+=1
    return lab,k
def solve(ch):
    g=glyph_mask(ch); lab,k=label(~g)
    for c in range(k):
        if (lab==c).sum()<50: g[lab==c]=True
    lab,k=label(~g)
    outer=lab[0,0]; conn={outer}; bridges=[]
    W=R//2  # half bar width 0.5mm
    while len(conn)<k:
        best=None
        for comp in range(k):
            if comp in conn: continue
            ys,xs=np.nonzero(lab==comp)
            for a,b in zip(ys,xs):
                for da,db in((1,0),(-1,0),(0,1),(0,-1)):
                    if not g[a+da,b+db]: continue
                    c,d=a+da,b+db; n=0
                    while 0<=c<N and 0<=d<N and g[c,d] and n<6*R: c+=da;d+=db;n+=1
                    if not(0<=c<N and 0<=d<N) or g[c,d]: continue
                    t=lab[c,d]
                    if t==comp: continue
                    # require the full bar width to cross cleanly (free at both ends across width)
                    ok=True
                    for w in range(-W,W+1):
                        pa,pb=(a+w*db, b+w*da)  # perpendicular offset
                        ea,eb=(c+w*db, d+w*da)
                        if not(0<=pa<N and 0<=pb<N and 0<=ea<N and 0<=eb<N): ok=False;break
                        if lab[pa,pb]!=comp or lab[ea,eb]!=t: ok=False;break
                    if not ok: continue
                    score=n + (0 if t in conn else 2*R)
                    if best is None or score<best[0]: best=(score,comp,t,a,b,c,d,da,db,n)
        if best is None: print(ch,"FAIL");return None
        _,comp,t,a,b,c,d,da,db,n=best
        # merge
        if t in conn: conn.add(comp)
        else: lab[lab==comp]=t
        # bar center (mm, y up)
        cy=((a+c)/2+0.5)/R-S/2; cx=((b+d)/2+0.5)/R-S/2
        L=(n/R)+0.8
        ang=90 if da!=0 else 0
        bridges.append([ang,round(float(-cy/ts),3),round(float(cx/ts),3),round(float(L/ts),3)])
    return bridges
for ch in sys.argv[1]:
    print(ch, solve(ch), flush=True)
