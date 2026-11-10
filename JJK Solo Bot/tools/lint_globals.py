#!/usr/bin/env python3
"""Scope-aware scan: names read as globals that are never assigned anywhere in the script.
usage: python3 -I lint_globals.py <bot.lua>"""
import re, sys
from luaparser import ast, astnodes as N
src = open(sys.argv[1], encoding='utf-8').read()
src = re.sub(r'"[A-Za-z0-9+/=]{2000,}"', '"x"', src)
tree = ast.parse(src)
BUILTIN = set('''_G _VERSION assert collectgarbage error getmetatable setmetatable ipairs pairs next pcall xpcall print select
tonumber tostring type unpack rawget rawset rawequal rawlen require string table math os coroutine debug utf8 bit32 buffer
game workspace script task tick time wait delay spawn warn typeof Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum
Ray RaycastParams OverlapParams TweenInfo NumberRange NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint
Rect Region3 BrickColor Random DateTime Font PhysicalProperties shared newproxy loadstring getfenv setfenv gcinfo elapsedTime
getgenv getrenv gethui getcustomasset getsynasset writefile readfile isfile isfolder makefolder appendfile delfile listfiles
setclipboard toclipboard identifyexecutor getexecutorname syn fluxus cloneref hookfunction hookmetamethod getnamecallmethod
checkcaller newcclosure getrawmetatable setreadonly isreadonly getconnections firesignal fireclickdetector firetouchinterest
fireproximityprompt request http_request http queue_on_teleport getgc getupvalues setupvalue getupvalue getconstants
sethiddenproperty gethiddenproperty setfpscap getfpscap isrbxactive mouse1click mouse1press mouse1release keypress keyrelease
Drawing crypt base64 lz4compress lz4decompress protect_gui getinstances getnilinstances getloadedmodules getscripts
getcallingscript getsenv decompile saveinstance settings UserSettings PluginManager stats version Axes Faces CatalogSearchParams
PathWaypoint DockWidgetPluginGuiInfo SharedTable vector'''.split())
assigned, reads = set(), {}
def names_of(targets):
    out = []
    for t in targets:
        if isinstance(t, N.Name): out.append(t.id)
    return out
def visit(node, scope):
    if node is None: return
    if isinstance(node, list):
        for x in node: visit(x, scope)
        return
    if not isinstance(node, N.Node): return
    if isinstance(node, (N.Chunk,)):
        visit(node.body, scope); return
    if isinstance(node, N.Block):
        inner = dict(scope) if False else scope
        local = set()
        sc = scope + [local]
        for st in node.body: visit(st, sc)
        return
    if isinstance(node, N.LocalAssign):
        visit(node.values, scope)
        for t in node.targets:
            if isinstance(t, N.Name): scope[-1].add(t.id)
        return
    if isinstance(node, N.LocalFunction):
        scope[-1].add(node.name.id)
        fn = set(a.id for a in node.args if isinstance(a, N.Name))
        visit(node.body, scope + [fn]); return
    if isinstance(node, (N.Function, N.Method)):
        nm = node.name
        if isinstance(node, N.Function):
            if isinstance(nm, N.Name):
                if not any(nm.id in s for s in scope): assigned.add(nm.id)
            else: visit(nm, scope)
        else:
            visit(node.source, scope)
        fn = set(a.id for a in node.args if isinstance(a, N.Name))
        if isinstance(node, N.Method): fn.add('self')
        visit(node.body, scope + [fn]); return
    if isinstance(node, N.AnonymousFunction):
        fn = set(a.id for a in node.args if isinstance(a, N.Name))
        visit(node.body, scope + [fn]); return
    if isinstance(node, N.Assign):
        visit(node.values, scope)
        for t in node.targets:
            if isinstance(t, N.Name):
                if not any(t.id in s for s in scope): assigned.add(t.id)
            else: visit(t, scope)
        return
    if isinstance(node, N.Fornum):
        visit([node.start, node.stop, node.step], scope)
        visit(node.body, scope + [{node.target.id}]); return
    if isinstance(node, N.Forin):
        visit(node.iter, scope)
        visit(node.body, scope + [set(t.id for t in node.targets if isinstance(t, N.Name))]); return
    if isinstance(node, N.Repeat):
        local = set(); sc = scope + [local]
        for st in node.body.body: visit(st, sc)
        visit(node.cond, sc); return
    if isinstance(node, N.Name):
        if not any(node.id in s for s in scope):
            reads.setdefault(node.id, []).append(getattr(node, 'line', None) or (node.first_token.line if getattr(node, 'first_token', None) else 0))
        return
    if isinstance(node, N.Index):
        visit(node.value, scope)
        if not (isinstance(node.idx, N.Name) and getattr(node, 'notation', None) is not None and str(node.notation).endswith('DOT')):
            visit(node.idx, scope)
        return
    if isinstance(node, N.Invoke):
        visit(node.source, scope); visit(node.args, scope); return
    if isinstance(node, N.Field):
        if not isinstance(node.key, N.Name) or getattr(node, 'between_brackets', False): visit(node.key, scope)
        visit(node.value, scope); return
    for k, v in vars(node).items():
        if k.startswith('_') or k in ('comments', 'first_token', 'last_token', 'line'): continue
        if isinstance(v, (N.Node, list)): visit(v, scope)
visit(tree, [set()])
undefined = {k: v for k, v in reads.items() if k not in assigned and k not in BUILTIN}
print(len(assigned), 'globals assigned;', len(reads), 'global names read;', len(undefined), 'read but never assigned')
for k in sorted(undefined, key=lambda x: -len(undefined[x])):
    ls = [l for l in undefined[k] if l]
    print('%-28s x%-3d %s' % (k, len(undefined[k]), ls[:6]))
