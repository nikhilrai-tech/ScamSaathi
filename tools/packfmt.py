"""Write a rule pack in a stable, review-friendly layout (one signal per block). Used by the training and tuning tools."""
import json  # formats packs/core/pack.json the same way every time so diffs stay readable
def fmt(v): return json.dumps(v, ensure_ascii=False)
def sig(s):
    lines = ['    {' + ", ".join(f'"{k}": {fmt(s[k])}' for k in ("id","type") if k in s)]
    rest = [k for k in ("feature","match","weight","family") if k in s]
    if rest: lines[0] += ", " + ", ".join(f'"{k}": {fmt(s[k])}' for k in rest)
    for k in ("phrases","unless","any_permissions","any_actions","min_sensitive","brand_names"):
        if k in s: lines.append(f'     "{k}": {fmt(s[k])}')
    known = {"id","type","feature","match","weight","family","phrases","unless","any_permissions","any_actions","min_sensitive","brand_names","reason"}
    assert set(s) <= known, f"packfmt would silently drop: {sorted(set(s) - known)}"  # never lose a field again
    lines.append(f'     "reason": {{"en": {fmt(s["reason"]["en"])},\n                "hi": {fmt(s["reason"]["hi"])}}}}}')
    return ",\n".join(lines)
def dump(pack, path):
    out = ['{', f'  "schema_version": {pack["schema_version"]},', f'  "version": {pack["version"]},', f'  "name": {fmt(pack["name"])},',
           f'  "thresholds": {fmt(pack["thresholds"])},', f'  "families": {fmt(pack["families"])},']
    if pack.get("weak_families"): out.append(f'  "weak_families": {fmt(pack["weak_families"])},')
    out.append('  "lists": {')
    L = pack["lists"]; keys = list(L)
    for i, k in enumerate(keys):
        v = L[k]
        if isinstance(v, dict):
            out.append(f'    "{k}": {{\n' + ",\n".join(f'      "{b}": {fmt(o)}' for b, o in v.items()) + '\n    }' + ("," if i < len(keys)-1 else ""))
        else:
            out.append(f'    "{k}": {fmt(v)}' + ("," if i < len(keys)-1 else ""))
    out.append('  },')
    out.append('  "signals": [\n' + ",\n".join(sig(s) for s in pack["signals"]) + '\n  ]' + (',' if pack.get('model') else ''))
    if pack.get('model'):
        m = pack['model']
        out.append('  "model": {' + ', '.join(f'"{k}": {fmt(v)}' for k, v in m.items() if k != 'weights') + ',')
        out.append('    "weights": {' + ', '.join(f'{fmt(g)}: {w}' for g, w in sorted(m['weights'].items())) + '}}')
    out.append('}')
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
