"""Decode Roblox's binary AttributesSerialize blob (subset of types)."""
import struct
def decode(b):
    out = {}
    if not b: return out
    try:
        p = 0; n = struct.unpack_from('<I', b, p)[0]; p += 4
        for _ in range(n):
            kl = struct.unpack_from('<I', b, p)[0]; p += 4
            k = b[p:p+kl].decode('utf-8', 'replace'); p += kl
            t = b[p]; p += 1
            if t == 0x02:
                l = struct.unpack_from('<I', b, p)[0]; p += 4; v = b[p:p+l].decode('utf-8', 'replace'); p += l
            elif t == 0x03: v = bool(b[p]); p += 1
            elif t == 0x04: v = struct.unpack_from('<i', b, p)[0]; p += 4
            elif t == 0x05: v = struct.unpack_from('<f', b, p)[0]; p += 4
            elif t == 0x06: v = struct.unpack_from('<d', b, p)[0]; p += 8
            elif t == 0x09: v = ('UDim',) + struct.unpack_from('<fi', b, p); p += 8
            elif t == 0x0A: v = ('UDim2',) + struct.unpack_from('<fifi', b, p); p += 16
            elif t == 0x0E: v = ('BrickColor', struct.unpack_from('<I', b, p)[0]); p += 4
            elif t == 0x0F: v = ('Color3',) + tuple(round(x * 255) for x in struct.unpack_from('<fff', b, p)); p += 12
            elif t == 0x10: v = ('Vector2',) + struct.unpack_from('<ff', b, p); p += 8
            elif t == 0x11: v = ('Vector3',) + struct.unpack_from('<fff', b, p); p += 12
            elif t == 0x14: v = ('CFrame',); p += 12; r = b[p]; p += 1; p += (36 if r == 0 else 0)
            elif t == 0x17: v = ('NumberSequence',); c = struct.unpack_from('<I', b, p)[0]; p += 4 + 12 * c
            elif t == 0x19: v = ('ColorSequence',); c = struct.unpack_from('<I', b, p)[0]; p += 4 + 20 * c
            elif t == 0x1B: v = ('NumberRange',) + struct.unpack_from('<ff', b, p); p += 8
            elif t == 0x1C: v = ('Rect',) + struct.unpack_from('<ffff', b, p); p += 16
            elif t == 0x21: v = ('Font',); out[k] = v; break
            else: out[k] = ('?type', t); break
            out[k] = v
    except Exception as e:
        out['__err'] = str(e)
    return out
