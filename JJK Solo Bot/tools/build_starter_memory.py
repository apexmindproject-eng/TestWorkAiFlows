#!/usr/bin/env python3
"""Build one starter memory file from several saved ones.
usage: python3 -I build_starter_memory.py <out.json> <older.json> [<older.json> ...] <newest.json>

The LAST file is the base: everything measured by the newer builds is taken
from it as it stands (facts by target state, tactics, reactions, opponents,
map, characters, career). From the older files only the tables that are plain
counts and were recorded the same way in every build are added in:
  global.moves  casts, hits and damage per move
  chains        what was cast after what, and how it went
  ranges        hits and casts by distance band, per move
  adopted       the family worked out for enemy moves the bot had no entry for
Files that are an earlier save of another file in the list (same run, fewer
lives) are detected and left out, so nothing is counted twice."""
import json, sys, time

def load(p): return json.load(open(p, encoding='utf-8'))
def casts(m): return sum(v.get('tries', 0) for v in ((m.get('global') or {}).get('moves') or {}).values() if isinstance(v, dict))

def add_counts(dst, src):
    """Sum numeric leaves of two nested count tables."""
    for k, v in (src or {}).items():
        if isinstance(v, dict):
            if not isinstance(dst.get(k), dict): dst[k] = {}
            add_counts(dst[k], v)
        elif isinstance(v, (int, float)) and not isinstance(v, bool):
            dst[k] = (dst.get(k) or 0) + v

def earlier_save_of(a, b):
    """True if `a` looks like an earlier save of the run that produced `b`: every move's casts in a are <= those in b."""
    ma, mb = (a.get('global') or {}).get('moves') or {}, (b.get('global') or {}).get('moves') or {}
    if not ma or a.get('savedAt', 0) >= b.get('savedAt', 0): return False
    return all(isinstance(mb.get(k), dict) and v.get('tries', 0) <= mb[k].get('tries', 0) for k, v in ma.items() if isinstance(v, dict))

def main():
    out, paths = sys.argv[1], sys.argv[2:]
    mems = [load(p) for p in paths]
    base = mems[-1]
    keep = []
    for i, m in enumerate(mems[:-1]):
        later = mems[i + 1:]
        if any(earlier_save_of(m, l) for l in later):
            print('left out (an earlier save of a later file): %s, %d casts' % (paths[i].split('/')[-1][:8], casts(m)))
        else:
            keep.append((paths[i], m))
    st = json.loads(json.dumps(base))
    st.setdefault('global', {}).setdefault('moves', {})
    for name in ('chains', 'ranges', 'adopted'): st.setdefault(name, {})
    for p, m in keep:
        add_counts(st['global']['moves'], (m.get('global') or {}).get('moves'))
        add_counts(st['chains'], m.get('chains'))
        add_counts(st['ranges'], m.get('ranges'))
        for k, v in (m.get('adopted') or {}).items(): st['adopted'].setdefault(k, v)
        print('added counts from %s: %d casts over %d moves' % (p.split('/')[-1][:8], casts(m), len((m.get('global') or {}).get('moves') or {})))
    # Moves the older builds could not use properly (two presses, of which
    # they sent one): their old counts say nothing. Base values only.
    bm = (base.get('global') or {}).get('moves') or {}
    for name in ('Transcend', 'Rupture', 'Littering', 'Drone Strike'):
        if name in st['global']['moves']:
            if name in bm: st['global']['moves'][name] = json.loads(json.dumps(bm[name]))
            else: del st['global']['moves'][name]
    # Old totals may inform but must not ban: the script retires a move for
    # good at 40 casts with almost no hits. Counts are scaled down to at most
    # CAP casts a move, keeping the rates, so nothing starts out retired and
    # the bot's own new casts decide.
    CAP = 36
    capped = 0
    for name, v in st['global']['moves'].items():
        if isinstance(v, dict) and v.get('tries', 0) > CAP:
            f = CAP / v['tries']; capped += 1
            for k in list(v):
                if isinstance(v[k], (int, float)) and not isinstance(v[k], bool): v[k] = round(v[k] * f, 3)
    print('capped at %d casts: %d moves' % (CAP, capped))
    st['savedAt'] = int(time.time())
    for k in ('opponents', 'facts', 'tactics', 'reactions', 'map', 'chars', 'career'):
        if not isinstance(st.get(k), dict): st[k] = {}
    json.dump(st, open(out, 'w', encoding='utf-8'), separators=(',', ':'))
    gm = st['global']['moves']
    print('base %s: %d casts. starter: %d casts over %d moves, %d with 12 or more; facts for %d moves; %d chains rows; %d range tables; %d KB' % (
        paths[-1].split('/')[-1][:8], casts(base), casts(st), len(gm), sum(1 for v in gm.values() if isinstance(v, dict) and v.get('tries', 0) >= 12),
        len(st['facts']), len(st['chains']), len(st['ranges']), len(json.dumps(st)) // 1024))

if __name__ == '__main__':
    if len(sys.argv) < 4: sys.exit(__doc__)
    main()
