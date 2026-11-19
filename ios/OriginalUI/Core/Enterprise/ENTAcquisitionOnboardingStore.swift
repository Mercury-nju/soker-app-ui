import Foundation

@MainActor
final class ENTAcquisitionOnboardingStore {
    static let shared = ENTAcquisitionOnboardingStore()

    // Prototype progress lasts only for this app process, never a real account session.
    private(set) var canEnterHome = false
    var shouldPresent: Bool { !canEnterHome }

    func completePrototype() {
        canEnterHome = true
    }

    private init() {}
}
