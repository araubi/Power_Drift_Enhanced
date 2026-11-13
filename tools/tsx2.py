# Lector de TSX/TZX completo (bloques 10,11,12,13,14,15,20,21,22,24,25,30,32,35,4B,5A)
import struct,sys
def bloques(d):
    assert d[:7]==b'ZXTape!'
    i=10; out=[]
    while i<len(d):
        bid=d[i]; i+=1
        if bid==0x10:
            pau,ln=struct.unpack('<HH',d[i:i+4]); out.append((bid,d[i+4:i+4+ln],dict(pausa=pau))); i+=4+ln
        elif bid==0x11:
            pil,syn1,syn2,b0,b1,npil,last,pau=struct.unpack('<HHHHHHBH',d[i:i+15]); ln=d[i+15]|d[i+16]<<8|d[i+17]<<16
            out.append((bid,d[i+18:i+18+ln],dict(pil=pil,s1=syn1,s2=syn2,b0=b0,b1=b1,np=npil,last=last,pausa=pau))); i+=18+ln
        elif bid==0x12: out.append((bid,d[i:i+4],None)); i+=4
        elif bid==0x13: n=d[i]; out.append((bid,d[i+1:i+1+2*n],None)); i+=1+2*n
        elif bid==0x14:
            b0,b1,last,pau=struct.unpack('<HHBH',d[i:i+7]); ln=d[i+7]|d[i+8]<<8|d[i+9]<<16
            out.append((bid,d[i+10:i+10+ln],dict(b0=b0,b1=b1,last=last,pausa=pau))); i+=10+ln
        elif bid==0x15:
            ln=d[i+5]|d[i+6]<<8|d[i+7]<<16; out.append((bid,d[i+8:i+8+ln],None)); i+=8+ln
        elif bid==0x4B:
            ln=struct.unpack('<I',d[i:i+4])[0]; blk=d[i+4:i+4+ln]
            pause,pilot,pulses,bit0,bit1,cfg=struct.unpack('<HHHHHB',blk[:11])
            out.append((0x4B,blk[12:],dict(pausa=pause,pilot=pilot,pulsos=pulses,b0=bit0,b1=bit1,cfg=cfg,zz=blk[11]))); i+=4+ln
        elif bid==0x20: out.append((bid,d[i:i+2],None)); i+=2
        elif bid==0x21: ln=d[i]; out.append((bid,d[i+1:i+1+ln],None)); i+=1+ln
        elif bid==0x22: out.append((bid,b'',None))
        elif bid==0x24: out.append((bid,d[i:i+2],None)); i+=2
        elif bid==0x25: out.append((bid,b'',None))
        elif bid==0x30: ln=d[i]; out.append((bid,d[i+1:i+1+ln],None)); i+=1+ln
        elif bid==0x32: ln=struct.unpack('<H',d[i:i+2])[0]; out.append((bid,d[i+2:i+2+ln],None)); i+=2+ln
        elif bid==0x35: ln=struct.unpack('<I',d[i+16:i+20])[0]; out.append((bid,d[i:i+20+ln],None)); i+=20+ln
        elif bid==0x5A: i+=9
        else: raise ValueError('bloque %02X en %d'%(bid,i))
    return out
if __name__=='__main__':
    d=open(sys.argv[1],'rb').read()
    for bid,b,inf in bloques(d):
        if bid in (0x4B,0x10,0x11,0x14): print('%02X'%bid,len(b),b[:12].hex(),inf)
        elif bid in (0x30,0x21): print('%02X'%bid,b.decode('latin1'))
        elif bid==0x32: print('32 info',b)
        elif bid==0x35: print('35',b[:16])
        else: print('%02X'%bid,len(b),b[:16].hex())
