---
name: qwen-prompt-architect
description: Turn a bare topic (2-6 words) plus a target qwen-<tool> skill into a rich, checked design brief (brief.md). Writes the brief only; never makes the artifact.
---
# Qwen Prompt Architect
Input: a bare topic, a target skill `qwen-<tool>`, and the path to save `brief.md`.
Output: only `brief.md`. Do not make the artifact and do not run the target skill.

1. Read the target skill. Open exactly two files: `../qwen-<tool>/SKILL.md` and `../qwen-<tool>/templates/content.json`
   (paths relative to this skill directory). Read nothing else. Write down:
   - the content fields the template accepts (for example title, parts, groups, links, slides, rows, takeaway);
   - each numbered content rule in its SKILL.md: how a link is written (a links field, or text inside a field
     such as `slide N`) and required items (for example a worked example with real values, real symbols);
   - its count limits: most parts, links, groups, parts per group, slides.
2. Brainstorm the topic before writing. Note:
   - 8-20 real named parts or subsystems (use the names an expert would use);
   - relationships: what moves between parts (material, energy, force, signal, data);
   - loops and feedback: what is sensed, and what gets corrected. The first loop controls the CORE IDEA quantity:
     the part where it is measured -> the controller part -> the actuator part, all three in PARTS;
   - branches and failure paths: what happens when a condition is met or a part fails;
   - a bypass, relief or backup part is a side path `upstream part -> bypass part -> downstream part`,
     never `bypass part -> the part it skips`;
   - groups: which parts belong to one subsystem;
   - key quantities with units: only well-known values, each written as "typical";
   - one takeaway that agrees with every part and relationship.
   Check each fact: does this part really act on that part, in that direction?
3. Copy `templates/brief.md` (this skill) to the save path and replace every `<...>` with real content.
   Keep the 12 section names exactly as written, each followed by ":".
   - PARTS: 8-20 short names separated by ";", never more than the target's part limit; aim close to it.
   - GROUPS: within the target's group limits. If the target shows groups as rows, sizes differ by at most one.
   - RELATIONSHIPS: 6 or more lines, one link per line: `- Part A -> Part B: what flows`, within the target's link limit.
     Copy both part names exactly from PARTS. One source and one target per line. Every part needs at least one line.
   - LOOPS/FEEDBACK and BRANCHES/FAILURES: one per line, `- Part A -> Part B -> Part C: what happens`.
     Every hop (A -> B, B -> C) must also be a RELATIONSHIPS line.
   - NUMBERS: write "typical" before each value. Never invent precise specs.
     If the target needs a worked example, give its typical inputs and the result here.
   - MAP-TO-TEMPLATE: map PARTS, GROUPS, RELATIONSHIPS, LOOPS/FEEDBACK, BRANCHES/FAILURES, NUMBERS and TAKEAWAY
     to the target's real field or link form from step 1, for example `LOOPS/FEEDBACK -> links`
     or `LOOPS/FEEDBACK -> rows value "back to slide N"`. Meet its required items (worked example, real symbols).
   - Never put layout in the brief: no x/y, positions, pixel sizes, or colors. The target skill does layout.
   - Total length: 8-40 lines. No text before ARTIFACT and no code fences.
4. Run `scripts/check_brief.sh <save path>/brief.md qwen-<tool>` from this skill directory.
   It prints one JSON line. If `"ok":false`, apply every hint in `"fix"` to brief.md and run it again.
   Stop after 3 tries even if it still fails.
5. Reply with the brief path and the last check result. Do not make the artifact.

To run both stages with `scripts/two-stage.sh`, set `HERMES_MODEL` and `HERMES_PROVIDER` to your own Hermes configuration. The runner has no account-specific provider or model defaults.

| Error | Fix |
|---|---|
| Target skill not found | Check the tool name; it must be a `qwen-<tool>` skill next to this one. |
| Endpoint not in PARTS | Rename the endpoint to the exact PARTS name, or add that part to PARTS. |
| Part has no link, or loop/branch hop not linked | Add the missing `- A -> B: what flows` line to RELATIONSHIPS. |
| Coordinates or layout found | Delete the position, size or color; describe only what the part does. |
