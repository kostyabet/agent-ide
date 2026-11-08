import Foundation

enum HookInstaller {
    static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: Paths.hookScript.path) && settingsContainHook()
    }

    /// Writes the hook script into ~/.deck and merges it into ~/.claude/settings.json,
    /// leaving every existing hook (cc-status, pandev, …) untouched. Returns an error
    /// string on failure, nil on success.
    static func install() -> String? {
        Paths.ensureDeckDir()

        // 1. hook script
        do {
            try hookSource.write(to: Paths.hookScript, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                  ofItemAtPath: Paths.hookScript.path)
        } catch {
            return "Не удалось записать хук-скрипт: \(error.localizedDescription)"
        }

        // 2. settings.json
        guard let data = try? Data(contentsOf: Paths.claudeSettings),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return "Не удалось прочитать ~/.claude/settings.json"
        }

        // backup first
        let backup = Paths.claudeSettings.appendingPathExtension("deck-backup")
        try? data.write(to: backup)

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = Paths.hookScript.path
        let ourGroup: [String: Any] = ["hooks": [["type": "command", "command": command]]]

        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            if !groups.contains(where: { groupMentionsDeck($0) }) {
                groups.append(ourGroup)
            }
            hooks[event] = groups
        }
        root["hooks"] = hooks

        guard let out = try? JSONSerialization.data(withJSONObject: root,
                                                    options: [.prettyPrinted]) else {
            return "Не удалось сериализовать settings.json"
        }
        do {
            try out.write(to: Paths.claudeSettings)
        } catch {
            return "Не удалось записать settings.json: \(error.localizedDescription)"
        }
        return nil
    }

    private static func settingsContainHook() -> Bool {
        guard let data = try? Data(contentsOf: Paths.claudeSettings),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any] else { return false }
        for event in events {
            if let groups = hooks[event] as? [[String: Any]],
               groups.contains(where: { groupMentionsDeck($0) }) {
                return true
            }
        }
        return false
    }

    private static func groupMentionsDeck(_ group: [String: Any]) -> Bool {
        guard let inner = group["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String)?.contains("deck-hook") == true }
    }

    /// Kept in sync with scripts/deck-hook.py.
    private static let hookSource = """
    #!/usr/bin/env python3
    import json, os, sys, time

    DECK_DIR = os.path.join(os.path.expanduser("~"), ".deck")
    EVENTS = os.path.join(DECK_DIR, "events.jsonl")


    def short_detail(tool_name, tool_input):
        if not isinstance(tool_input, dict):
            return ""
        for key in ("file_path", "path", "command", "pattern", "url", "query"):
            val = tool_input.get(key)
            if isinstance(val, str) and val:
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
        record = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "event": data.get("hook_event_name", ""),
            "agent_id": os.environ.get("DECK_AGENT_ID", ""),
            "session_id": data.get("session_id", ""),
            "cwd": data.get("cwd", ""),
            "transcript_path": data.get("transcript_path", ""),
            "tool": data.get("tool_name", ""),
            "detail": short_detail(data.get("tool_name", ""), data.get("tool_input")),
        }
        try:
            os.makedirs(DECK_DIR, exist_ok=True)
            with open(EVENTS, "a") as f:
                f.write(json.dumps(record) + "\\n")
        except Exception:
            pass
        sys.exit(0)


    if __name__ == "__main__":
        main()
    """
}
