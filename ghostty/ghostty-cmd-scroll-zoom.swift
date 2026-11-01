import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

private let ghosttyBundleIdentifier = "com.mitchellh.ghostty"
private let defaultPreciseScrollPointsPerStep = 9.0
private let preciseScrollPointsPerStep: Double = {
    let settingsPath = NSHomeDirectory() + "/.config/ghostty/cmd-scroll-zoom-scroll-threshold"
    guard let contents = try? String(contentsOfFile: settingsPath, encoding: .utf8),
          let value = Double(contents.trimmingCharacters(in: .whitespacesAndNewlines)),
          value.isFinite,
          value > 0 else {
        return defaultPreciseScrollPointsPerStep
    }
    return value
}()

private func log(_ message: String) {
    fputs("GhosttyCmdScrollZoom: \(message)\n", stderr)
}

private final class ZoomEventHandler {
    var eventTap: CFMachPort?
    private var accumulatedScroll = 0.0

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                log("Re-enabled the scroll event tap")
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        guard event.flags.contains(.maskCommand),
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ghosttyBundleIdentifier else {
            accumulatedScroll = 0
            return Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let pointDelta = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let delta: Double
        let threshold: Double

        if isContinuous && pointDelta != 0 {
            delta = pointDelta
            threshold = preciseScrollPointsPerStep
        } else {
            let fixedDelta = Double(event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)) / 65_536.0
            let wheelDelta = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            delta = wheelDelta != 0 ? wheelDelta : fixedDelta
            threshold = 1.0
        }

        guard delta != 0 else {
            return Unmanaged.passUnretained(event)
        }

        // A direction change starts a fresh partial step, avoiding a delayed
        // zoom when the user reverses direction before reaching the threshold.
        if accumulatedScroll != 0 && accumulatedScroll.sign != delta.sign {
            accumulatedScroll = 0
        }
        accumulatedScroll += delta

        while abs(accumulatedScroll) >= threshold {
            postFontSizeKey(increase: accumulatedScroll > 0)
            accumulatedScroll += accumulatedScroll > 0 ? -threshold : threshold
        }

        // Consume Command+vertical-scroll in Ghostty so tmux and terminal apps
        // do not also receive it as a scroll gesture.
        return nil
    }

    private func postFontSizeKey(increase: Bool) {
        let keyCode: CGKeyCode = increase ? CGKeyCode(kVK_ANSI_Equal) : CGKeyCode(kVK_ANSI_Minus)
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            log("Could not create a font-size key event")
            return
        }

        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

private let handler = ZoomEventHandler()

private let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
    handler.handle(type: type, event: event)
}

private func waitForPermission(
    _ name: String,
    preflight: () -> Bool,
    request: () -> Bool
) {
    guard !preflight() else { return }

    _ = request()
    log("Waiting for \(name) permission. Enable Ghostty Cmd Scroll Zoom in System Settings → Privacy & Security.")
    while !preflight() {
        Thread.sleep(forTimeInterval: 2)
    }
    log("\(name) permission granted")
}

func main() -> Never {
    waitForPermission("Input Monitoring", preflight: CGPreflightListenEventAccess, request: CGRequestListenEventAccess)
    waitForPermission("Accessibility", preflight: CGPreflightPostEventAccess, request: CGRequestPostEventAccess)

    let eventMask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: nil
    ) else {
        log("Could not create the scroll event tap. Check Input Monitoring and Accessibility permissions.")
        exit(EXIT_FAILURE)
    }

    handler.eventTap = tap
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
        log("Could not create the event-tap run-loop source")
        exit(EXIT_FAILURE)
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log("Ready: Command+vertical-scroll in Ghostty changes font size")
    CFRunLoopRun()
    exit(EXIT_SUCCESS)
}

main()
