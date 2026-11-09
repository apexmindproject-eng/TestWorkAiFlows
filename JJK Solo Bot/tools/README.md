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
