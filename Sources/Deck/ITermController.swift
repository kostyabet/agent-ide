import Foundation

enum ITermController {
    /// Launches `claude` in a new iTerm tab under `cwd`, tagged with DECK_AGENT_ID.
    /// Returns the iTerm session id used later to focus it, or nil on failure.
    @discardableResult
    static func launch(agentId: String, cwd: String, name: String = "") -> String? {
        let command = "cd \(shellQuote(cwd)) && DECK_AGENT_ID=\(agentId) claude"
        let setName = name.isEmpty ? "" : "set name of s to \(appleScriptString(name))"
        let script = """
        tell application "iTerm"
            activate
            if (count of windows) = 0 then
                set w to (create window with default profile)
                set s to current session of w
            else
                tell current window
                    set t to (create tab with default profile)
                    set s to current session of t
                end tell
            end if
            tell s
                \(setName)
                write text \(appleScriptString(command))
            end tell
            return id of s
        end tell
        """
        return runAppleScript(script)
    }

    /// Brings the given iTerm session to the front.
    @discardableResult
    static func focus(sessionId: String) -> Bool {
        guard !sessionId.isEmpty else { return false }
        let script = """
        tell application "iTerm"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if id of s is \(appleScriptString(sessionId)) then
                            select w
                            tell t to select
                            tell s to select
                            return "ok"
                        end if
                    end repeat
                end repeat
            end repeat
            return "missing"
        end tell
        """
        return runAppleScript(script) == "ok"
    }

    // MARK: helpers

    @discardableResult
    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error { NSLog("Deck AppleScript error: \(error)"); return nil }
        return result.stringValue
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }
}
