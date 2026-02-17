import Foundation

/// Single source of truth for the ClawAPI version.
/// Update these values for every release. `build-app.sh` extracts them to stamp Info.plist.
public enum AppVersion {
    /// Semantic version string (major.minor.patch).
    public static let current = "1.5.2"

    /// Build number, incremented with each build.
    public static let build = "1"

    /// URL of the remote update manifest JSON (hosted on GitHub).
    /// Change this once the GitHub repo is created.
    public static let updateManifestURL = URL(string: "https://raw.githubusercontent.com/Gogo6969/clawapi/main/update.json")!
}
