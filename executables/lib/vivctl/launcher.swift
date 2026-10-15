// launcher: the "Vivaldi Ctl" app, a Dock icon and default browser that always lands in the
// Vivaldi run by vivctl.
//
// A Vivaldi started from its own Dock icon opens the default profile and has no control
// channel. This app is what to click and what to register as the default browser instead:
//
//   clicked, vivctl not running     -> `vivctl start`, which starts Vivaldi on the vivctl profile
//   clicked, vivctl running         -> bring that Vivaldi to the front, or open a window if none is
//                                      (the daemon knows; minimized windows and other Spaces count)
//   a link, vivctl not running      -> `vivctl start`, then hand the link over
//   a link, vivctl running          -> hand the link over (no Touch ID needed for that)
//   Vivaldi runs on the profile without vivctl -> ask whether to restart it under vivctl
//
// Handing over a link means starting the Vivaldi binary with the same --user-data-dir: Chromium
// then passes the URL to the running instance and exits. The app quits once it is done.
//
// Configuration comes from keys in its Info.plist, written by `vivctl install-app`:
// VivctlPath (the vivctl wrapper), VivctlProfile, VivctlHome, VivaldiBinary.
//
//   vivaldi-ctl --plan [URL...]   print what a launch would do, and do nothing (for tests)

import AppKit

struct Config {
    let vivctl: String
    let profile: String
    let home: String
    let vivaldi: String

    static func load() -> Config? {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let vivctl = info["VivctlPath"] as? String, let profile = info["VivctlProfile"] as? String,
              let home = info["VivctlHome"] as? String, let vivaldi = info["VivaldiBinary"] as? String else { return nil }
        return Config(vivctl: vivctl, profile: profile, home: home, vivaldi: vivaldi)
    }

    // A Dock launch gets a minimal PATH, without Homebrew's node.
    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        env["VIVCTL_PROFILE"] = profile
        env["VIVCTL_HOME"] = home
        return env
    }
}

struct Result { let code: Int32; let out: String; let err: String }

func run(_ path: String, _ args: [String], _ config: Config) -> Result {
    let p = Process(), out = Pipe(), err = Pipe()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.environment = config.environment
    p.standardOutput = out
    p.standardError = err
    do { try p.run() } catch { return Result(code: -1, out: "", err: "\(error)") }
    let o = out.fileHandleForReading.readDataToEndOfFile(), e = err.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return Result(code: p.terminationStatus, out: String(decoding: o, as: UTF8.self), err: String(decoding: e, as: UTF8.self))
}

// What the daemon reports, or nil when it is not running. "windowless" is exact: the daemon sees
// every browser window, minimized ones and those on another Space included.
func daemonStatus(_ config: Config) -> [String: Any]? {
    let r = run(config.vivctl, ["status", "--json"], config)
    guard r.code == 0 else { return nil }
    return (try? JSONSerialization.jsonObject(with: Data(r.out.utf8))) as? [String: Any] ?? [:]
}

// Main Vivaldi processes on our profile, and whether each was started by vivctl (has the pipe).
func vivaldiProcesses(_ config: Config) -> [(pid: pid_t, piped: Bool)] {
    let ps = run("/bin/ps", ["-axww", "-o", "pid=,command="], config)
    let flag = "--user-data-dir=" + config.profile
    return ps.out.split(separator: "\n").compactMap { line in
        let s = line.trimmingCharacters(in: .whitespaces)
        guard let space = s.firstIndex(of: " "), let pid = pid_t(s[..<space]) else { return nil }
        let cmd = String(s[space...]).trimmingCharacters(in: .whitespaces)
        guard cmd.hasPrefix(config.vivaldi + " "), !cmd.contains("--type="),
              cmd.hasSuffix(flag) || cmd.contains(flag + " ") else { return nil }
        return (pid, cmd.contains("--remote-debugging-pipe"))
    }
}

enum Plan {
    case start([String])
    case handover([String])
    case activate(pid_t)
    case newWindow(pid_t)
    case askRestart(pid_t, [String])

    var text: String {
        switch self {
        case .start(let u): return "start" + (u.isEmpty ? "" : " then hand over \(u.count) URL(s)")
        case .handover(let u): return "hand over \(u.count) URL(s)"
        case .activate: return "activate"
        case .newWindow: return "open a window"
        case .askRestart(_, let u): return "ask to restart" + (u.isEmpty ? "" : " (\(u.count) URL(s) waiting)")
        }
    }
}

func plan(_ config: Config, _ urls: [String]) -> Plan {
    let procs = vivaldiProcesses(config)
    guard let status = daemonStatus(config) else {
        if let lone = procs.first(where: { !$0.piped }) { return .askRestart(lone.pid, urls) }
        return .start(urls)
    }
    // Hand over only to a Vivaldi that is there: without one, the handover would start a new
    // Vivaldi without the control channel.
    guard let ours = procs.first(where: { $0.piped }) ?? procs.first else { return .start(urls) }
    if !urls.isEmpty { return .handover(urls) }
    return (status["windowless"] as? Bool) == true ? .newWindow(ours.pid) : .activate(ours.pid)
}

final class Launcher: NSObject, NSApplicationDelegate {
    let config: Config
    var pending: [String] = []
    var scheduled = false

    init(config: Config) { self.config = config }

    func application(_ app: NSApplication, open urls: [URL]) {
        pending += urls.map { $0.absoluteString }
        schedule()
    }
    func applicationDidFinishLaunching(_ note: Notification) { schedule() }

    // Links arrive as an event right after the launch; wait a moment to collect them.
    func schedule() {
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let urls = self.pending
            self.pending = []
            self.execute(plan(self.config, urls))
            self.scheduled = false
            if self.pending.isEmpty { NSApp.terminate(nil) } else { self.schedule() }
        }
    }

    func execute(_ p: Plan) {
        switch p {
        case .start(let urls):
            let r = run(config.vivctl, ["start"], config)
            guard r.code == 0 else {
                return alert("vivctl could not start Vivaldi", r.err + r.out + "\nSee \(config.home)/daemon.log.")
            }
            if !urls.isEmpty { handover(urls) }
            if let ours = vivaldiProcesses(config).first(where: { $0.piped }) { activate(ours.pid) }
        case .handover(let urls):
            handover(urls)
        case .activate(let pid):
            activate(pid)
        case .newWindow(let pid):
            handover([])
            activate(pid)
        case .askRestart(let pid, let urls):
            NSApp.activate()
            let a = NSAlert()
            a.messageText = "Vivaldi runs without vivctl"
            a.informativeText = "Vivaldi was started on the vivctl profile without the control channel, so vivctl "
                + "cannot reach it. Restart it under vivctl? Vivaldi restores its tabs."
            a.addButton(withTitle: "Restart")
            a.addButton(withTitle: "Leave It")
            if a.runModal() == .alertFirstButtonReturn {
                guard quit(pid) else { return alert("Vivaldi did not quit", "Quit it yourself, then click Vivaldi Ctl again.") }
                execute(.start(urls))
            } else if !urls.isEmpty {
                handover(urls)
            } else {
                activate(pid)
            }
        }
    }

    func handover(_ urls: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: config.vivaldi)
        p.arguments = ["--user-data-dir=" + config.profile] + urls
        p.environment = config.environment
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()   // not waited for: it passes the URLs on and exits by itself
    }

    func activate(_ pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        NSApp.yieldActivation(to: app)
        app.activate()
    }

    // The same as Cmd+Q, then wait for it to be gone.
    func quit(_ pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return true }
        app.terminate()
        for _ in 0..<80 where !app.isTerminated { Thread.sleep(forTimeInterval: 0.25) }
        return app.isTerminated
    }

    func alert(_ title: String, _ text: String) {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}

guard let config = Config.load() else {
    FileHandle.standardError.write(Data("vivaldi-ctl: Info.plist lacks the vivctl keys, reinstall with `vivctl install-app`\n".utf8))
    exit(1)
}
let args = Array(CommandLine.arguments.dropFirst())
if args.first == "--plan" {
    print(plan(config, Array(args.dropFirst())).text)
    exit(0)
}
let app = NSApplication.shared
let launcher = Launcher(config: config)
app.delegate = launcher
app.setActivationPolicy(.accessory)
app.run()
