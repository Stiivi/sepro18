// Simulator - object performing execution and signalling of a simulation.
//
// Note: This is meant to be a generic class that will be extracted into a
// separate library later on. It should not contain any domain specifics.
//
// TODO: This is incubated module.
//
import Model

// TODO: Make Simulator an abstract class/lib for iterative simulations
// TODO: make this a protocol, since we can't expose our internal
// implementation of object

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

public protocol SimulatorDelegate {
    associatedtype S: IterativeSimulation

	func willRun(simulator: Simulator<S, Self>)
	func didRun(simulator: Simulator<S, Self>)
	func willStep(simulator: Simulator<S, Self>)
	func didStep(simulator: Simulator<S, Self>, signal: S.Signal?)

	func didHalt<S>(simulator: Simulator<S, Self>)
}


public class Simulator<S,
                       D: SimulatorDelegate> where D.S == S {
    typealias Signal = S.Signal

    public let simulation: S

    public internal(set) var stepCount: Int = 0
    public internal(set) var isHalted: Bool = false

    public var delegate: D? = nil

    public init(simulation: S, delegate: D?=nil) {
        self.simulation = simulation
        self.delegate = delegate
    }
	/// Runs the simulation for `steps`.
    ///
    /// - Returns: Number of steps the simulation run. Note that it might be
    /// less that the number of steps requested due to potential halt.
    ///
    @discardableResult
	public func run(steps:Int) -> Int {
        precondition(steps > 0, "Number of steps to run must be greater than 0")

        var stepsRun: Int = 0

		// if collector != nil {
		// 	collector!.collectingWillStart(measures: model.measures, steps: steps)
		// 	// TODO: this should be called only on first run
		// 	probe()
		// }
		
		delegate?.willRun(simulator:self)

		for _ in 1...steps {
			step()

			if isHalted {
				delegate?.didHalt(simulator:self)
				break
			}

			stepsRun += 1
		}

		// collector?.collectingDidEnd(steps: stepsRun)
        return stepsRun
	}

    public func step() {
        precondition(!isHalted, "Can't run halted simulator")

        let result: StepResult<Signal>

		delegate?.willStep(simulator: self)

        result =  simulation.step()
        stepCount += 1

        if case .halt(_) = result {
            isHalted = true
        }
		
        delegate?.didStep(simulator: self, signal: result.signal)
    }

}

