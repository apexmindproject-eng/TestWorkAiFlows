#!/usr/bin/env python3
"""Print what the bot has learned, from its memory file.
usage: python3 -I analyze_memory.py <JJK_AutoFight_Memory_*.json>
Reads only. Sections that an older memory file lacks are skipped."""
import json, sys

STATES = ['free', 'block', 'stun', 'rag', 'wake', 'swing', 'air']

def seq(v):
    """A Lua array comes back from JSON as a list, or as a dict with string keys if it had holes."""
    if isinstance(v, list): return list(enumerate(v, 1))
    if isinstance(v, dict): return sorted(((int(k), x) for k, x in v.items() if str(k).isdigit()))
    return []

def report(path):
    m = json.load(open(path, encoding='utf-8'))
    print('=' * 78); print(path.split('/')[-1])
    sizes = {k: (len(v) if isinstance(v, (dict, list)) else v) for k, v in m.items()}
    print('tables: ' + ', '.join('%s %s' % kv for kv in sorted(sizes.items(), key=lambda kv: str(kv[0]))))
    car = m.get('career') or {}
    if car: print('career: %s' % ', '.join('%s %s' % (k, round(v, 1) if isinstance(v, float) else v) for k, v in car.items() if not isinstance(v, (dict, list))))
    gm = (m.get('global') or {}).get('moves') or {}
    facts = m.get('facts') or {}
    if gm:
        rows = sorted(((v.get('tries', 0), k, v) for k, v in gm.items() if isinstance(v, dict)), reverse=True)
        n = [r[0] for r in rows]
        print('\nCareer casts: %d moves, %d casts in all; median %d casts a move; %d moves with 12 or more' % (
            len(rows), sum(n), sorted(n)[len(n) // 2] if n else 0, sum(1 for x in n if x >= 12)))
    if facts:
        print('\nMoves by target state (hits/casts)')
        print('  %-24s %s  %s' % ('move', ' '.join('%-9s' % s for s in STATES), 'notes'))
        for name in sorted(facts, key=lambda k: -(facts[k].get('n') or 0))[:70]:
            o = facts[name]; s = o.get('s') or {}
            cells = []
            for st in STATES:
                c = s.get(st)
                cells.append('%-9s' % ('%g/%g' % (round(c.get('h', 0), 1), round(c.get('n', 0), 1)) if isinstance(c, dict) and c.get('n') else '.'))
            notes = []
            if o.get('seeded'): notes.append('seeded')
            if o.get('cd'): notes.append('cd %.1fs' % o['cd'])
            if o.get('rn'): notes.append('lands %.2fs' % (o.get('rt', 0) / o['rn']))
            if o.get('mvN'): notes.append('carries %.0f' % (o.get('mv', 0) / o['mvN']))
            if o.get('hn'): notes.append('after hit: down %d held %d of %d' % (o.get('rg', 0), o.get('st', 0), o['hn']))
            if o.get('late'): notes.append('late cooldown x%d' % o['late'])
            h = o.get('hold')
            if isinstance(h, dict) and ((h.get('tap') or {}).get('n') or (h.get('hold') or {}).get('n')):
                t, hd = h.get('tap') or {}, h.get('hold') or {}
                notes.append('tap %.1f x%d, hold %.1f x%d' % (t.get('d', 0) / max(1, t.get('n', 0)), t.get('n', 0), hd.get('d', 0) / max(1, hd.get('n', 0)), hd.get('n', 0)))
            arms = [(i, a) for i, a in seq(o.get('p2')) if isinstance(a, dict) and a.get('n')]
            if arms: notes.append('2nd press ' + ', '.join('#%d %.1f x%d' % (i, a.get('d', 0) / a['n'], a['n']) for i, a in arms))
            print('  %-24s %s  %s' % (name[:24], ' '.join(cells), '; '.join(notes)))
    tac = m.get('tactics') or {}
    if tac:
        print('\nTactics (career)')
        for k in ('confirm', 'neutral', 'punish', 'counter', 'ground', 'break', 'm1'):
            r = tac.get(k)
            if isinstance(r, dict) and r.get('n'):
                print('  %-8s %d of %d landed (%.0f%%), %.1f dmg each' % (k, r.get('h', 0), r['n'], 100.0 * r.get('h', 0) / r['n'], r.get('d', 0) / max(1, r.get('h', 0))))
        fin = tac.get('fin')
        if isinstance(fin, dict) and fin:
            print('  last hit of the string: ' + ', '.join('%s x%d (net %+.1f each)' % (k, v.get('n', 0), v.get('net', 0) / max(1, v.get('n', 0))) for k, v in fin.items() if isinstance(v, dict)))
        m1r = tac.get('m1r')
        if isinstance(m1r, dict) and m1r:
            print('  swings by distance: ' + ', '.join('%s-%d %d/%d' % (k, int(k) + 2, v.get('h', 0), v.get('n', 0)) for k, v in sorted(m1r.items(), key=lambda kv: int(kv[0])) if isinstance(v, dict)))
        op = tac.get('open')
        if isinstance(op, dict) and op:
            tot = sum(op.values())
            print('  what we were doing when hits got in (%d):' % tot)
            for k, v in sorted(op.items(), key=lambda kv: -kv[1]): print('    %4d  %3.0f%%  %s' % (v, 100.0 * v / tot, k))
        if tac.get('dashHit') is not None: print('  dash punches landed: %s' % tac.get('dashHit'))
    ch = m.get('chars')
    if isinstance(ch, dict) and ch:
        print('\nCharacters')
        for k, v in sorted(ch.items(), key=lambda kv: -(kv[1].get('lives', 0) if isinstance(kv[1], dict) else 0))[:30]:
            if isinstance(v, dict): print('  %-12s %s' % (k, ', '.join('%s %s' % (a, round(b, 1) if isinstance(b, float) else b) for a, b in v.items() if not isinstance(b, (dict, list)))))

if __name__ == '__main__':
    if len(sys.argv) < 2: sys.exit(__doc__)
    for p in sys.argv[1:]: report(p)
