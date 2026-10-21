# Lessons from Qwen wrapper iterations

These notes summarize recurring findings from the wrapper experiments.

1. **Keep geometry deterministic.** A version that asked the model to choose node coordinates and typed links produced collisions, clipping, and worse adherence. The model should supply labels, order, groups, and concise notes; scripts should lay out and validate the result.
2. **Avoid growing the prompt surface without evidence.** New fields, options, or instructions need a confirmed critic root cause. Prefer fewer choices and report instruction/template size changes.
3. **Separate tool limits from skill defects.** If a topic requires a visual capability the renderer lacks, record the limitation rather than trying to teach around it.
4. **Inspect cross-domain smoke tests.** Use a fixture unlike the preceding topic and view the output; a successful process exit alone is insufficient.
5. **Keep the best version, not the latest.** Compare comparable scores, prefer earlier version on ties, and do not build on a known regression.
6. **Represent complex topics as relationships.** Dense systems need parallel groups, feedback, branches, and cross-links rather than a linear card stack. Preserve automatic layout.
7. **Animate state and flow separately.** A focused component is not necessarily active; encode active links for each scene and check that animation matches the narrated system state.
8. **Coordinate events independently of card order.** Shared phase rows and automatic routing allow back-edges and branches without misleading chronology.
