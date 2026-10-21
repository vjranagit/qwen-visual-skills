#!/usr/bin/env bash
# Usage: two-stage.sh <tool> "<bare topic>" <dir>
# Stage 1: the configured Hermes model + qwen-prompt-architect writes <dir>/brief.md from the bare topic.
# Stage 2: a separate fresh session using the configured Hermes model runs qwen-<tool> on that brief.
# The driver only pipes files: it never writes or edits brief.md. Records both sessions in <dir>/two-stage.json.
# Env: HERMES_MODEL and HERMES_PROVIDER are required; ARTIFACT overrides the artifact phrase; HERMES_TIMEOUT bounds each stage.
set -euo pipefail

[ $# -eq 3 ] || { echo 'usage: two-stage.sh <tool> "<bare topic>" <dir>' >&2; exit 64; }
tool=${1#qwen-}
topic=$2
dir=$(realpath -m -- "$3")
skill_dir=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
repo=$(cd "$skill_dir/../.." && pwd)
timeout_s=${HERMES_TIMEOUT:-1500}
model=${HERMES_MODEL:?Set HERMES_MODEL to the Hermes model name}
provider=${HERMES_PROVIDER:?Set HERMES_PROVIDER to the Hermes provider name}

case $tool in
  antv-infographic)  default_artifact="a dense infographic cheat sheet" ;;
  svg-infographic)   default_artifact="a dense one-page technical infographic" ;;
  carousel)          default_artifact="a dense 6-8 slide carousel" ;;
  diagram-design)    default_artifact="a dense technical diagram" ;;
  baoyu-diagram)     default_artifact="a dense architecture/flow diagram" ;;
  canvas-design)     default_artifact="a dense technical poster" ;;
  visual-explainer)  default_artifact="a dense explainer page" ;;
  live-panel)        default_artifact="a dense live animated panel" ;;
  slack-gif-creator) default_artifact="a dense animated GIF" ;;
  video-shotcraft)   default_artifact="a dense explainer video" ;;
  remotion)          default_artifact="a dense animated explainer video" ;;
  *)                 default_artifact="" ;;
esac
artifact=${ARTIFACT:-$default_artifact}
[ -n "$artifact" ] || { echo "unknown tool '$tool': set ARTIFACT=\"<artifact phrase>\"" >&2; exit 64; }
[ -f "$skill_dir/../qwen-$tool/SKILL.md" ] || { echo "target skill qwen-$tool not found in $(dirname "$skill_dir")" >&2; exit 64; }

mkdir -p "$dir/out"
brief="$dir/brief.md"
[ ! -e "$brief" ] || { echo "$brief already exists; use a fresh <dir> so stage 1 writes its own brief" >&2; exit 65; }

# run_stage <n> <skill> <prompt>: one fresh oneshot Hermes session; sets sid_<n>, rc_<n>, wall_<n>.
run_stage() {
  local n=$1 skill=$2 prompt=$3 log="$dir/stage$1.log" t0 t1 rc sid
  t0=$(date +%s.%N)
  set +e
  (cd "$repo" && env -u DISPLAY -u WAYLAND_DISPLAY timeout "$timeout_s" \
    hermes chat --oneshot --yolo -m "$model" --provider "$provider" --pass-session-id \
    -s "$skill" -q "$prompt") >"$log" 2>&1 </dev/null
  rc=$?
  set -e
  t1=$(date +%s.%N)
  # Keep a session ID only when Hermes reports it in the command output.
  sid=$(grep -aoE '(hermes --resume|session_id:) +[0-9A-Za-z_]+' "$log" | tail -n 1 | awk '{print $NF}' || true)
  printf -v "sid_$n" '%s' "$sid"
  printf -v "rc_$n" '%s' "$rc"
  printf -v "wall_$n" '%s' "$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')"
  printf -v "prompt_$n" '%s' "$prompt"
}

record() {  # writes <dir>/two-stage.json from the stage variables; prints it
  TS_TOOL="qwen-$tool" TS_TOPIC="$topic" TS_ARTIFACT="$artifact" TS_DIR="$dir" TS_MODEL="$model" TS_PROVIDER="$provider" \
  TS_P1="${prompt_1-}" TS_SID1="${sid_1-}" TS_RC1="${rc_1-}" TS_W1="${wall_1-}" \
  TS_P2="${prompt_2-}" TS_SID2="${sid_2-}" TS_RC2="${rc_2-}" TS_W2="${wall_2-}" \
  TS_CHECK="${check-}" TS_SHA_BEFORE="${sha_before-}" TS_SHA_AFTER="${sha_after-}" TS_STATUS="$1" \
  python3 - <<'PY'
import json, os
e = os.environ
def stage(n):
    sid = e.get(f"TS_SID{n}", "")
    if not e.get(f"TS_P{n}"):
        return None
    return {"skill": "qwen-prompt-architect" if n == 1 else e["TS_TOOL"], "prompt": e[f"TS_P{n}"],
            "session_id": sid or None, "model_requested": e["TS_MODEL"], "provider_requested": e["TS_PROVIDER"],
            "exit_code": int(e[f"TS_RC{n}"]), "wall_seconds": float(e[f"TS_W{n}"]), "log": f"stage{n}.log"}
s1, s2 = stage(1), stage(2)
status = e["TS_STATUS"]
try:
    check = json.loads(e["TS_CHECK"]) if e.get("TS_CHECK") else None
except ValueError:
    check = {"raw": e["TS_CHECK"]}
out = {"tool": e["TS_TOOL"], "topic": e["TS_TOPIC"], "artifact": e["TS_ARTIFACT"], "dir": e["TS_DIR"],
       "status": status, "brief": "brief.md", "brief_check": check,
       "brief_sha256": e.get("TS_SHA_BEFORE") or None,
       "brief_unchanged_by_stage2": (e["TS_SHA_BEFORE"] == e["TS_SHA_AFTER"]) if e.get("TS_SHA_AFTER") else None,
       "stage1": s1, "stage2": s2}
with open(os.path.join(e["TS_DIR"], "two-stage.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, indent=1, ensure_ascii=False)
    f.write("\n")
print(json.dumps(out, ensure_ascii=False))
raise SystemExit(0 if status == "ok" else 1)
PY
}

run_stage 1 qwen-prompt-architect \
  "Use the qwen-prompt-architect skill to write a design brief for the qwen-$tool skill about: $topic. Save it to $brief"
if [ ! -s "$brief" ]; then
  echo "stage 1 produced no $brief (exit $rc_1); see $dir/stage1.log" >&2
  record failed  # exits non-zero
fi
check=$("$skill_dir/scripts/check_brief.sh" "$brief" "qwen-$tool" || true)  # recorded for the critic; brief is passed on as-is
sha_before=$(sha256sum -- "$brief" | cut -d' ' -f1)

run_stage 2 "qwen-$tool" \
  "Use the qwen-$tool skill to make $artifact from this brief. Save everything to $dir/out/

$(cat -- "$brief")"
sha_after=$(sha256sum -- "$brief" | cut -d' ' -f1)

# record exits non-zero unless both stages exited 0.
if [ "$rc_1" -eq 0 ] && [ "$rc_2" -eq 0 ]; then record ok; else record failed; fi
