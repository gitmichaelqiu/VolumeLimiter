import Cocoa
import SwiftUI

// This is the core logic that handles the "Re-scaling"
// 0-100% on your slider = 0-20% on the System.
class VolumeManager: ObservableObject {
    @Published var displayVolume: Double = 0 {
        didSet {
            updateSystemVolume()
        }
    }
    
    private let maxHardwareVolume: Double = 20.0 // Your 20% Limit
    
    init() {
        // Fetch current system volume and map it back to our 0-100 scale
        let currentSysVol = getSystemVolume()
        self.displayVolume = (currentSysVol / maxHardwareVolume) * 100.0
    }
    
    func getSystemVolume() -> Double {
        var scriptOutput: NSAppleEventDescriptor?
        let script = NSAppleScript(source: "output volume of (get volume settings)")
        scriptOutput = script?.executeAndReturnError(nil)
        return Double(scriptOutput?.int32Value ?? 0)
    }
    
    func updateSystemVolume() {
        // Map 0-100 to 0-20
        let targetVolume = (displayVolume / 100.0) * maxHardwareVolume
        let script = NSAppleScript(source: "set volume output volume \(targetVolume)")
        script?.executeAndReturnError(nil)
    }
    
    // Call this for precise keyboard adjustments (e.g., +1 unit on our 0-100 scale)
    func adjustVolume(by amount: Double) {
        let newValue = displayVolume + amount
        displayVolume = max(0, min(100, newValue))
    }
}

// Simple UI for the Menu Bar Popover
struct VolumeSliderView: View {
    @ObservedObject var manager: VolumeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AirPods Precision Control")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "speaker.wave.1.fill")
                Slider(value: $manager.displayVolume, in: 0...100)
                Image(systemName: "speaker.wave.3.fill")
                Text("\(Int(manager.displayVolume))%")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 40)
            }
            
            Divider()
            
            Text("Range Limited to 0-20%")
                .font(.system(size: 9))
                .italic()
        }
        .padding()
        .frame(width: 250)
    }
}

// AppDelegate to handle the Menu Bar Item
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    let volumeManager = VolumeManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the SwiftUI view
        let contentView = VolumeSliderView(manager: volumeManager)

        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 100)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover

        // Create the status bar item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = self.statusBarItem.button {
            // FIX: Using systemSymbolName for AppKit/macOS
            if let icon = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Volume Limiter") {
                icon.isTemplate = true // Ensures it works with Dark Mode
                button.image = icon
            }
            button.action = #selector(togglePopover(_:))
        }
        
        // Monitor for Volume Keys
        // Note: Real keyboard overriding requires Accessibility Permissions in macOS.
        // This is a global monitor for media keys.
        NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self else { return }
            let keyCode = ((event.data1 & 0xFFFF0000) >> 16)
            let keyFlags = (event.data1 & 0x0000FFFF)
            let keyPressed = (keyFlags & 0xFF00) >> 8
            
            if keyPressed == 0x0A { // Key Down
                if keyCode == 0 { // Volume Up
                    self.volumeManager.adjustVolume(by: 1.0) // Moves by 1% of the 20% limit
                } else if keyCode == 1 { // Volume Down
                    self.volumeManager.adjustVolume(by: -1.0)
                }
            }
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
