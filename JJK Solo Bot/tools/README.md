# Place-file tools

Small readers used to produce §17 and Appendix C of `REVERSE_ENGINEERING_REFERENCE.md`
from a UniversalSynSaveInstance `.rbxl`. They treat the file strictly as data.

Requires Python 3 with `lz4` and `zstandard`.

```
python3 parse_rbxl.py game.rbxl tree.pkl      # instance tree, string/number props, parents
python3 extract.py tree.pkl scripts/          # every script's Source to a file, plus _index.json
python3 digest.py scripts/<Controller>.lua    # services, remotes, effect keys, attributes, assets
```

`attrs.py` decodes the binary `AttributesSerialize` blob on an instance
(`decode(props["AttributesSerialize"])`).

What to look at first after a game update:

1. `UpdateLogController` for the version string and the change list.
2. `ReplicatedStorage/Knit/Knit/Services/*/RE|RF/*` in the tree for the full remote list.
3. The `v_u_25` table near the top of `ToolController` for per-move argument codes,
   which is what `MoveRules[...].code` in the bot must match.
4. `ReplicatedStorage/Modules/ListData` and `UltNames` for roster and move names.

## Move research

`../research/group1.json` to `group5.json` hold what the public wiki and guides
say about each move (274 entries) and about general combat mechanics (90
facts), with a source URL on every entry. They were read from web-search
extracts, not from the pages.

`gen_facts.py` turns them into the `MoveFacts` table the bot carries and the
catalogue in section 18 of the reference:

```
python3 -I gen_facts.py ../JJK_Solo_Bot.lua ../research facts.lua catalogue.md
```

## Reading a log

```
python3 -I analyze_log.py <log.txt> [more logs...]
```

Prints kills and deaths, hit rates by kind of cast, where stun time came from,
what the bot was doing when hits got in, refusals by move, finishers, second
presses and every `KNOW` line. Older logs simply lack the newer sections.

## Checking the script

```
python3 -I lint_globals.py ../JJK_Solo_Bot.lua
python3 test_tactics.py ../JJK_Solo_Bot.lua
```

`lint_globals.py` lists names that are read as globals and never assigned,
which is how a call to a missing function shows up. It needs `luaparser`.

