---
name: qwen-remotion
description: Use when asked to make a technical explainer video with the installed Remotion sample; fill one JSON template and render an MP4 without writing layout code or leaving unrelated sample labels.
---

# Qwen Remotion

You write CONTENT only. The script draws the diagram, places every box and arrow, animates it, and checks that no text clips and nothing overlaps.

1. Copy `templates/content.json` to `<work>/content.json`. It is a filled example; replace all of its text.
2. `title` names the topic once. `subtitle` says what the viewer will understand.
3. `lanes`: 1-4 groups of parts that work side by side (subsystems, parallel units, levels, stages). Each lane has a `name` and 1-6 `parts`, each `["Label", "detail"]`.
   - Label (≤18 chars): the exact name this domain uses. Labels are unique; links and scenes repeat them exactly.
   - Detail (≤28 chars): what the part does or holds, with the real number when the domain has one (angle, ratio, size, order).
   - Each lane is a row drawn left to right in your order; order parts so linked parts in neighbouring lanes line up.
4. `links`: `["From", "To", "verb"]`. The verb (≤14 chars) says what From does to To ("drives", "opens", "splits"); use "" for no label. Every part needs a link. A link back to an earlier part draws a loop; links between lanes show how parts drive each other.
5. `scenes`: 3-8 scenes of 7 s, in teaching order. Each has:
   - `say` (≤110 chars): the narration for this moment, what changes and why. Never a list of labels or a copy of a detail.
   - `focus`: `{"Label": "state"}` for every part active now. The state (≤14 chars) is its value in this scene ("open", "x = 3", "full"), or "".
   - A part appears in the first scene that focuses it, so the diagram can grow. Focus every part in some scene; change states between scenes to show what moves.
6. Run exactly `scripts/make.sh <work>/content.json <work>/output`.
7. If it prints `FIX: ...`, make exactly that change in content.json and rerun step 6. Repeat until it prints `"status":"rendered"`, then use `output/exports/video.mp4` and `output/poster.png`. Never edit the scripts; review only facts, link directions and states.

| Common failure | Fix |
| --- | --- |
| `FIX: ... does not fit` / `is N chars` | Shorten that exact text to the number of characters given. |
| `FIX: ... overlaps ...` / `runs through part` | Set the named verb to "", reorder parts in that lane, or drop the least important link. |
| `FIX: ... is not a part label` / `never in a scene focus` | Copy the label exactly from `lanes`, or add the part to a scene's focus. |
| `sample Remotion install missing` | Run `scripts/setup.sh` to install Remotion dependencies locally in this skill directory. |
