import Foundation

/// How a training session was produced — a standard scripted/free workout or
/// the gym-recovery mode that auto-captures HRR between sets.
public enum SessionMode: String, Codable, Sendable {
    case standard = "standard"
    case gymRecovery = "gymRecovery"
}
