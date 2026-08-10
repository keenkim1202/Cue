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
        guard let url = CueURL.openable(action.urlString) else {
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

    /// 로그에 남는 값은 **표시가 아니라 데이터**다. 로케일에 따라 숫자 체계가 바뀌면
    /// 기록이 흔들리므로 고정 로케일을 쓰고, 포맷터도 매번 만들지 않는다.
    private static let markFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func mark() -> Outcome {
        Outcome(detail: markFormatter.string(from: Date()), succeeded: true)
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
