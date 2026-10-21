#!/usr/bin/env bash
# Render content.json into a 1920x1080 30 fps H.264 explainer MP4.
# Layout, animation and geometry checks are script-owned (prepare.cjs, video.tsx).
# Any content problem exits 4 with one "FIX: ..." line.
set -euo pipefail
[[ $# -eq 2 ]] || { echo 'usage: scripts/make.sh <content.json> <out-dir>' >&2; exit 2; }
skill=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
content=$(realpath "$1"); out=$(realpath -m "$2")
[[ -f "$content" ]] || { echo "FIX: content JSON missing: $1"; exit 4; }
[[ -x "$skill/node_modules/.bin/remotion" ]] || { echo 'Remotion dependencies missing; run scripts/setup.sh' >&2; exit 3; }
mkdir -p "$out/project/src" "$out/exports"
node "$skill/scripts/prepare.cjs" "$content" "$out/project/src/data.json"
cp "$skill/scripts/video.tsx" "$out/project/src/video.tsx"
printf '{"private":true,"type":"module"}\n' >"$out/project/package.json"
ln -sfn "$skill/node_modules" "$out/project/node_modules"
video="$out/exports/video.mp4"; log="$out/render.log"
if ! (cd "$out/project" && env -u DISPLAY -u WAYLAND_DISPLAY ./node_modules/.bin/remotion render src/video.tsx Explainer "$video" --codec=h264 --crf=18) >"$log" 2>&1; then
  fix=$(grep -o 'FIX: .*' "$log" | head -n 1 || true)
  if [[ -n "$fix" ]]; then echo "$fix"; exit 4; fi
  echo "render failed; last lines of $log:" >&2; tail -n 15 "$log" >&2; exit 1
fi
ffmpeg -v error -i "$video" -f null -
scenes=$(node -e 'console.log(require(process.argv[1]).scenes.length)' "$out/project/src/data.json")
ffmpeg -y -v error -ss $(( scenes * 7 - 3 )) -i "$video" -frames:v 1 "$out/poster.png"
probe=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name -show_entries format=duration -of json "$video")
PROBE="$probe" OUT="$out" node -e 'const fs=require("fs"),p=JSON.parse(process.env.PROBE),s=p.streams[0],f=p.format,o=process.env.OUT;if(!s||s.width!==1920||s.height!==1080||s.r_frame_rate!=="30/1"||s.codec_name!=="h264"||!Number(f.duration)||fs.statSync(o+"/exports/video.mp4").size<10000){console.error("render produced an invalid video; rerun make.sh");process.exit(1)}console.log(JSON.stringify({status:"rendered",path:o+"/exports/video.mp4",poster:o+"/poster.png",width:s.width,height:s.height,fps:s.r_frame_rate,codec:s.codec_name,duration_s:Number(f.duration)}))'
