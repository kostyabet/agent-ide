#!/usr/bin/env python3
"""Deck hook: appends one JSON line per Claude Code event to ~/.deck/events.jsonl.

Installed alongside the user's existing hooks (cc-status, pandev) — it only reads
stdin and appends; it never blocks or mutates anything else. Must exit 0 always so
it can never interfere with the Claude Code session it observes.
"""
import json
import os
import sys
import time

DECK_DIR = os.path.join(os.path.expanduser("~"), ".deck")
EVENTS = os.path.join(DECK_DIR, "events.jsonl")


def short_detail(tool_name, tool_input):
    if not isinstance(tool_input, dict):
        return ""
    for key in ("file_path", "path", "command", "pattern", "url", "query"):
        val = tool_input.get(key)
        if isinstance(val, str) and val:
            # keep it short; basename for paths
            if key in ("file_path", "path"):
                return os.path.basename(val)
            return val[:80]
    return ""


def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    event = data.get("hook_event_name", "")
    tool_name = data.get("tool_name", "")
    detail = short_detail(tool_name, data.get("tool_input"))

    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "event": event,
        "agent_id": os.environ.get("DECK_AGENT_ID", ""),
        "session_id": data.get("session_id", ""),
        "cwd": data.get("cwd", ""),
        "transcript_path": data.get("transcript_path", ""),
        "tool": tool_name,
        "detail": detail,
    }

    try:
        os.makedirs(DECK_DIR, exist_ok=True)
        # append is atomic for small lines on local fs
        with open(EVENTS, "a") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
