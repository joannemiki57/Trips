import Foundation
import Photos

/// C4 LOCKED — Request Full Library (`.readWrite`). On denial, caller shows guidance + Settings deep-link.
/// `.limited` is a valid steady state (사용자가 일부만 선택) — UI 흐름은 계속 진행, B1 인덱싱도 한정된 자산으로 돌림.
@MainActor
@Observable
final class PhotoLibraryAuthorizer {

    enum State: Equatable, Sendable {
        case notDetermined
        case authorized
        case limited
        case denied
        case restricted
    }

    private(set) var state: State

    init() {
        self.state = State(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// 시스템 권한 시트를 띄움. 이미 결정된 상태면 캐시된 상태만 반영.
    func requestAccessIfNeeded() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else {
            state = State(current)
            return
        }
        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        state = State(granted)
    }

    /// 외부에서 강제로 동기화 (예: Settings 다녀온 직후).
    func refresh() {
        state = State(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    var canRead: Bool {
        switch state {
        case .authorized, .limited: return true
        case .notDetermined, .denied, .restricted: return false
        }
    }
}

private extension PhotoLibraryAuthorizer.State {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: self = .authorized
        case .limited: self = .limited
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .notDetermined
        }
    }
}
