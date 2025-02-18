//
//  AppDelegate.swift
//  LangSwitch
//
//  Created by ANTON NIKEEV on 05.07.2023.
//

import AppKit
import Carbon
import Foundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var currentAnimationID: UUID?
    var popupWindow: NSWindow?
    var dismissalWorkItem: DispatchWorkItem?
    var shouldShowPopup = true
    var aboutWindow: NSWindow?
    var globeKeyDownTimestamp: TimeInterval?
    var isGlobeKeyDown: Bool = false
    var minKeyPressDuration: TimeInterval = 200 // Default minimum duration
    var maxKeyPressDuration: TimeInterval = 1000 // Default maximum duration
    var tickLabelMin: NSTextField!
    var tickLabelMax: NSTextField!

    private let shouldShowPopupKey = "ShouldShowPopup"
    private let minKeyPressDurationKey = "MinKeyPressDurationKey"
    private let maxKeyPressDurationKey = "MaxKeyPressDurationKey"

    func applicationDidFinishLaunching(_: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem?.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)

        // Retrieve the saved values from UserDefaults, or use the default values if they don't exist
        if let savedMinDuration = UserDefaults.standard.object(forKey: minKeyPressDurationKey) as? Double {
            minKeyPressDuration = savedMinDuration
        } else {
            minKeyPressDuration = 200.0 // Default minimum duration
        }

        if let savedMaxDuration = UserDefaults.standard.object(forKey: maxKeyPressDurationKey) as? Double {
            maxKeyPressDuration = savedMaxDuration
        } else {
            maxKeyPressDuration = 1000.0 // Default maximum duration
        }

        print("minKeyPressDuration in settings: \(minKeyPressDuration)")
        print("maxKeyPressDuration in settings: \(maxKeyPressDuration)")

        if UserDefaults.standard.object(forKey: shouldShowPopupKey) == nil {
            shouldShowPopup = true
        }

        if maxKeyPressDuration == 0 {
            maxKeyPressDuration = 1000.0
        }

        // Modify the menu for the status bar item
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Enable popup", action: #selector(toggleShouldShowPopup), keyEquivalent: "")
        toggleItem.state = shouldShowPopup ? .on : .off // Set the initial state based on the flag
        menu.addItem(toggleItem)

        // Add a separator after the "Enable Popup" menu item
        menu.addItem(NSMenuItem.separator())

        // Min keypress delay slider
        let sliderMinMenuItem = createSliderMenuItem(title: "Min keypress delay", value: minKeyPressDuration, action: #selector(sliderMinValueChanged))
        menu.addItem(sliderMinMenuItem)

        // Max keypress delay slider
        let sliderMaxMenuItem = createSliderMenuItem(title: "Max keypress delay", value: maxKeyPressDuration, action: #selector(sliderMaxValueChanged))
        menu.addItem(sliderMaxMenuItem)

        // Add another separator before the "About" menu item
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "About", action: #selector(showAboutDialog), keyEquivalent: "")
        menu.addItem(withTitle: "Exit", action: #selector(exitAction), keyEquivalent: "")
        statusBarItem?.menu = menu

        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)

        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self = self else { return }

            let isGlobeKeyDownNow = event.modifierFlags.contains(.function)

            if self.isGlobeKeyDown != isGlobeKeyDownNow {
                if isGlobeKeyDownNow {
                    self.globeKeyDownTimestamp = event.timestamp
                    print("Fn key down at: \(event.timestamp)")
                } else {
                    if let keyDownTimestamp = self.globeKeyDownTimestamp {
                        let elapsedTime = (event.timestamp - keyDownTimestamp) * 1000

                        print("Fn key up at: \(event.timestamp)")
                        print("Elapsed time: \(elapsedTime)ms")

                        if elapsedTime > self.minKeyPressDuration && elapsedTime < self.maxKeyPressDuration {
                            print("Switching language...")
                            self.switchKeyboardLanguage()
                        } else {
                            print("Not switching language...")
                        }
                    }
                }
                self.isGlobeKeyDown = isGlobeKeyDownNow
            }
        }

        createAboutWindow()
    }

    @objc func sliderMinValueChanged(sender: NSSlider) {
        minKeyPressDuration = TimeInterval(sender.doubleValue)
        tickLabelMin.stringValue = "\(Int(minKeyPressDuration))ms"
        UserDefaults.standard.set(sender.doubleValue, forKey: minKeyPressDurationKey)
        UserDefaults.standard.synchronize() // Ensure the value is saved immediately
        print("sliderMinValueChanged: \(sender.doubleValue)")
    }

    @objc func sliderMaxValueChanged(sender: NSSlider) {
        maxKeyPressDuration = TimeInterval(sender.doubleValue)
        tickLabelMax.stringValue = "\(Int(maxKeyPressDuration))ms"
        UserDefaults.standard.set(sender.doubleValue, forKey: maxKeyPressDurationKey)
        UserDefaults.standard.synchronize() // Ensure the value is saved immediately
        print("sliderMaxValueChanged: \(sender.doubleValue)")
    }

    func createSliderMenuItem(title: String, value: Double, action: Selector) -> NSMenuItem {
        let label = NSTextField(labelWithString: title)
        label.isBezeled = false
        label.drawsBackground = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12)

        let tickLabel = NSTextField(labelWithString: "\(Int(value))ms")
        tickLabel.isBezeled = false
        tickLabel.drawsBackground = false
        tickLabel.alignment = .center
        tickLabel.font = NSFont.systemFont(ofSize: 10)

        print("create slider with value: \(value)")

        let slider = NSSlider(value: value, minValue: 0, maxValue: 1000, target: self, action: action)
        slider.numberOfTickMarks = 21
        slider.allowsTickMarkValuesOnly = true
        slider.tickMarkPosition = .below

        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 60))
        sliderContainer.addSubview(label)
        sliderContainer.addSubview(slider)
        sliderContainer.addSubview(tickLabel)

        label.frame = NSRect(x: 0, y: 40, width: 150, height: 20)
        slider.frame = NSRect(x: 10, y: 20, width: 140, height: 20)
        tickLabel.frame = NSRect(x: 0, y: 0, width: 150, height: 20)

        if title == "Min keypress delay" {
            tickLabelMin = tickLabel
        } else {
            tickLabelMax = tickLabel
        }

        let sliderMenuItem = NSMenuItem()
        sliderMenuItem.view = sliderContainer
        return sliderMenuItem
    }

    func createAboutWindow() {
        aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        aboutWindow?.center()
        aboutWindow?.title = "About LangSwitch"
        aboutWindow?.isReleasedWhenClosed = false // Add this line

        let iconImageView = NSImageView(frame: NSRect(x: 150 - 60, y: 150 - 40, width: 120, height: 120))
        iconImageView.image = NSImage(named: NSImage.Name("AppIcon")) // Updated this line
        aboutWindow?.contentView?.addSubview(iconImageView)

        let appNameLabel = NSTextField(frame: NSRect(x: 50, y: 80, width: 200, height: 20))
        appNameLabel.stringValue = "LangSwitch"
        appNameLabel.alignment = .center
        appNameLabel.font = NSFont.systemFont(ofSize: 18)
        appNameLabel.isBezeled = false
        appNameLabel.drawsBackground = false
        appNameLabel.isEditable = false
        appNameLabel.isSelectable = false
        aboutWindow?.contentView?.addSubview(appNameLabel)

        let authorLabel = NSTextField(frame: NSRect(x: 50, y: 55, width: 200, height: 20))
        authorLabel.stringValue = "Version 1.0"
        authorLabel.alignment = .center
        authorLabel.font = NSFont.systemFont(ofSize: 12)
        authorLabel.isBezeled = false
        authorLabel.drawsBackground = false
        authorLabel.isEditable = false
        authorLabel.isSelectable = false
        aboutWindow?.contentView?.addSubview(authorLabel)

        let githubButton = NSButton(frame: NSRect(x: 75, y: 10, width: 150, height: 30))
        githubButton.title = "View on GitHub"
        githubButton.bezelStyle = .rounded
        githubButton.target = self
        githubButton.action = #selector(openGitHubRepo) // The action that will open the GitHub repo
        aboutWindow?.contentView?.addSubview(githubButton)
    }

    @objc func showAboutDialog() {
        // Show the "About" window
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Bring app to the foreground
    }

    @objc func openGitHubRepo() {
        // Open the GitHub repository in the default web browser
        if let url = URL(string: "https://github.com/darkguy2008/LangSwitch") { // Replace with your repository URL
            NSWorkspace.shared.open(url)
        }
    }

    @objc func exitAction() {
        NSApplication.shared.terminate(nil)
    }

    // Method to toggle the display of the language switch popup

    @objc func toggleShouldShowPopup(_ sender: NSMenuItem) {
        shouldShowPopup.toggle() // Toggle the flag

        // Save the new setting
        UserDefaults.standard.set(shouldShowPopup, forKey: shouldShowPopupKey)

        // Update the checkmark state based on the current state
        sender.state = shouldShowPopup ? .on : .off
    }

    func switchKeyboardLanguage() {
        // Get the current keyboard input source
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeUnretainedValue() else {
            print("Failed to switch keyboard language.")
            return
        }

        // Get all enabled keyboard input sources
        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              !inputSources.isEmpty
        else {
            print("Failed to switch keyboard language.")
            return
        }

        // Find the index of the current input source
        guard let currentIndex = inputSources.firstIndex(where: { $0 == currentSource }) else {
            print("Failed to switch keyboard language.")
            return
        }

        // Calculate the index of the next input source
        var nextIndex = (currentIndex + 1) % inputSources.count

        let skipSources = ["Emoji & Symbols", "com.apple.PressAndHold", "Dictation", "EmojiFunctionRowIM_Extension"]

        // Skip system keyboards
        while let nextSource = inputSources[nextIndex] as TISInputSource? {
            let sourceName = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(nextSource, kTISPropertyLocalizedName)).takeUnretainedValue() as String
            if !skipSources.contains(sourceName) {
                break
            }
            nextIndex = (nextIndex + 1) % inputSources.count
        }

        // Retrieve the next input source
        let nextSource = inputSources[nextIndex]

        // Switch to the next input source
        TISSelectInputSource(nextSource)

        // Print the new input source's name
        let newSourceName = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(nextSource, kTISPropertyLocalizedName)).takeUnretainedValue() as String
        print("Switched to: \(newSourceName)")

        // Show a popup with the language name
        if shouldShowPopup {
            showPopup(languageName: newSourceName)
        }
    }

    func showPopup(languageName: String) {
        // Generate a new UUID to represent the current animation
        currentAnimationID = UUID()
        let thisAnimationID = currentAnimationID!

        // Stop ongoing animations and reset the alphaValue
        popupWindow?.contentView?.layer?.removeAllAnimations()
        popupWindow?.alphaValue = 1.0

        // Initialize the popup window if it's nil
        if popupWindow == nil {
            let windowSize = NSRect(x: 0, y: 0, width: 300, height: 125)
            popupWindow = NSWindow(contentRect: windowSize, styleMask: [.borderless], backing: .buffered, defer: false)
            popupWindow?.backgroundColor = NSColor.clear
            popupWindow?.isOpaque = false
            popupWindow?.level = NSWindow.Level.statusBar
            popupWindow?.hasShadow = false
            popupWindow?.level = .floating
        }

        // Create a visual effect view with less translucency
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .menu
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 15
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        // Create a gray box behind the text field
        let grayBox = NSBox()
        grayBox.boxType = .custom
        grayBox.fillColor = NSColor.quaternaryLabelColor
        grayBox.wantsLayer = true
        grayBox.layer?.cornerRadius = 10
        grayBox.borderWidth = 0 // No border for the gray box
        grayBox.translatesAutoresizingMaskIntoConstraints = false

        // Create a text field with the desired appearance
        let textField = NSTextField(labelWithString: languageName)
        textField.font = NSFont.systemFont(ofSize: 24)
        textField.textColor = NSColor.black
        textField.backgroundColor = NSColor.clear
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(grayBox)
        visualEffectView.addSubview(textField)

        // Constraints for grayBox
        NSLayoutConstraint.activate([
            grayBox.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 30),
            grayBox.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            grayBox.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
            grayBox.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -30),
        ])

        // Position the text field within the visual effect view
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
        ])

        // Set the visual effect view as the window's content view
        popupWindow?.contentView = visualEffectView
        popupWindow?.contentView?.layoutSubtreeIfNeeded()

        // Calculate the screen's center point and set the new window frame
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = popupWindow!.frame
            let newOriginX = screenRect.midX - windowRect.width / 2
            let newOriginY = screenRect.midY - windowRect.height / 2
            popupWindow?.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
        }

        // Show the window
        popupWindow?.makeKeyAndOrderFront(nil)

        // Cancel the previous dismissal task if it exists
        dismissalWorkItem?.cancel()

        // Create a new dismissal task
        dismissalWorkItem = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5 // Duration of the fade
                self?.popupWindow?.animator().alphaValue = 0.0
            }, completionHandler: {
                // Only order out if the animation ID hasn't changed
                if thisAnimationID == self?.currentAnimationID {
                    self?.popupWindow?.orderOut(nil)
                }
            })
        }

        // Dismiss the popup after 2 seconds
        if let dismissalWorkItem = dismissalWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: dismissalWorkItem)
        }
    }
}
