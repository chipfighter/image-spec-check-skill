#!/bin/bash
# 用法：gen.sh <组名> <提示词文件> <输出图片路径> [参考图...]
# 调用 Codex 生成一张图，复制到输出路径，并把这次调用的 token 用量记进 logs/codex_usage.tsv。
# 参考图会作为附件图 1、图 2……按顺序传入；提示词里要写明每张附件的作用。
# 环境变量：CODEX_EXE（codex 可执行文件，默认 codex）、CODEX_MODEL（默认 gpt-6.1-sol，本次测试用的就是它）。
T="$(cd "$(dirname "$0")" && pwd)"
EXE="${CODEX_EXE:-codex}"
MODEL="${CODEX_MODEL:-gpt-6.1-sol}"
arm=$1; prompt=$2; out=$3; shift 3
refs=(); for r in "$@"; do refs+=(-i "$r"); done
mkdir -p "$T/logs" "$(dirname "$out")"
name=$(basename "$out" .png)
for attempt in 1 2; do
  log="$T/logs/${arm}_${name}.$attempt"
  touch "$log.mark"
  cat "$T/_wrap.txt" "$prompt" | timeout 1500 "$EXE" exec --skip-git-repo-check -s read-only -C "$T" \
    -m "$MODEL" -c 'model_reasoning_effort="low"' --json -o "$log.txt" "${refs[@]}" > "$log.jsonl" 2> "$log.err"
  tid=$(grep -o '"thread_id":"[^"]*"' "$log.jsonl" | head -1 | cut -d'"' -f4)
  u=$(grep -o '"usage":{[^}]*}' "$log.jsonl" | tail -1)
  in=$(echo "$u" | grep -o '"input_tokens":[0-9]*' | cut -d: -f2)
  ca=$(echo "$u" | grep -o '"cached_input_tokens":[0-9]*' | cut -d: -f2)
  ou=$(echo "$u" | grep -o '"output_tokens":[0-9]*' | cut -d: -f2)
  img=""; [ -n "$tid" ] && img=$(find ~/.codex/generated_images/"$tid" -name '*.png' -newer "$log.mark" 2>/dev/null | head -1)
  ok=fail; [ -n "$img" ] && { cp "$img" "$out"; ok=ok; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%F_%T)" "$arm" "$name" "${in:-0}" "${ca:-0}" "${ou:-0}" "$ok" >> "$T/logs/codex_usage.tsv"
  rm -f "$log.mark"
  [ "$ok" = ok ] && { echo "OK $out"; exit 0; }
  lim=$(grep -o "hit your usage limit[^\"]*" "$log.jsonl" | head -1)
  [ -n "$lim" ] && { echo "Codex 额度用完，不要重试：$lim"; exit 1; }
  echo "attempt $attempt failed: $(tail -c 300 "$log.err" | tr '\n' ' ')"
done
exit 1
