import Foundation

// Foundation-only mirror of the app-target `DetectedActivity` enum.
// The app copy (in ShuttlX/Models/ActivitySegment.swift) is the source of truth
// for UI concerns (color/icon/displayName) — but tests only need the raw cases,
// so we keep this shim free of SwiftUI to make the Shared/ SPM target compile.
//
// Future work: once the app targets import ShuttlXShared, the SwiftUI extensions
// can move to a separate file in the app target and this becomes the single
// source of truth.
public enum DetectedActivity: String, Codable, CaseIterable, Sendable {
    case running
    case walking
    case stationary
    case unknown
}
