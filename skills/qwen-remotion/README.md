# Qwen Remotion

A content-only wrapper skill for local language models, tuned on qwen3.8-27b. Fill the template and render a structured explainer video without writing layout code.

## Install

Run `scripts/setup.sh` (Node.js and npm required), then use the generic skill installation steps in the hub README.

## Usage

Copy `templates/content.json` to a work directory, replace its sample content, then run `scripts/make.sh <work>/content.json <work>/output`. A successful render writes `output/exports/video.mp4` and `output/poster.png`.

## Best attempt and scores

Best version: v2, score 6.0/10 (attempt 1: 5.3, attempt 2: 6.0, attempt 3: 5.5). Scores are an AI critic assessment, not a benchmark.

## License

This wrapper is MIT licensed. Remotion is a separately installed third-party dependency; its own license and terms apply. Companies should review Remotion's current licensing terms and determine whether a company license is required before commercial use.
