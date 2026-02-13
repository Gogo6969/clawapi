#!/bin/bash
# take-screenshots.sh — Launch ClawAPI with mock data and capture screenshots of every page
# Uses screencapture -l to capture specific windows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/screenshots"
BUILD_DIR="$PROJECT_DIR/.build/arm64-apple-macosx/debug"
APP_DIR="$BUILD_DIR/ClawAPI.app"

# Ensure app is built
echo "Building app..."
cd "$PROJECT_DIR"
bash build-app.sh

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Populating mock data for screenshots..."

# Create mock data directory
DATA_DIR="$HOME/Library/Application Support/ClawAPI"
mkdir -p "$DATA_DIR"

# Back up existing data
BACKUP_DIR="$DATA_DIR/.backup_$$"
mkdir -p "$BACKUP_DIR"
for f in policies.json audit.json pending.json; do
    [ -f "$DATA_DIR/$f" ] && cp "$DATA_DIR/$f" "$BACKUP_DIR/$f" 2>/dev/null || true
done

# Write rich mock policies (6 providers with various states)
cat > "$DATA_DIR/policies.json" << 'POLICYJSON'
[
  {
    "id": "11111111-1111-1111-1111-111111111111",
    "serviceName": "OpenAI",
    "scope": "openai",
    "allowedDomains": ["api.openai.com"],
    "approvalMode": "auto",
    "hasSecret": true,
    "isEnabled": true,
    "priority": 1,
    "credentialType": "bearer",
    "preferredFor": ["coding", "chat", "general"],
    "createdAt": 760000000
  },
  {
    "id": "22222222-2222-2222-2222-222222222222",
    "serviceName": "Anthropic",
    "scope": "anthropic",
    "allowedDomains": ["api.anthropic.com"],
    "approvalMode": "auto",
    "hasSecret": true,
    "isEnabled": true,
    "priority": 2,
    "credentialType": "header",
    "customHeaderName": "x-api-key",
    "preferredFor": ["coding", "analysis", "chat"],
    "createdAt": 759000000
  },
  {
    "id": "33333333-3333-3333-3333-333333333333",
    "serviceName": "Google AI",
    "scope": "google-ai",
    "allowedDomains": ["generativelanguage.googleapis.com"],
    "approvalMode": "auto",
    "hasSecret": true,
    "isEnabled": true,
    "priority": 3,
    "credentialType": "header",
    "customHeaderName": "x-goog-api-key",
    "preferredFor": ["research", "chat", "general"],
    "createdAt": 758000000
  },
  {
    "id": "44444444-4444-4444-4444-444444444444",
    "serviceName": "GitHub",
    "scope": "github",
    "allowedDomains": ["api.github.com", "github.com"],
    "approvalMode": "manual",
    "hasSecret": true,
    "isEnabled": true,
    "priority": 4,
    "credentialType": "bearer",
    "preferredFor": ["coding"],
    "createdAt": 757000000
  },
  {
    "id": "55555555-5555-5555-5555-555555555555",
    "serviceName": "Perplexity",
    "scope": "perplexity",
    "allowedDomains": ["api.perplexity.ai"],
    "approvalMode": "auto",
    "hasSecret": true,
    "isEnabled": true,
    "priority": 5,
    "credentialType": "bearer",
    "preferredFor": ["research"],
    "createdAt": 756000000
  },
  {
    "id": "66666666-6666-6666-6666-666666666666",
    "serviceName": "Groq",
    "scope": "groq",
    "allowedDomains": ["api.groq.com"],
    "approvalMode": "auto",
    "hasSecret": true,
    "isEnabled": false,
    "priority": 6,
    "credentialType": "bearer",
    "preferredFor": ["coding", "chat"],
    "createdAt": 755000000
  }
]
POLICYJSON

# Write mock audit entries (mix of results — 8 entries for richer display)
cat > "$DATA_DIR/audit.json" << 'AUDITJSON'
[
  {
    "id": "A1111111-1111-1111-1111-111111111111",
    "timestamp": 760099000,
    "scope": "openai",
    "requestingHost": "api.openai.com",
    "reason": "Generate code completion",
    "result": "approved"
  },
  {
    "id": "A2222222-2222-2222-2222-222222222222",
    "timestamp": 760097000,
    "scope": "anthropic",
    "requestingHost": "api.anthropic.com",
    "reason": "Analyze codebase architecture",
    "result": "approved"
  },
  {
    "id": "A3333333-3333-3333-3333-333333333333",
    "timestamp": 760095000,
    "scope": "google-ai",
    "requestingHost": "generativelanguage.googleapis.com",
    "reason": "Research paper summarization",
    "result": "approved"
  },
  {
    "id": "A4444444-4444-4444-4444-444444444444",
    "timestamp": 760090000,
    "scope": "github",
    "requestingHost": "api.github.com",
    "reason": "Fetch repository list",
    "result": "approved"
  },
  {
    "id": "A5555555-5555-5555-5555-555555555555",
    "timestamp": 760085000,
    "scope": "perplexity",
    "requestingHost": "api.perplexity.ai",
    "reason": "Web search — latest Swift concurrency docs",
    "result": "approved"
  },
  {
    "id": "A6666666-6666-6666-6666-666666666666",
    "timestamp": 760080000,
    "scope": "anthropic",
    "requestingHost": "unknown-host.example.com",
    "reason": "Message completion",
    "result": "denied",
    "detail": "Host not in allowed domains"
  },
  {
    "id": "A7777777-7777-7777-7777-777777777777",
    "timestamp": 760075000,
    "scope": "openai",
    "requestingHost": "api.openai.com",
    "reason": "Chat completion — explain OAuth flow",
    "result": "approved"
  },
  {
    "id": "A8888888-8888-8888-8888-888888888888",
    "timestamp": 760070000,
    "scope": "groq",
    "requestingHost": "api.groq.com",
    "reason": "Fast inference request",
    "result": "error",
    "detail": "Provider is disabled"
  }
]
AUDITJSON

# Write mock pending requests
cat > "$DATA_DIR/pending.json" << 'PENDINGJSON'
[
  {
    "id": "P1111111-1111-1111-1111-111111111111",
    "scope": "github",
    "requestingHost": "api.github.com",
    "reason": "Create release tag v2.1.0",
    "requestedAt": 760098000
  }
]
PENDINGJSON

echo "Mock data written."

# Reset welcome state so we can screenshot the welcome pages first
defaults write com.clawapi.app hasSeenWelcome -bool false
defaults write com.clawapi.app skippedGetStarted -bool false

echo ""
echo "=== SCREENSHOT INSTRUCTIONS ==="
echo ""
echo "The app will now launch. Please follow these steps to take screenshots:"
echo ""
echo "For EACH page, press Cmd+Shift+4, then press Space, then click the ClawAPI window."
echo "macOS will save the screenshot to your Desktop."
echo ""
echo "Pages to capture:"
echo "  1. Welcome Page 1 (Start) — opens automatically"
echo "  2. Welcome Page 2 (How It Works) — click 'How It Works' button"
echo "  3. Click 'Get Started' to proceed"
echo "  4. Skip Get Started — click 'Skip for now'"
echo "  5. Providers tab — opens automatically (with 5 providers)"
echo "  6. Activity tab — click the Activity tab"
echo "  7. Logs tab — click the Logs tab"
echo "  8. Quick Guide — click ? in toolbar"
echo "  9. FAQ — click book icon in toolbar"
echo " 10. Add Provider — click + in toolbar"
echo ""
echo "Or, this script will attempt automatic window capture..."
echo ""

# Launch the app
open "$APP_DIR"
sleep 3

# Try to find the window ID
echo "Attempting automatic screenshots..."

# Function to capture by window title
capture_window() {
    local name="$1"
    local output="$2"

    # Get window ID for ClawAPI
    local wid
    wid=$(osascript -e 'tell application "System Events" to tell process "ClawAPIApp" to get id of first window' 2>/dev/null || echo "")

    if [ -n "$wid" ]; then
        screencapture -l "$wid" -o "$output"
        echo "  Captured: $output"
    else
        # Fallback: capture using window name
        screencapture -l "$(osascript -e '
            tell application "System Events"
                tell process "ClawAPIApp"
                    set frontWindow to first window
                    return id of frontWindow
                end tell
            end tell
        ' 2>/dev/null || echo "")" -o "$output" 2>/dev/null || {
            echo "  Could not auto-capture $name. Using screencapture -w instead..."
            screencapture -w -o "$output"
        }
        echo "  Captured: $output"
    fi
}

# Get the CGWindowID for ClawAPIApp
get_window_id() {
    osascript -e '
        tell application "System Events"
            tell process "ClawAPIApp"
                set frontmost to true
                delay 0.3
            end tell
        end tell
    ' 2>/dev/null || true

    # Get window list and find ClawAPI
    local wid
    wid=$(python3 -c "
import subprocess, json
result = subprocess.run(['osascript', '-e', '''
    tell application \"System Events\"
        tell process \"ClawAPIApp\"
            return id of window 1
        end tell
    end tell
'''], capture_output=True, text=True)
print(result.stdout.strip())
" 2>/dev/null || echo "")
    echo "$wid"
}

# Helper to click UI elements via AppleScript
click_element() {
    osascript -e "$1" 2>/dev/null || true
    sleep 1.5
}

capture_screenshot() {
    local filename="$1"
    local filepath="$OUTPUT_DIR/$filename.png"

    # Bring to front
    osascript -e 'tell application "ClawAPI" to activate' 2>/dev/null || \
    osascript -e 'tell application "ClawAPIApp" to activate' 2>/dev/null || true
    sleep 0.5

    # Use screencapture with window mode - capture frontmost window
    # The -l flag needs a CGWindowID. Let's use the simpler approach:
    screencapture -o -w -x "$filepath" 2>/dev/null && {
        echo "  ✓ Saved: $filepath"
        return 0
    }

    echo "  ✗ Failed: $filename"
    return 1
}

echo ""
echo "The app should now be open on the Welcome screen."
echo "Since automated window capture requires accessibility permissions,"
echo "I'll use a programmatic approach instead."
echo ""

# --- Programmatic screenshot approach ---
# Use a small Swift script that uses CGWindowListCreateImage

cat > /tmp/capture_clawapi.swift << 'CAPTURESWIFT'
import Cocoa
import ScreenCaptureKit

@available(macOS 14.0, *)
func captureWindow(processName: String, outputPath: String) async -> Bool {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let matchingWindows = content.windows.filter { window in
            let app = window.owningApplication
            let name = app?.applicationName ?? ""
            let bundleID = app?.bundleIdentifier ?? ""
            return name.contains("ClawAPI") || bundleID.contains("clawapi")
        }
        .filter { $0.frame.width > 100 }
        .sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }

        guard let window = matchingWindows.first else {
            print("No ClawAPI window found. Available:")
            for w in content.windows.prefix(15) {
                let name = w.owningApplication?.applicationName ?? "?"
                print("  \(name) — \(Int(w.frame.width))x\(Int(w.frame.height))")
            }
            return false
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        config.scalesToFit = false
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return false }
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Captured \(Int(window.frame.width))x\(Int(window.frame.height)) → \(outputPath)")
        return true
    } catch {
        print("Capture error: \(error)")
        return false
    }
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/screenshot.png"
if #available(macOS 14.0, *) {
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    Task {
        success = await captureWindow(processName: "ClawAPI", outputPath: outputPath)
        semaphore.signal()
    }
    semaphore.wait()
    exit(success ? 0 : 1)
} else {
    print("Requires macOS 14.0+"); exit(1)
}
CAPTURESWIFT

echo "Compiling screenshot helper..."
swiftc -o /tmp/capture_clawapi /tmp/capture_clawapi.swift -framework Cocoa -framework ScreenCaptureKit 2>&1

take_shot() {
    local name="$1"
    local file="$OUTPUT_DIR/$name.png"
    sleep 1
    /tmp/capture_clawapi "$file" 2>&1 || echo "  (capture may need screen recording permission)"
}

echo ""
echo "=== Taking Screenshots ==="
echo ""

# 1. Welcome Page 1 (should be showing now)
echo "1/10: Welcome — Start"
take_shot "01-welcome-start"

# 2. Click "How It Works" button
echo "2/10: Welcome — How It Works"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            set frontmost to true
            delay 0.5
            click button "How It Works" of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "02-how-it-works"

# 3. Click "Get Started"
echo "3/10: Get Started"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            click button "Get Started" of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "03-get-started"

# 4. Click "Skip for now" to get to main app
echo "4/10: Navigating to main app..."
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            click button "Skip for now" of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 2

# 5. Providers tab (default)
echo "5/10: Providers tab"
take_shot "04-providers"

# 6. Activity tab
echo "6/10: Activity tab"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            -- Click the Activity tab
            click radio button "Activity" of tab group 1 of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "05-activity"

# 7. Logs tab
echo "7/10: Logs tab"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            click radio button "Logs" of tab group 1 of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "06-logs"

# 8. Quick Guide popover — click ? button
echo "8/10: Quick Guide"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            -- Click Help button in toolbar
            click button "Help" of toolbar 1 of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "07-quick-guide"

# Close popover by clicking elsewhere
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            key code 53
        end tell
    end tell
' 2>/dev/null || true
sleep 0.5

# 9. FAQ sheet
echo "9/10: FAQ"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            click button "FAQ" of toolbar 1 of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "08-faq"

# Close FAQ
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            key code 53
        end tell
    end tell
' 2>/dev/null || true
sleep 0.5

# 10. Add Provider sheet
echo "10/10: Add Provider"
osascript -e '
    tell application "System Events"
        tell process "ClawAPIApp"
            click button "Add Provider" of toolbar 1 of first window
        end tell
    end tell
' 2>/dev/null || true
sleep 1.5
take_shot "09-add-provider"

# Close the app
echo ""
echo "Closing app..."
osascript -e 'tell application "ClawAPIApp" to quit' 2>/dev/null || \
pkill -f ClawAPIApp 2>/dev/null || true

# Restore original data
echo "Restoring original data..."
for f in policies.json audit.json pending.json; do
    if [ -f "$BACKUP_DIR/$f" ]; then
        cp "$BACKUP_DIR/$f" "$DATA_DIR/$f"
    else
        rm -f "$DATA_DIR/$f"
    fi
done
rm -rf "$BACKUP_DIR"

# Reset welcome back to seen
defaults write com.clawapi.app hasSeenWelcome -bool true
defaults write com.clawapi.app skippedGetStarted -bool true

echo ""
echo "=== Done ==="
echo "Screenshots saved to: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/" 2>/dev/null || echo "(no screenshots captured — may need screen recording permission)"
echo ""
echo "If screenshots are blank or missing, grant Screen Recording permission to Terminal in:"
echo "  System Settings → Privacy & Security → Screen Recording → Terminal"
