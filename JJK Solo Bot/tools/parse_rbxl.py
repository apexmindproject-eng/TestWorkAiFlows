"""Minimal reader for Roblox binary place files (.rbxl). Reads the instance
tree, string / bool / number properties and attribute blobs. Treats the file
strictly as data."""
import struct, sys, json, pickle
import lz4.block, zstandard

def read_chunks(buf):
    assert buf[:8] == b'<roblox!', 'not a binary roblox file'
    ncls, ninst = struct.unpack_from('<ii', buf, 16)
    pos = 32
    out = []
    while pos < len(buf):
        name = buf[pos:pos+4]; clen, ulen, _ = struct.unpack_from('<III', buf, pos+4); pos += 16
        if clen == 0:
            data = buf[pos:pos+ulen]; pos += ulen
        else:
            raw = buf[pos:pos+clen]; pos += clen
            if raw[:4] == b'\x28\xb5\x2f\xfd':
                data = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                data = lz4.block.decompress(raw, uncompressed_size=ulen)
        out.append((name.rstrip(b'\x00').decode('latin1'), data))
        if name == b'END\x00': break
    return ncls, ninst, out

class R:
    def __init__(s, d): s.d = d; s.p = 0
    def u8(s): v = s.d[s.p]; s.p += 1; return v
    def u32(s): v = struct.unpack_from('<I', s.d, s.p)[0]; s.p += 4; return v
    def string(s): n = s.u32(); v = s.d[s.p:s.p+n]; s.p += n; return v
    def interleaved(s, count, width):
        raw = s.d[s.p:s.p+count*width]; s.p += count*width
        vals = []
        for i in range(count):
            v = 0
            for b in range(width): v = (v << 8) | raw[b*count + i]
            vals.append(v)
        return vals
    def zz(s, count, width=4):
        return [(v >> 1) ^ -(v & 1) for v in s.interleaved(count, width)]
    def refs(s, count):
        out, acc = [], 0
        for v in s.zz(count): acc += v; out.append(acc)
        return out
    def floats(s, count):
        out = []
        for v in s.interleaved(count, 4):
            v = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
            out.append(struct.unpack('<f', struct.pack('<I', v))[0])
        return out

def parse(path):
    ncls, ninst, chunks = read_chunks(open(path, 'rb').read())
    classes = {}     # class id -> (name, [referents])
    inst = {}        # referent -> dict(class=, props={})
    sstr = []
    skipped = {}
    for name, data in chunks:
        r = R(data)
        if name == 'SSTR':
            r.u32(); n = r.u32()
            for _ in range(n): r.p += 16; sstr.append(r.string())
        elif name == 'INST':
            cid = r.u32(); cname = r.string().decode('utf-8', 'replace'); svc = r.u8(); n = r.u32()
            ids = r.refs(n)
            classes[cid] = (cname, ids)
            for i in ids: inst[i] = {'class': cname, 'props': {}, 'parent': None}
        elif name == 'PROP':
            cid = r.u32(); pname = r.string().decode('utf-8', 'replace'); ty = r.u8()
            cname, ids = classes[cid]; n = len(ids)
            vals = None
            try:
                if ty == 0x01: vals = [r.string() for _ in range(n)]
                elif ty == 0x02: vals = [bool(r.u8()) for _ in range(n)]
                elif ty == 0x03: vals = r.zz(n)
                elif ty == 0x04: vals = r.floats(n)
                elif ty == 0x05: vals = list(struct.unpack_from('<%dd' % n, data, r.p))
                elif ty == 0x12: vals = r.interleaved(n, 4)
                elif ty == 0x13: vals = r.refs(n)
                elif ty == 0x1B: vals = r.zz(n, 8)
                elif ty == 0x1C: vals = [sstr[i] if i < len(sstr) else b'' for i in r.interleaved(n, 4)]
                else: skipped[ty] = skipped.get(ty, 0) + 1
            except Exception as e:
                skipped['err:%s:%s' % (cname, pname)] = str(e)
            if vals is not None:
                for i, v in zip(ids, vals): inst[i]['props'][pname] = v
        elif name == 'PRNT':
            r.u8(); n = r.u32()
            kids = r.refs(n); pars = r.refs(n)
            for k, p in zip(kids, pars):
                if k in inst: inst[k]['parent'] = p
    return ncls, ninst, inst, skipped

if __name__ == '__main__':
    ncls, ninst, inst, skipped = parse(sys.argv[1])
    for i, o in inst.items():
        nm = o['props'].get('Name', b'?')
        o['name'] = nm.decode('utf-8', 'replace') if isinstance(nm, bytes) else str(nm)
    kids = {}
    for i, o in inst.items(): kids.setdefault(o['parent'], []).append(i)
    def path(i):
        parts = []
        while i in inst and i is not None and i != -1:
            parts.append(inst[i]['name']); i = inst[i]['parent']
        return '/'.join(reversed(parts))
    for i, o in inst.items(): o['path'] = path(i)
    pickle.dump({'inst': inst, 'kids': kids}, open(sys.argv[2], 'wb'))
    print('classes', ncls, 'instances', ninst, 'parsed', len(inst), 'skipped prop types', {k: v for k, v in skipped.items() if not str(k).startswith('err')})
    errs = {k: v for k, v in skipped.items() if str(k).startswith('err')}
    print('prop errors', len(errs), list(errs.items())[:5])
    roots = kids.get(-1, []) + kids.get(None, [])
    print('roots:', sorted(inst[i]['class'] + ':' + inst[i]['name'] for i in roots))
    from collections import Counter
    c = Counter(o['class'] for o in inst.values())
    print('scripts:', {k: c[k] for k in ('Script', 'LocalScript', 'ModuleScript')})
    withsrc = sum(1 for o in inst.values() if o['class'] in ('Script', 'LocalScript', 'ModuleScript') and len(o['props'].get('Source', b'')) > 0)
    print('scripts with non-empty Source:', withsrc)
