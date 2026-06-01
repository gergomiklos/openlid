import Cocoa

// NoSleepAgent menu bar indicator.
//
// Shows, at a glance, whether the Mac is currently being kept awake — i.e.
// whether it's safe to close the lid without killing a running agent. It reads
// ground truth from `pmset -g` (the SleepDisabled flag the daemon toggles), so
// it reflects the real system state, not just our intent. Runs as a user
// LaunchAgent; no Dock icon.
//
// Usage: nosleep-menubar <ctl.sh path> <enabled-flag path>

let ctlPath     = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let enabledPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""

// True when system sleep is disabled — the lid can be closed safely.
func sleepDisabled() -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["-g"]
    let pipe = Pipe()
    p.standardOutput = pipe
    do { try p.run() } catch { return false }
    p.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                     encoding: .utf8) ?? ""
    for line in out.split(separator: "\n") where line.contains("SleepDisabled") {
        let toks = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        if let i = toks.firstIndex(of: "SleepDisabled"), i + 1 < toks.count {
            return toks[i + 1] == "1"
        }
    }
    return false
}

// The master switch (`/nosleep on|off`). Missing/anything-but-0 means enabled.
func isEnabled() -> Bool {
    let v = (try? String(contentsOfFile: enabledPath, encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return v != "0"
}

func runCtl(_ arg: String) {
    guard !ctlPath.isEmpty else { return }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = [ctlPath, arg]
    try? p.run()
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let toggle = NSMenuItem(title: "", action: #selector(toggleSwitch), keyEquivalent: "")

    func applicationDidFinishLaunching(_ note: Notification) {
        let menu = NSMenu()
        header.isEnabled = false
        toggle.target = self
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        refresh()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in self.refresh() }
    }

    @objc func toggleSwitch() {
        runCtl(isEnabled() ? "off" : "on")
        // The daemon reacts within its poll interval; nudge the UI sooner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refresh() }
    }

    func refresh() {
        let awake = sleepDisabled()
        let symbol = awake ? "bolt.fill" : "moon.zzz.fill"
        if let img = NSImage(systemSymbolName: symbol,
                             accessibilityDescription: awake ? "Awake" : "Can sleep") {
            img.isTemplate = true
            item.button?.image = img
            item.button?.title = ""
        } else {
            item.button?.image = nil
            item.button?.title = awake ? "AWAKE" : "zZ"
        }
        header.title = awake ? "Awake — safe to close the lid"
                             : "Will sleep if you close the lid"
        toggle.title = isEnabled() ? "Pause keep-awake" : "Resume keep-awake"
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
