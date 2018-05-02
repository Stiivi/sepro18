public enum StepResult<Signal> {
    case error(Error)
    case ok(signal: Signal?)
    case halt(signal: Signal?)

    public var signal: Signal? {
        switch self {
        case .error(_): return nil
        case .ok(let signal): return signal
        case .halt(let signal): return signal
        }
    }
}

public protocol IterativeSimulation {
    associatedtype Signal
    func step() -> StepResult<Signal>
}

