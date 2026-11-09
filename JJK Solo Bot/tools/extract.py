import pickle, sys, os, re, json
d = pickle.load(open(sys.argv[1], 'rb')); inst = d['inst']
out = sys.argv[2]; os.makedirs(out, exist_ok=True)
idx = []
used = set()
for i, o in inst.items():
    if o['class'] in ('Script', 'LocalScript', 'ModuleScript'):
        src = o['props'].get('Source', b'')
        if not src: continue
        fn = re.sub(r'[^A-Za-z0-9_.\-]+', '_', o['path'])[:180]
        k = fn; n = 1
        while k in used: n += 1; k = '%s__%d' % (fn, n)
        used.add(k)
        open(os.path.join(out, k + '.lua'), 'wb').write(src)
        idx.append({'file': k + '.lua', 'path': o['path'], 'class': o['class'], 'bytes': len(src)})
json.dump(idx, open(os.path.join(out, '_index.json'), 'w'), indent=0)
print('wrote', len(idx), 'scripts,', sum(x['bytes'] for x in idx) // 1024, 'KB')
