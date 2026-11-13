import re, sys
def items(ops):
    out=[];cur='';q=None
    for ch in ops:
        if q:
            cur+=ch
            if ch==q:q=None
        elif ch in '"\'':q=ch;cur+=ch
        elif ch==',':out.append(cur.strip());cur=''
        elif ch==';':return out+[cur.strip()],True
        else:cur+=ch
    return out+[cur.strip()],False
pat=re.compile(r'^(\s*(?:\w+:)?\s*)DB\s+(.*)$')
def convierte(txt):
    res=[];n=0
    for l in txt.split('\n'):
        m=pat.match(l)
        if m:
            ops=m.group(2)
            # separar comentario fuera de comillas
            q=None;cut=len(ops)
            for i,ch in enumerate(ops):
                if q:
                    if ch==q:q=None
                elif ch in '"\'':q=ch
                elif ch==';':cut=i;break
            it,_=items(ops[:cut])
            c=0
            for x in it:
                if x[:1] in '"\'': c+=len(x)-2
                else: c+=1
            com=ops[cut:]
            l=m.group(1)+'DS %d,RELLENO'%c+('\t'+com if com else '')
            n+=c
        res.append(l)
    return '\n'.join(res),n
if __name__=='__main__':
    for f in sys.argv[1:]:
        t,n=convierte(open(f).read())
        open(f,'w').write(t); print(f,n,'bytes de datos quitados')
