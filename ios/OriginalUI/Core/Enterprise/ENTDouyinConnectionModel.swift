import Combine
import Foundation

struct ENTDouyinAccount: Equatable {
    let nickname: String
    let handle: String
    let avatarSymbol: String
}

/// Local presentation state for the approved UI prototype.
/// Development must replace the fixture login result and account verification together.
@MainActor
final class ENTDouyinConnectionModel: ObservableObject {
    enum Failure: Equatable {
        case cancelled
        case loginNotCompleted
        case network
        case identityUnavailable
    }

    enum Phase: Equatable {
        case idle
        case waitingForLogin
        case checking
        case confirming(ENTDouyinAccount)
        case failed(Failure)
        case expired
    }

    @Published private(set) var phase: Phase = .idle
    private var attemptID = UUID()
    private var platformLoginAttempt: UUID?
    private var verifiedAttempt: UUID?
    private var candidateAccount: ENTDouyinAccount?

    func beginLogin() {
        attemptID = UUID()
        platformLoginAttempt = nil
        verifiedAttempt = nil
        candidateAccount = nil
        phase = .waitingForLogin
    }

    func cancelLogin() {
        platformLoginAttempt = nil
        verifiedAttempt = nil
        candidateAccount = nil
        phase = .failed(.cancelled)
    }

    func completePlatformLogin() {
        guard case .waitingForLogin = phase else { return }
        platformLoginAttempt = attemptID
        // Fictional presentation fixture; never an authenticated platform identity.
        candidateAccount = ENTDouyinAccount(
            nickname: "Soker",
            handle: "soker_business",
            avatarSymbol: "person.crop.circle.fill"
        )
    }

    func checkConnection() {
        verifiedAttempt = nil
        guard platformLoginAttempt == attemptID else {
            phase = .failed(.loginNotCompleted)
            return
        }
        phase = .checking
        guard let account = candidateAccount else {
            phase = .failed(.identityUnavailable)
            return
        }
        verifiedAttempt = attemptID
        phase = .confirming(account)
    }

    func retry() {
        if platformLoginAttempt == attemptID {
            checkConnection()
        } else {
            phase = .idle
        }
    }

    func expireConnection() {
        platformLoginAttempt = nil
        verifiedAttempt = nil
        candidateAccount = nil
        phase = .expired
    }

    func confirm() -> Bool {
        guard case let .confirming(account) = phase,
              verifiedAttempt == attemptID,
              platformLoginAttempt == attemptID,
              account == candidateAccount else { return false }
        return true
    }
}
