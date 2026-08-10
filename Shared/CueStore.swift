import Foundation

/// 앱 · 위젯 확장 · 컨트롤이 함께 읽는 상태 저장소.
///
/// `ControlWidget`의 값 제공자는 위젯 확장 프로세스에서 돌고,
/// 인텐트는 앱 프로세스에서 돈다. 둘이 같은 상태를 봐야 하므로 App Group을 쓴다.
@MainActor
enum CueStore {
    static let appGroupID = "group.com.keen.cue"

    /// `var`인 것은 테스트가 앱의 실제 App Group을 건드리지 않도록 별도 suite로
    /// 갈아끼우게 하려는 것뿐이다. 앱에서 바꾸지 않는다.
    static var defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    private enum Key {
        static let config = "cue.config"
        static let state = "cue.state"
        static let log = "cue.log"
        static let stopwatch = "cue.stopwatch"
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: Config

    /// 저장된 구성이 없으면 시드를 돌려준다. **쓰지는 않는다** —
    /// 게터가 공유 저장소를 건드리면 앱과 위젯 확장이 동시에 첫 실행될 때 서로 다른 값을 쓸 수 있다.
    /// 영속화는 `bootstrapIfNeeded()`가 앱에서 한 번만 한다.
    static var config: CueConfig {
        get {
            guard let data = defaults.data(forKey: Key.config),
                  let decoded = try? decoder.decode(CueConfig.self, from: data),
                  !decoded.sets.isEmpty
            else {
                return .seed
            }
            return decoded
        }
        set {
            guard !newValue.sets.isEmpty else { return }
            defaults.set(try? encoder.encode(newValue), forKey: Key.config)
        }
    }

    static var activeSet: CueSet { config.activeSet }

    /// 첫 실행에 기본 구성을 심는다. 앱 시작 시 한 번만 호출한다.
    static func bootstrapIfNeeded() {
        guard defaults.data(forKey: Key.config) == nil else { return }
        config = .seed
    }

    /// 다음 세트로 순환. 컨트롤 센터 버튼에서 호출한다.
    @discardableResult
    static func advanceSet() -> CueSet {
        var current = config
        guard current.sets.count > 1 else { return current.activeSet }
        let index = current.sets.firstIndex { $0.id == current.activeSetID } ?? 0
        let next = current.sets[(index + 1) % current.sets.count]
        current.activeSetID = next.id
        config = current
        return next
    }

    // MARK: Runtime state

    static var state: CueState {
        get {
            guard let data = defaults.data(forKey: Key.state),
                  let decoded = try? decoder.decode(CueState.self, from: data)
            else { return .empty }
            return decoded
        }
        set { defaults.set(try? encoder.encode(newValue), forKey: Key.state) }
    }

    /// 무장을 풀고 **대기 중인 자동 커밋을 무효화한다.**
    ///
    /// `generation`을 올리는 것이 핵심이다. 예전에는 올리지 않아서, Live Activity의 실행
    /// 버튼으로 먼저 확정해도 대기 중이던 `arm()`이 generation 검사를 통과해 같은 액션을
    /// 두 번 실행했다. `commit()`은 `isArmed`를 보지 않으므로 이 토큰이 유일한 방어선이다.
    static func disarm() {
        var current = state
        current.isArmed = false
        current.lastInputWasItemTap = false
        current.generation += 1
        state = current
    }

    /// 런타임 상태를 비운다.
    ///
    /// `CueState.empty`를 그대로 대입하면 `generation`이 0으로 **되돌아가** 나중 누름의
    /// generation과 충돌한다. 무효화 토큰은 단조 증가여야 하므로 값을 이어 붙인다.
    static func clearRuntimeState() {
        var fresh = CueState.empty
        fresh.generation = state.generation + 1
        state = fresh
    }

    // MARK: Stopwatch

    static var stopwatch: CueStopwatch {
        get {
            guard let data = defaults.data(forKey: Key.stopwatch),
                  let decoded = try? decoder.decode(CueStopwatch.self, from: data)
            else { return .idle }
            return decoded
        }
        set { defaults.set(try? encoder.encode(newValue), forKey: Key.stopwatch) }
    }

    // MARK: Log

    static let logLimit = 30

    static var log: [CueLogEntry] {
        get {
            guard let data = defaults.data(forKey: Key.log),
                  let decoded = try? decoder.decode([CueLogEntry].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let trimmed = Array(newValue.prefix(logLimit))
            defaults.set(try? encoder.encode(trimmed), forKey: Key.log)
        }
    }

    static func appendLog(_ entry: CueLogEntry) {
        log = [entry] + log
    }

    static func clearLog() {
        log = []
    }
}
