#!/usr/bin/env python3
"""Turn the research JSON into the Lua MoveFacts table and a markdown catalogue.
usage: python3 -I gen_facts.py <bot.lua> <research dir> <out.lua> <out.md>"""
import json, re, glob, sys
bot = open(sys.argv[1]).read()
i = bot.index('local MoveRules = {'); j = bot.index('\nlocal DefaultRule', i)
rules = re.findall(r'\["([^"]+)"\]\s*=\s*\{', bot[i:j])
key = lambda s: re.sub(r'[^A-Za-z0-9]', '', s or '')
rulekeys = {key(r): r for r in rules}
entries = []
for f in sorted(glob.glob(sys.argv[2] + '/group*.json')):
    d = json.load(open(f))
    for m in (d['moves'] if isinstance(d, dict) else d):
        if m.get('name'): entries.append(m)

def num(v):
    if v is None: return None
    if isinstance(v, (int, float)): return float(v)
    mm = re.search(r'-?\d+(?:\.\d+)?', str(v))
    return float(mm.group()) if mm else None

def role(text):
    t = (text or '').lower()
    if re.search(r'extender|extend|keeps? the (target|enemy) (stunned|in place)|stunned in place|saves the user', t): return 'extender'
    if re.search(r'starter|launcher|opener|launches', t): return 'starter'
    if re.search(r'ender|finisher|knocks? (the )?(target|enemy|them|enemies|opponent) (away|back)|sends? (the )?(target|them|enemies) away|knocking them away', t): return 'ender'
    return None

def window(m):
    t = ' '.join(str(m.get(k) or '') for k in ('when_it_whiffs', 'description', 'combo'))
    mm = re.search(r'(\d(?:\.\d+)?)\s*s(?:econd)?s?\s*(?:counter )?window|within (\d(?:\.\d+)?)\s*s|inside the (\d(?:\.\d+)?)\s*s', t)
    if mm:
        return float(next(g for g in mm.groups() if g))
    return None

base, variants = {}, {}
for m in entries:
    nm = m['name']
    b = re.sub(r'\s*\(.*\)\s*$', '', nm).strip()
    k = key(b)
    if nm == b: base.setdefault(k, m)
    else: variants.setdefault(k, []).append(m)
# names the research split differently from the game's own move names
ALIAS = {'RatioBreaker': 'RatioBreakerI', 'Supernova': None}
facts = {}
for k, rname in rulekeys.items():
    m = base.get(k) or base.get(ALIAS.get(k) or '') or (variants.get(k) or [None])[0]
    if not m or not m.get('kind'): continue
    kind = m['kind']
    dmg = num(m.get('damage'))
    f = {'k': kind}
    if kind == 'summon' and not dmg: f['k'] = 'buff'
    if m.get('blockable') is False: f['ub'] = True
    elif m.get('blockable') is True: f['ub'] = False     # semi-blockable counts: the opening hit is what a guard stops
    if m.get('hits_ragdolled') is True: f['rag'] = True
    elif m.get('hits_ragdolled') is False: f['rag'] = False
    cd = num(m.get('cooldown_s'))
    if cd and 0.3 <= cd <= 300: f['cd'] = cd
    if dmg and dmg > 0: f['dmg'] = dmg
    elif f['k'] in ('pull', 'grab', 'projectile', 'melee', 'rush', 'beam', 'other', 'aoe_point', 'aoe_self'):
        if m.get('damage') is not None and (dmg == 0 or str(m.get('damage')).lower().startswith(('none', '0 '))): f['nd'] = True
    r = num(m.get('range_studs'))
    if r and r > 0: f['r'] = r
    c = role(m.get('combo'))
    if c: f['c'] = c
    if f['k'] == 'counter':
        w = window(m)
        if w and w <= 2: f['cw'] = w
    note = (m.get('when_it_whiffs') or m.get('description') or '').strip()
    facts[k] = (rname, f, re.sub(r'\s+', ' ', note)[:118], m)

# what the place file and the research disagree on, or what the research
# leaves open but the wording settles
PATCH = {
    'Toad': {'nd': True},                   # pulls, deals nothing by itself
    'LapseBlue': {'ub': False},             # "or the target is blocking"
    'ManjiKick': {'cw': 0.6}, 'EyeCatching': {'cw': 0.75}, 'Brothers': {'cw': 1.1},
    'Outburst': {'cw': 0.25}, 'Adaptation': {'cw': 0.4}, 'Supernova': {'cw': 0.6},
    'Veilstep': {'k': 'mobility'},
}
for k, p in PATCH.items():
    if k in facts: facts[k][1].update(p)

def lua(v):
    if v is True: return 'true'
    if v is False: return 'false'
    if isinstance(v, float): return ('%g' % v)
    return '"%s"' % v
out = ['-- [move key] = { k = family, ub = gets through a block, rag = hits a body on the ground,',
       '--   cd = cooldown, dmg = damage, r = reach in studs, c = place in a string,',
       '--   nd = deals no damage of its own (judged by what it does to the target), cw = counter window }',
       '-- Second-hand: read from search extracts of the wiki and guides, not from the pages. The',
       '-- machine checks every line against its own casts and says so in the log when one is wrong.',
       'MoveFacts = {']
order = ['k', 'ub', 'rag', 'nd', 'cw', 'cd', 'dmg', 'r', 'c']
for k in sorted(facts, key=lambda x: (facts[x][3].get('character') or '', x)):
    rname, f, note, m = facts[k]
    body = ', '.join('%s = %s' % (o, lua(f[o])) for o in order if o in f)
    line = '    %s = { %s },' % (k if re.match(r'^[A-Za-z_]\w*$', k) else '["%s"]' % k, body)
    if note: line += '  -- ' + note.replace('--', '-')
    out.append(line)
out.append('}')
open(sys.argv[3], 'w').write('\n'.join(out) + '\n')

# markdown catalogue: everything researched, including what has no rule
md = []
chars = []
for m in entries:
    c = m.get('character') or '?'
    if c not in chars: chars.append(c)
for c in chars:
    md.append('\n#### %s\n' % c)
    md.append('| Move | Slot | Family | Block | Ground | Damage | Cooldown | Reach | When it misses |')
    md.append('|---|---|---|---|---|---|---|---|---|')
    for m in entries:
        if (m.get('character') or '?') != c: continue
        b = m.get('blockable'); b = 'unblockable' if b is False else ('blockable' if b is True else '?')
        g = m.get('hits_ragdolled'); g = 'hits' if g is True else ('misses' if g is False else '?')
        cell = lambda v: re.sub(r'\s+', ' ', str(v if v is not None else '?')).replace('|', '/')
        md.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
            cell(m['name']), cell(m.get('slot')), cell(m.get('kind')), b, g, cell(m.get('damage'))[:60],
            cell(m.get('cooldown_s'))[:40], cell(m.get('range_studs')), cell(m.get('when_it_whiffs') or '')[:220]))
open(sys.argv[4], 'w').write('\n'.join(md) + '\n')
print(len(facts), 'facts for', len(rulekeys), 'rules;', len(entries), 'entries in the catalogue')
print('unblockable:', sum(1 for v in facts.values() if v[1].get('ub') is True), 'blockable:', sum(1 for v in facts.values() if v[1].get('ub') is False),
      'ground yes:', sum(1 for v in facts.values() if v[1].get('rag') is True), 'ground no:', sum(1 for v in facts.values() if v[1].get('rag') is False),
      'counters:', [v[0] for v in facts.values() if v[1]['k'] == 'counter'], 'nd:', [v[0] for v in facts.values() if v[1].get('nd')])
