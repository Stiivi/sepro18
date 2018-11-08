public enum StepResult<Signal> {
    case error(Error)
    case ok(signal: Signal)
    case halt(signal: Signal)

    public var signal: Signal? {
        switch self {
        case .error: return nil
        case .ok(let signal): return signal
        case .halt(let signal): return signal
        }
    }

    public var isError: Bool {
        switch self {
        case .error: return true
        default: return false
        }
    }
}

public protocol IterativeSimulation {
    associatedtype Signal
    func step() -> StepResult<Signal>
}
