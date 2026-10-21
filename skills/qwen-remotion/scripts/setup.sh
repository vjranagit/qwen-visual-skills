#!/usr/bin/env bash
set -euo pipefail
skill=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v node >/dev/null || { echo 'Node.js is required' >&2; exit 1; }
command -v npm >/dev/null || { echo 'npm is required' >&2; exit 1; }
cd "$skill"
npm install --no-save --no-package-lock remotion@^4.0.0 @remotion/cli@^4.0.0 react@^18.0.0 react-dom@^18.0.0
