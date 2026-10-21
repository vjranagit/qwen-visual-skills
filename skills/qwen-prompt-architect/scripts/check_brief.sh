#!/usr/bin/env bash
# Usage: check_brief.sh <brief.md> <target skill, e.g. qwen-svg-infographic>
# Prints exactly one JSON line: {"ok":true,...} or {"ok":false,"errors":[...],"fix":[...]}. Exit 0 only when ok.
set -uo pipefail
command -v python3 >/dev/null || { echo '{"ok":false,"errors":["python3 missing"],"fix":["Report it: python3 is required by check_brief.sh."]}'; exit 1; }
SKILLS_DIR=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
exec python3 - "$SKILLS_DIR" "$@" <<'PY'
import json, os, re, sys

SECTIONS = ["ARTIFACT", "AUDIENCE", "CORE IDEA", "PARTS", "GROUPS", "RELATIONSHIPS", "LOOPS/FEEDBACK",
            "BRANCHES/FAILURES", "NUMBERS", "EMPHASIS", "TAKEAWAY", "MAP-TO-TEMPLATE"]
errors, fixes = [], []

def fail(code, hint):
    errors.append(code)
    fixes.append(hint)

def finish(**extra):
    out = {"ok": not errors, **extra}
    if errors:
        out["errors"], out["fix"] = errors, fixes
    print(json.dumps(out, ensure_ascii=False))
    sys.exit(0 if not errors else 1)

skills_dir, args = sys.argv[1], sys.argv[2:]
if len(args) != 2:
    fail("usage", "Run: scripts/check_brief.sh <path>/brief.md qwen-<tool>")
    finish()
brief_path, target = args
tool = target if target.startswith("qwen-") else "qwen-" + target

# Target skill: its content template defines the field names MAP-TO-TEMPLATE may use.
target_dir = next((d for d in (os.path.join(skills_dir, tool), os.path.expanduser("~/.hermes/skills/creative/" + tool))
                   if os.path.isfile(os.path.join(d, "SKILL.md"))), None)
fields = set()
if target_dir is None:
    fail("target_missing", f"Target skill {tool} not found next to qwen-prompt-architect; pass the exact qwen-<tool> name.")
else:
    def collect(node):
        if isinstance(node, dict):
            for k, v in node.items():
                fields.add(k.lower())
                collect(v)
        elif isinstance(node, list):
            for v in node:
                collect(v)
    try:
        with open(os.path.join(target_dir, "templates", "content.json"), encoding="utf-8") as f:
            collect(json.load(f))
    except (OSError, ValueError):
        pass  # no readable content template: field-name check is skipped

try:
    with open(brief_path, encoding="utf-8") as f:
        raw_lines = f.read().splitlines()
except (OSError, UnicodeDecodeError) as e:
    fail("brief_unreadable", f"Write the brief to {brief_path} first ({e.__class__.__name__}).")
    finish()

lines = [l.rstrip() for l in raw_lines if l.strip()]
n_lines = len(lines)
if not 8 <= n_lines <= 40:
    fail("length", f"Brief has {n_lines} non-empty lines; keep it 8-40 (one short line per section, list lines only for RELATIONSHIPS/PARTS).")

# Parse sections. Header = optional markdown decoration + exact section name + ":".
header_re = re.compile(r"^\s*(?:#+\s*)?\**\s*(" + "|".join(re.escape(s) for s in SECTIONS) + r")\s*\**\s*:\s*\**\s*(.*)$", re.I)
body, order, current, stray = {}, [], None, []
for l in lines:
    m = header_re.match(l)
    if m:
        current = m.group(1).upper()
        if current in body:
            fail("duplicate_section", f"Section {current}: appears twice; merge into one.")
        body.setdefault(current, [])
        order.append(current)
        if m.group(2).strip():
            body[current].append(m.group(2).strip())
    elif current is None:
        stray.append(l.strip())
    else:
        body[current].append(l.strip())
if stray:
    fail("text_before_artifact", f"Delete the {len(stray)} line(s) before 'ARTIFACT:' (first: {stray[0][:40]!r}); no titles or code fences.")
if any(l.strip().startswith("```") for l in lines):
    fail("code_fence", "Remove the ``` code fence lines; write plain text.")

missing = [s for s in SECTIONS if s not in body]
empty = [s for s in SECTIONS if s in body and not body[s]]
if missing:
    fail("missing_sections", "Add these sections, each as 'NAME: content' on its own line: " + ", ".join(missing) + ".")
if empty:
    fail("empty_sections", "Fill these empty sections: " + ", ".join(empty) + ".")
placeholders = [s for s in body if any(re.search(r"<[A-Za-z][^<>]{0,80}>", t) for t in body[s])]
if placeholders:
    fail("placeholders", "Replace every <...> placeholder with real content in: " + ", ".join(placeholders) + ".")

def items(section):
    out = []
    for t in body.get(section, []):
        t = re.sub(r"^\s*(?:[-*\u2022]|\d+[.)])\s+", "", t)
        out += [p.strip() for p in t.split(";") if p.strip()]
    return out

def norm(name):
    name = name.strip().strip("*`\"'").strip()
    name = re.split(r"\s*[(:\u2014]|\s+-\s+", name, 1)[0]  # drop "(note)", ": note", " - note"
    return re.sub(r"\s+", " ", name).strip(" .,").lower()

parts = [p for p in (norm(i) for i in items("PARTS")) if p]
part_set = set(parts)
if "PARTS" in body:
    dups = sorted({p for p in parts if parts.count(p) > 1})
    if dups:
        fail("duplicate_parts", "List each part once in PARTS; duplicates: " + ", ".join(dups) + ".")
    if not 8 <= len(part_set) <= 20:
        fail("parts_count", f"PARTS has {len(part_set)} distinct parts; list 8-20 short names separated by ';'"
             + (" (split subsystems into their real named parts)." if len(part_set) < 8 else " (merge minor parts into their subsystem)."))

arrow = re.compile(r"\s*(?:->|\u2192)\s*")
rels, bad_format, bad_ends = [], [], []
for it in items("RELATIONSHIPS"):
    it = it.replace("\u2192", "->")
    m = re.match(r"^(.+?)\s*->\s*(.+?)\s*:\s*(.*\S)\s*$", it)
    if not m or arrow.search(m.group(2)) or "," in m.group(1) or "," in m.group(2):
        bad_format.append(it)
        continue
    a, b = norm(m.group(1)), norm(m.group(2))
    rels.append((a, b))
    for end in (a, b):
        if end not in part_set and end not in bad_ends:
            bad_ends.append(end)
if "RELATIONSHIPS" in body:
    if bad_format:
        fail("relationship_format", "Write each relationship as '- Part A -> Part B: what flows' (one source, one target, a label); fix: "
             + "; ".join(repr(x[:50]) for x in bad_format[:3]) + ".")
    if len(rels) < 6:
        fail("relationships_count", f"RELATIONSHIPS has {len(rels)} valid links; add at least {6 - len(rels)} more, one per line.")
    if bad_ends:
        fail("unknown_endpoints", "These relationship endpoints are not in PARTS: " + ", ".join(bad_ends[:6])
             + ". Copy the exact PARTS name or add the part to PARTS.")
    orphans = [p for p in parts if not any(p in r for r in rels)]
    if orphans and rels:
        fail("orphan_parts", "These PARTS have no RELATIONSHIPS line: " + ", ".join(orphans[:6])
             + ". For each, add what enters it and what it sends on ('- Source -> Part: what flows', '- Part -> Target: what flows'), or delete it from PARTS.")

# LOOPS/FEEDBACK and BRANCHES/FAILURES reuse RELATIONSHIPS links: '- A -> B -> C: note'; every hop must be a RELATIONSHIPS line.
rel_set = set(rels)
chains = {}
for sec in ("LOOPS/FEEDBACK", "BRANCHES/FAILURES"):
    bad_chain, unknown, missing_hops, n = [], [], [], 0
    for it in items(sec):
        chain, _, note = it.replace("\u2192", "->").partition(":")
        names = [norm(x) for x in re.split(r"\s*->\s*", chain)]
        if len(names) < 2 or not note.strip() or not all(names) or "," in chain:
            bad_chain.append(it)
            continue
        n += 1
        unknown += [x for x in names if x not in part_set and x not in unknown]
        missing_hops += [f"{a} -> {b}" for a, b in zip(names, names[1:]) if (a, b) not in rel_set and a in part_set and b in part_set]
    chains[sec] = n
    if sec not in body:
        continue
    if bad_chain:
        fail("chain_format", f"Write each {sec} line as '- Part A -> Part B -> Part C: what happens' using PARTS names, the note after the parts; fix: "
             + "; ".join(repr(x[:50]) for x in bad_chain[:2]) + ".")
    if unknown:
        fail("chain_unknown_parts", f"{sec} names parts not in PARTS: " + ", ".join(unknown[:6]) + ". Add each to PARTS with its RELATIONSHIPS lines, or use an existing PARTS name.")
    if missing_hops:
        fail("chain_hop_not_linked", f"{sec} hops missing from RELATIONSHIPS: " + "; ".join(missing_hops[:6])
             + ". Add each as '- A -> B: what flows' in RELATIONSHIPS, or correct the chain.")

# No layout decisions (Lesson L1): coordinates, pixel sizes, colors.
layout_patterns = [
    (r"\b[xy]\s*[:=]\s*-?\d", "x/y coordinates"),
    (r"\(\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*\)", "coordinate pairs like (120, 40)"),
    (r"\b(?:left|top|right|bottom|width|height|position)\s*[:=]\s*-?\d", "positions or sizes"),
    (r"\b\d+\s*px\b", "pixel sizes"),
    (r"#(?=[0-9a-f]*[a-f])(?:[0-9a-f]{3}){1,2}\b", "hex colors"),
]
found = [label for pat, label in layout_patterns if any(re.search(pat, l, re.I) for l in lines)]
if found:
    fail("coordinates", "Remove layout from the brief (" + ", ".join(found) + "); describe parts and flows only, the target skill does layout.")

if "MAP-TO-TEMPLATE" in body:
    map_items = items("MAP-TO-TEMPLATE")
    must_map = ["PARTS", "GROUPS", "RELATIONSHIPS", "LOOPS/FEEDBACK", "BRANCHES/FAILURES", "NUMBERS", "TAKEAWAY"]
    lhs = " ".join(it.split("->", 1)[0] for it in map_items if "->" in it).upper()
    not_mapped = [s for s in must_map if not re.search(r"(?<![A-Z/])" + re.escape(s) + r"(?![A-Z/])", lhs)]
    if not_mapped:
        fail("map_missing", "MAP-TO-TEMPLATE must map " + ", ".join(not_mapped)
             + " to the target's real field or link form from its SKILL.md (e.g. 'LOOPS/FEEDBACK -> links').")
    unmapped = []
    for it in map_items if fields else []:
        rhs = it.split("->", 1)[1] if "->" in it else ""
        if not rhs or not any(w.lower() in fields for w in re.findall(r"[A-Za-z_]+", rhs)):
            unmapped.append(it)
    if unmapped:
        fail("map_fields", f"MAP-TO-TEMPLATE entries must read 'SECTION -> field' using {tool} template fields ("
             + ", ".join(sorted(fields)) + "); fix: " + "; ".join(repr(x[:40]) for x in unmapped[:3]) + ".")

finish(parts=len(part_set), relationships=len(rels), loops=chains["LOOPS/FEEDBACK"], branches=chains["BRANCHES/FAILURES"],
       lines=n_lines, target=tool)
PY
