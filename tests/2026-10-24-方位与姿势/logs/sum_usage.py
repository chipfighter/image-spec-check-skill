"""汇总子代理对话记录（JSONL）里每次 API 调用的 token 用量。
用法：py -I sum_usage.py 标签=记录文件路径 ...
同一条 assistant 消息会分成多行写入，按 message.id 去重，只算一次。"""
import json
import sys

FIELDS = ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"]

print("标签\t调用次数\t" + "\t".join(FIELDS) + "\t合计")
for arg in sys.argv[1:]:
    label, path = arg.split("=", 1)
    calls = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            msg = rec.get("message") or {}
            if rec.get("type") != "assistant" or not msg.get("usage"):
                continue
            calls[msg.get("id") or len(calls)] = msg["usage"]
    sums = [sum(u.get(k, 0) or 0 for u in calls.values()) for k in FIELDS]
    print(f"{label}\t{len(calls)}\t" + "\t".join(str(s) for s in sums) + f"\t{sum(sums)}")
