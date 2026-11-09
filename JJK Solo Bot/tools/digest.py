"""Compact digest of a decompiled Knit controller: what it talks to and what it does."""
import re, sys, os
def digest(path, ctx=0):
    s = open(path, encoding='utf-8', errors='replace').read()
    lines = s.split('\n')
    out = []
    name = re.search(r'\["Name"\] = "([^"]+)"', s)
    out.append('## %s  (%d lines, %d B)' % (name.group(1) if name else os.path.basename(path), len(lines), len(s)))
    out.append('services: ' + ', '.join(sorted(set(re.findall(r'GetService\("([A-Za-z0-9_]+Service)"\)', s)))))
    out.append('controllers: ' + ', '.join(sorted(set(re.findall(r'GetController\("([A-Za-z0-9_]+)"\)', s)))))
    # map upvalue var -> service name
    svc = dict(re.findall(r'(v_u_\d+) = v_u_\d+\.GetService\("([A-Za-z0-9_]+)"\)', s))
    keys = re.findall(r'^\t{1,3}\["([^"]+)"\] = function', s, re.M)
    out.append('effect keys: ' + ', '.join(keys))
    fires = []
    for i, l in enumerate(lines):
        m = re.search(r'(v_u_\d+)\.([A-Za-z0-9_]+):(Fire|FireServer|Connect|InvokeServer)\((.*)', l)
        if m and m.group(1) in svc:
            fires.append('  L%d %s.%s:%s(%s' % (i + 1, svc[m.group(1)], m.group(2), m.group(3), m.group(4)[:110]))
        m2 = re.search(r'GetService\("([A-Za-z0-9_]+)"\)\.([A-Za-z0-9_]+):(Fire|Connect)\((.*)', l)
        if m2: fires.append('  L%d %s.%s:%s(%s' % (i + 1, m2.group(1), m2.group(2), m2.group(3), m2.group(4)[:110]))
    out.append('remotes:\n' + '\n'.join(fires))
    hb = [('  L%d %s' % (i + 1, l.strip()[:170])) for i, l in enumerate(lines) if re.search(r'Hitbox|GetPartBoundsIn|Raycast\(|Blockcast|Spherecast', l) and 'GetController' not in l]
    out.append('hitbox/raycast lines:\n' + '\n'.join(hb[:40]))
    attrs = sorted(set(re.findall(r'[GS]etAttribute\("([^"]+)"', s)))
    out.append('attributes: ' + ', '.join(attrs))
    info = sorted(set(re.findall(r'Info:FindFirstChild\("([^"]+)"\)', s)) | set(re.findall(r'Info\.([A-Z][A-Za-z0-9_]+)', s)))
    out.append('Info children: ' + ', '.join(info))
    for root in ('Utils', 'Sounds', 'Animations'):
        var = re.search(r'local (v_u_\d+|v\d+) = v_?u?_?\d*\.%s\b' % root, s)
        refs = set()
        if var:
            for m in re.finditer(re.escape(var.group(1)) + r'((?:\.[A-Za-z0-9_]+){1,4})', s):
                refs.add(m.group(1)[1:])
        out.append('%s refs: %s' % (root, ', '.join(sorted(refs))[:900]))
    strs = [x for x in set(re.findall(r'"([^"\n]{12,90})"', s)) if ' ' in x and 'rbxasset' not in x and 'Saved by' not in x]
    out.append('strings: ' + ' | '.join(sorted(strs))[:700])
    return '\n'.join(out)
if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(digest(p)); print()
