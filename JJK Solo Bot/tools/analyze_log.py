#!/usr/bin/env python3
"""Summarise a JJK_AutoFight log: one table per question the log can answer.
usage: python3 -I analyze_log.py <log.txt> [more logs...]
Reads only; older logs simply lack the newer sections."""
import re, sys, collections

def num(x):
    try: return float(x)
    except Exception: return 0.0

def frac(seg):
    m = re.match(r'\s*(\d+)/(\d+) hit ([\d.]+) dmg', seg or '')
    return (int(m.group(1)), int(m.group(2)), float(m.group(3))) if m else (0, 0, 0.0)

def analyse(path):
    txt = open(path, encoding='utf-8', errors='replace').read()
    lives = re.findall(r'LIFE END: [^\n]*', txt)
    build = re.search(r'### BUILD (\S+) ###', txt)
    out = {'path': path, 'build': build.group(1) if build else '?', 'lives': len(lives), 'kills': len(re.findall(r'Kill! Total', txt))}
    S = collections.Counter(); chars = collections.Counter(); opens = collections.Counter(); fins = collections.defaultdict(lambda: [0, 0.0])
    stun_by = collections.Counter(); held_why = collections.Counter()
    state_sec = collections.Counter(); rev_pairs = collections.Counter()
    for L in lives:
        m = re.match(r'LIFE END: ([\d.]+) dmg in ([\d.]+)s \(([\d.]+) dmg/s, (\d+) moves, ([\d.]+)% engaged, (\d+) blocks, ([\d.]+)s stunned\) \| ([^|]*)\|', L)
        if not m: continue
        S['dmg'] += num(m.group(1)); S['dur'] += num(m.group(2)); S['moves'] += int(m.group(4)); S['blocks'] += int(m.group(6)); S['stunned'] += num(m.group(7))
        chars[m.group(8).strip()] += 1
        for part in (re.search(r'stunned by: ([^|]*)', L) or [None, ''])[1].split(','):
            mm = re.match(r'\s*([^:]+):(\S.*?) x(\d+)', part)
            if mm:
                who, anim, k = mm.group(1), mm.group(2), int(mm.group(3))
                cat = 'own recovery' if who == 'self' else ('front-dash punch' if anim == 'Chase' else ('not identified' if anim == '?' else
                      ('basic attack' if re.match(r'(Melee\d|Hit\d|Down|Up|Land|[A-Za-z]+\d)$', anim) else 'skill: ' + anim)))
                stun_by[cat] += k
        mm = re.search(r'refused (\d+) \(rolled back (\d+)\), burst (\d+)/(\d+)', L)
        if mm: S['refused'] += int(mm.group(1)); S['bursts'] += int(mm.group(3)); S['escapes'] += int(mm.group(4))
        mm = re.search(r'tactics: confirm ([^;]*); neutral ([^;]*); punish ([^;]*); combos (\d+); pre-guards (\d+) \((\d+) met a swing\), counters (\d+); lead-aimed (\d+); gated (\d+); M1 (\d+) swings (\d+) hits ([\d.]+) dmg', L)
        if mm:
            for key, seg in (('confirm', mm.group(1)), ('neutral', mm.group(2)), ('punish', mm.group(3))):
                h, n, d = frac(seg); S[key + '_h'] += h; S[key + '_n'] += n; S[key + '_d'] += d
            for key, g in (('combos', 4), ('preguard', 5), ('preguard_met', 6), ('lead', 8), ('gated', 9), ('m1_n', 10), ('m1_h', 11)):
                S[key] += int(mm.group(g))
            S['m1_d'] += num(mm.group(12))
        mm = re.search(r'movement: backward ([\d.]+)% of travel; (\d+) reversals', L)
        if mm: S['back_sum'] += num(mm.group(1)); S['back_n'] += 1; S['reversals'] += int(mm.group(2))
        mm = re.search(r'knowledge: (\d+) casts withheld \(mostly (\S+) x(\d+)\), (\d+) probes, (\d+) counters, (\d+) guard-breaks, (\d+) ground hits, M1 held off ([\d.]+)s, finishers ([^|]*?)(?:, (\d+) refusals that were not)?(?:, second presses (\d+) of (\d+) \((\d+) lost to a stun\))?\s*(?:\||$)', L)
        if mm:
            S['held'] += int(mm.group(1)); held_why[mm.group(2)] += int(mm.group(3))
            for key, g in (('probes', 4), ('kcounters', 5), ('breaks', 6), ('ground', 7)): S[key] += int(mm.group(g))
            S['m1held'] += num(mm.group(8))
            for f in re.findall(r'(down|up|flat) x(\d+) \(net ([+-]?[\d.]+)\)', mm.group(9)):
                fins[f[0]][0] += int(f[1]); fins[f[0]][1] += num(f[2])
            S['late'] += int(mm.group(10) or 0); S['p2_sent'] += int(mm.group(11) or 0); S['p2_cast'] += int(mm.group(12) or 0); S['p2_lost'] += int(mm.group(13) or 0)
        mm = re.search(r'hits that got in: (\d+) \(([^)]*)\) \| wake-up: swung through (\d+), guarded theirs (\d+), stunned while immune (\d+) \| held casts (\d+), awakening waited ([\d.]+)s', L)
        if mm:
            S['openN'] += int(mm.group(1))
            for part in mm.group(2).split(','):
                pm = re.match(r'\s*(.+?) (\d+)$', part)
                if pm: opens[pm.group(1)] += int(pm.group(2))
            S['wake_swing'] += int(mm.group(3)); S['wake_guard'] += int(mm.group(4)); S['wake_stunned'] += int(mm.group(5)); S['hold_casts'] += int(mm.group(6))
        mm = re.search(r'swings by distance: ([^;]*); reach taken as ([\d.]+) studs \((\w+)\) \| casts turned onto the target (\d+) of (\d+)', L)
        if mm: out['m1bands'] = mm.group(1); out['m1reach'] = '%s studs (%s)' % (mm.group(2), mm.group(3)); S['cast_turned'] += int(mm.group(4)); S['cast_faced'] += int(mm.group(5))
        mm = re.search(r'dash punches (\d+) \((\d+) landed\)(?: \| took ([\d.]+) dmg)?', L)
        if mm: S['dash'] += int(mm.group(1)); S['dash_hit'] += int(mm.group(2)); S['taken'] += num(mm.group(3))
        mm = re.search(r'\| path (\d+) computes \(', L)
        if mm: S['computes'] += int(mm.group(1))
        # v93: what blocks achieve, time per state, where reversals fall, frames dropped
        mm = re.search(r'probe: blocks raised/accepted/absorbed (\d+)/(\d+)/(\d+) \(accepted after ([\d.]+) ms\); state s ([^;]*); reversals between ([^;]*); swings in a skill (\d+) of (\d+); log flushes (\d+) \(worst ([\d.]+) ms\)', L)
        if mm:
            S['blk_raised'] += int(mm.group(1)); S['blk_accepted'] += int(mm.group(2)); S['blk_absorbed'] += int(mm.group(3))
            S['blk_delay_sum'] += num(mm.group(4)) * int(mm.group(2))
            for part in mm.group(5).split(','):
                pm = re.match(r'\s*(\S+) ([\d.]+)$', part)
                if pm: state_sec[pm.group(1)] += num(pm.group(2))
            for part in mm.group(6).split(','):
                pm = re.match(r'\s*(\S+) x(\d+)$', part)
                if pm: rev_pairs[pm.group(1)] += int(pm.group(2))
            S['swing_inskill'] += int(mm.group(7)); S['swing_probe_n'] += int(mm.group(8)); S['flushes'] += int(mm.group(9))
            S['flush_worst'] = max(S['flush_worst'], num(mm.group(10)))
        mm = re.search(r'path: (\d+) of (\d+) computes with the target in sight; stale frames (\d+); reactions latched (\d+)', L)
        if mm: S['path_seen'] += int(mm.group(1)); S['path_n'] += int(mm.group(2)); S['stale'] += int(mm.group(3)); S['latched'] += int(mm.group(4))
    S['blk_delay_ms'] = round(S['blk_delay_sum'] / S['blk_accepted']) if S['blk_accepted'] else 0
    holds = [(num(a), int(b)) for a, b in re.findall(r'DEFEND held ([\d.]+) s, swings (\d+)', txt)]
    know = {}
    for name, rest in re.findall(r'KNOW (.+?): ([^\n]*)', txt): know[name] = rest
    out.update(S=S, chars=chars, opens=opens, fins=fins, stun_by=stun_by, held_why=held_why, holds=holds, know=know,
               refused_by=collections.Counter(re.findall(r'refused: (.+?) \(no stamp moved', txt)),
               checks=re.findall(r'research check: [^\n]*', txt), probes=re.findall(r'probe result: [^\n]*', txt),
               late=collections.Counter(re.findall(r'not refused after all: (.+?) started', txt)),
               hooks=re.findall(r'second press: [A-Z][^\n]*(?:hooked|absent)[^\n]*', txt),
               state_sec=state_sec, rev_pairs=rev_pairs,
               flanks=len(re.findall(r'Target blocking', txt)), flank_by=collections.Counter(re.findall(r'Target blocking \(([^)]*)\) -> flanking', txt)),
               gates=collections.Counter(re.findall(r'\| block stopped by (.+?)(?: \([\d.]+ s more to run\))?, [\d.]+ s before', txt)),
               chase=[int(d) for nm, d in re.findall(r'DEFEND: \S+ \([^:()]*:([^()]*)\) swinging at us from (\d+) studs', txt) if 'Chase' in nm],
               health=len(re.findall(r'\] health: \d+% \|', txt)), dodges=len(re.findall(r'\] dodge: [^\n]* - stepping out to the (?:left|right)', txt)))
    return out

def pct(a, b): return '%.0f%%' % (100.0 * a / b) if b else 'n/a'

def report(r):
    S = r['S']; dur = S['dur'] or 1
    print('=' * 78); print('%s  |  build %s' % (r['path'].split('/')[-1], r['build']))
    print('lives %d over %.1f min  |  characters: %s' % (r['lives'], dur / 60, ', '.join('%s x%d' % kv for kv in r['chars'].most_common(8))))
    rows = [('Kills and deaths', '%d and %d' % (r['kills'], r['lives'])),
            ('Damage per second', '%.2f' % (S['dmg'] / dur)),
            ('Damage dealt for each 1 taken', '%.2f' % (S['dmg'] / S['taken']) if S['taken'] else 'n/a (no "took" figure before v90)'),
            ('Time spent stunned', pct(S['stunned'], dur)),
            ('Raw casts that landed', '%s (%d of %d)' % (pct(S['neutral_h'], S['neutral_n']), S['neutral_h'], S['neutral_n'])),
            ('Chained casts that landed', '%s (%d of %d)' % (pct(S['confirm_h'], S['confirm_n']), S['confirm_h'], S['confirm_n'])),
            ('Punish casts that landed', '%s (%d of %d)' % (pct(S['punish_h'], S['punish_n']), S['punish_h'], S['punish_n'])),
            ('Basic attacks that landed', '%s (%d of %d, %.0f dmg)' % (pct(S['m1_h'], S['m1_n']), S['m1_h'], S['m1_n'], S['m1_d'])),
            ('Basic swings per minute', '%.1f' % (60.0 * S['m1_n'] / dur)),
            ('Flank lines per minute', '%.1f (%d)' % (60.0 * r['flanks'] / dur, r['flanks'])),
            ('Path computes per minute', '%.1f (%d)' % (60.0 * S['computes'] / dur, S['computes'])),
            ('Casts refused', '%s (%d of %d)' % (pct(S['refused'], S['moves'] + S['refused']), S['refused'], S['moves'] + S['refused'])),
            ('Predicted blocks that met a swing', '%s (%d of %d)' % (pct(S['preguard_met'], S['preguard']), S['preguard_met'], S['preguard'])),
            ('Escapes', '%d of %d tries' % (S['escapes'], S['bursts'])),
            ('Backward share of travel', '%.0f%%' % (S['back_sum'] / S['back_n']) if S['back_n'] else 'n/a')]
    if r['holds']:
        h = r['holds']
        rows += [('Blocks lasting 0.1 s or less', pct(sum(1 for a, _ in h if a <= 0.1), len(h))), ('Blocks that met no swing', pct(sum(1 for _, b in h if b == 0), len(h)))]
    w = max(len(a) for a, _ in rows)
    for a, b in rows: print('  %-*s  %s' % (w, a, b))
    if S['held'] or S['probes'] or S['p2_cast'] or S['openN']:
        print('\nKnowledge and fight sense')
        print('  casts withheld %d (%s) | probes %d | counters %d | guard-breaks %d | ground hits %d | M1 held off %.0fs' % (
            S['held'], ', '.join('%s x%d' % kv for kv in r['held_why'].most_common(4)), S['probes'], S['kcounters'], S['breaks'], S['ground'], S['m1held']))
        print('  second presses %d of %d (%d lost to a stun) | held casts %d | refusals that were not %d' % (S['p2_sent'], S['p2_cast'], S['p2_lost'], S['hold_casts'], S['late']))
        print('  finishers: ' + (', '.join('%s x%d (net %+.1f each)' % (k, v[0], v[1] / v[0]) for k, v in r['fins'].items() if v[0]) or 'none'))
        print('  dash punches %d (%d landed) | wake-up: swung through %d, guarded theirs %d, stunned while immune %d' % (S['dash'], S['dash_hit'], S['wake_swing'], S['wake_guard'], S['wake_stunned']))
        if r.get('m1bands'): print('  swings by distance (career): %s | reach taken as %s' % (r['m1bands'], r['m1reach']))
        if S['cast_faced']: print('  casts that had to be turned onto the target: %d of %d' % (S['cast_turned'], S['cast_faced']))
    if S['blk_raised'] or S['path_n'] or S['stale'] or r['state_sec']:
        tot = sum(r['state_sec'].values()) or 1; revs = sum(r['rev_pairs'].values()) or 1
        print('\nMeasurement (v93)')
        print('  blocks raised %d | taken by the server %d (%s, after %d ms) | took a hit %d (%s of raised)' % (
            S['blk_raised'], S['blk_accepted'], pct(S['blk_accepted'], S['blk_raised']), S['blk_delay_ms'], S['blk_absorbed'], pct(S['blk_absorbed'], S['blk_raised'])))
        print('  swings thrown with our own InSkill set: %d of %d (%s)' % (S['swing_inskill'], S['swing_probe_n'], pct(S['swing_inskill'], S['swing_probe_n'])))
        print('  seconds per state: ' + (', '.join('%s %.0f (%s)' % (k, v, pct(v, tot)) for k, v in r['state_sec'].most_common(14)) or 'none'))
        print('  reversals fell between (top three of each life): ' + (', '.join('%s x%d (%s)' % (k, v, pct(v, revs)) for k, v in r['rev_pairs'].most_common(6)) or 'none'))
        print('  path computes %d, %d with the target in sight (%s) | stale frames dropped %d | log flushes %d (worst %.0f ms)' % (
            S['path_n'], S['path_seen'], pct(S['path_seen'], S['path_n']), S['stale'], S['flushes'], S['flush_worst']))
        print('  reactions latched %d | aimed dodges %d | health lines %d' % (S['latched'], r['dodges'], r['health']))
        if r['flank_by']: print('  flank lines by detector: ' + ', '.join('%s x%d' % kv for kv in r['flank_by'].most_common(4)))
        if r['chase']: print('  front-dash latches %d, first seen at 13 studs or more: %d (%s)' % (len(r['chase']), sum(1 for d in r['chase'] if d >= 13), pct(sum(1 for d in r['chase'] if d >= 13), len(r['chase']))))
    for title, c in (('Where stun time came from', r['stun_by']), ('What we were doing when a hit got in', r['opens']), ('What stopped a block when a hit got in', r['gates']), ('Refused casts by move', r['refused_by']), ('Refusals that were not', r['late'])):
        if c:
            tot = sum(c.values()); print('\n%s' % title)
            for k, v in c.most_common(9): print('  %4d  %4s  %s' % (v, pct(v, tot), k))
    if r['know']:
        print('\nMoves (last KNOW line each)')
        for name in sorted(r['know'])[:60]: print('  %-22s %s' % (name[:22], r['know'][name][:210]))
    for title, lst in (('Research checks', r['checks']), ('Probe results', r['probes']), ('Second-press hooks', r['hooks'][-1:])):
        if lst:
            print('\n%s' % title)
            for l in lst[:12]: print('  ' + l[:200])

def compare(rs):
    """One row per measure, one column per log, in the order given."""
    def cols(f): return [f(r) for r in rs]
    def rate(a, b): return lambda r: pct(r['S'][a], r['S'][b])
    rows = [('Build', cols(lambda r: r['build'])),
            ('Lives, minutes', cols(lambda r: '%d, %.0f' % (r['lives'], r['S']['dur'] / 60))),
            ('Kills per life', cols(lambda r: '%.2f' % (r['kills'] / r['lives']) if r['lives'] else 'n/a')),
            ('Damage per second', cols(lambda r: '%.2f' % (r['S']['dmg'] / (r['S']['dur'] or 1)))),
            ('Dealt for each 1 taken', cols(lambda r: '%.2f' % (r['S']['dmg'] / r['S']['taken']) if r['S']['taken'] else 'n/a')),
            ('Time stunned', cols(lambda r: pct(r['S']['stunned'], r['S']['dur']))),
            ('Raw casts landed', cols(rate('neutral_h', 'neutral_n'))),
            ('Chained casts landed', cols(rate('confirm_h', 'confirm_n'))),
            ('Chained casts per minute', cols(lambda r: '%.1f' % (60.0 * r['S']['confirm_n'] / (r['S']['dur'] or 1)))),
            ('Basic attacks landed', cols(rate('m1_h', 'm1_n'))),
            ('Basic swings per minute', cols(lambda r: '%.1f' % (60.0 * r['S']['m1_n'] / (r['S']['dur'] or 1)))),
            ('Flank lines per minute', cols(lambda r: '%.1f' % (60.0 * r['flanks'] / (r['S']['dur'] or 1)))),
            ('Path computes per minute', cols(lambda r: '%.1f' % (60.0 * r['S']['computes'] / (r['S']['dur'] or 1)))),
            ('Blocks taken by the server', cols(rate('blk_accepted', 'blk_raised'))),
            ('Blocks that took a hit', cols(rate('blk_absorbed', 'blk_raised'))),
            ('Casts refused', cols(lambda r: pct(r['S']['refused'], r['S']['moves'] + r['S']['refused']))),
            ('Predicted blocks met a swing', cols(rate('preguard_met', 'preguard'))),
            ('Escapes of tries', cols(rate('escapes', 'bursts'))),
            ('Blocks of 0.1 s or less', cols(lambda r: pct(sum(1 for a, _ in r['holds'] if a <= 0.1), len(r['holds'])))),
            ('Dash punches landed', cols(rate('dash_hit', 'dash'))),
            ('Second presses sent', cols(rate('p2_sent', 'p2_cast')))]
    w0 = max(len(a) for a, _ in rows); wc = max(12, max(len(str(c)) for _, cs in rows for c in cs))
    print('=' * 78); print('BEFORE AND AFTER (logs in the order given)')
    for a, cs in rows: print('  %-*s  %s' % (w0, a, '  '.join('%*s' % (wc, c) for c in cs)))

if __name__ == '__main__':
    if len(sys.argv) < 2: sys.exit(__doc__)
    rs = [analyse(p) for p in sys.argv[1:]]
    for r in rs: report(r)
    if len(rs) > 1: compare(rs)
