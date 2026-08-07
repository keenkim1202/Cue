import AVFoundation
import Foundation

/// 선택된 액션을 실제로 수행한다.
@MainActor
enum CueActionRunner {
    struct Outcome {
        var detail: String
        var succeeded: Bool
        /// 실행만으로는 끝나지 않고 "열기" 버튼을 띄워야 하는 액션이면 그 대상.
        /// 백그라운드 인텐트는 앱도 링크도 못 여므로 여는 것은 사용자 탭에 맡긴다.
        var openTarget: CueOpenTarget? = nil
    }

    static func run(_ action: CueAction) -> Outcome {
        switch action.kind {
        case .torch: return toggleTorch()
        case .mark: return mark()
        case .stopwatch: return toggleStopwatch()
        case .openApp: return Outcome(detail: String(localized: "열기 버튼 표시"), succeeded: true, openTarget: .app)
        case .openURL: return openURL(action)
        }
    }

    // MARK: 링크

    private static func openURL(_ action: CueAction) -> Outcome {
        guard let url = URL(string: action.urlString), url.scheme?.hasPrefix("http") == true else {
            return Outcome(detail: String(localized: "열 수 없는 주소: \(action.urlString)"), succeeded: false)
        }
        return Outcome(detail: url.host() ?? url.absoluteString, succeeded: true, openTarget: .url(url.absoluteString))
    }

    // MARK: 손전등

    private static func toggleTorch() -> Outcome {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            return Outcome(detail: String(localized: "토치를 쓸 수 없는 기기 (시뮬레이터 포함)"), succeeded: false)
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let turningOn = !device.isTorchActive
            device.torchMode = turningOn ? .on : .off
            return Outcome(detail: turningOn ? String(localized: "켜짐") : String(localized: "꺼짐"), succeeded: true)
        } catch {
            return Outcome(detail: String(localized: "토치 설정 실패: \(error.localizedDescription)"), succeeded: false)
        }
    }

    // MARK: 순간 기록

    private static func mark() -> Outcome {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return Outcome(detail: formatter.string(from: Date()), succeeded: true)
    }

    // MARK: 스톱워치

    private static func toggleStopwatch() -> Outcome {
        var watch = CueStore.stopwatch
        if let startedAt = watch.startedAt {
            let elapsed = Date().timeIntervalSince(startedAt)
            watch.startedAt = nil
            CueStore.stopwatch = watch
            return Outcome(detail: String(localized: "정지 · \(format(elapsed))"), succeeded: true)
        } else {
            watch.startedAt = Date()
            CueStore.stopwatch = watch
            return Outcome(detail: String(localized: "시작"), succeeded: true)
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
