# Qwen wrapper optimization loop

## Purpose and experiment

The wrappers are designed to help a weak local model produce useful visual artifacts without bespoke human instructions. Each attempt uses a one-sentence prompt and the selected wrapper skill; model output is reviewed, scored, and used to guide a generic skill change.

## Attempt cycle

1. Generate one artifact using only the topic prompt and the wrapper skill. Record the model, run status, media, and timing.
2. A separate critic inspects the complete output (all slides, or representative video frames), then rates technical accuracy, diagram quality, phone-size readability, layout, skill adherence, and density from 1–10. Overall is the mean of the six dimensions, rounded to one decimal. Distinguish limits of the rendering medium from fixable skill defects.
3. For attempts before the final one, a rewriter addresses the most important confirmed causes by changing only that skill. Changes must help across topics, not encode the next prompt. Smoke-test the change on a different kind of topic and inspect the result.
4. Record changes and evidence with the attempt; do not make an untested change after the final attempt.

## Keep-best

An attempt uses version N. Keep the version with the best comparable overall score; ties go to the earlier version. If an attempt scores below the current best, base the next change on the best version rather than stacking changes on the weaker one. After the final attempt restore the best-scoring skill version.

## Design lessons

- The model should supply content, not low-level geometry. Keep positions, sizes, and routing in deterministic renderers; validate collisions, clipping, and overflow and return concise repair hints.
- Add complexity only to address a confirmed root cause; prefer reducing the choices and text the model must process.
- Separate limitations of the chosen visual medium from mistakes the skill can prevent.
- Smoke-test using a topic structurally different from the previous one, and inspect the rendered result.
- For non-linear systems, preserve groups, parallel lanes, feedback loops, and cross-links while leaving layout automatic.
- In animation, distinguish an element being visible from a flow being active. Ensure motion agrees with the narrated state.
- For diagrams with branches and loops, support explicit phases independent of card ordering, and route back-edges and branches automatically.
