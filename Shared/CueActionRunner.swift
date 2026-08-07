import AVFoundation
import Foundation

/// 선택된 액션을 실제로 수행한다.
enum CueActionRunner {
    struct Outcome {
        var detail: String
        var succeeded: Bool
        /// 실행만으로는 끝나지 않고 "열기" 버튼을 띄워야 하는 액션인지.
        /// 백그라운드 인텐트는 앱을 전면으로 못 올리므로 여는 것은 사용자 탭에 맡긴다.
        var offersAppLaunch: Bool = false
    }

    static func run(_ action: CueAction) -> Outcome {
        switch action.kind {
        case .torch: return toggleTorch()
        case .mark: return mark()
        case .stopwatch: return toggleStopwatch()
        case .openApp: return Outcome(detail: "열기 버튼 표시", succeeded: true, offersAppLaunch: true)
        }
    }

    // MARK: 손전등

    private static func toggleTorch() -> Outcome {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            return Outcome(detail: "토치를 쓸 수 없는 기기 (시뮬레이터 포함)", succeeded: false)
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let turningOn = !device.isTorchActive
            device.torchMode = turningOn ? .on : .off
            return Outcome(detail: turningOn ? "켜짐" : "꺼짐", succeeded: true)
        } catch {
            return Outcome(detail: "토치 설정 실패: \(error.localizedDescription)", succeeded: false)
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
            return Outcome(detail: "정지 · \(format(elapsed))", succeeded: true)
        } else {
            watch.startedAt = Date()
            CueStore.stopwatch = watch
            return Outcome(detail: "시작", succeeded: true)
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
