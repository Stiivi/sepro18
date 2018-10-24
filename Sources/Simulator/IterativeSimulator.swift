// Simulator - object performing execution and signalling of a simulation.
//
// Note: This is meant to be a generic class that will be extracted into a
// separate library later on. It should not contain any domain specifics.
//
// TODO: This is incubated module.
// TODO: Error handling
//

public protocol SimulatorDelegate: AnyObject {
    associatedtype Sim: IterativeSimulation

	func willRun(simulator: IterativeSimulator<Sim, Self>)
	func didRun(simulator: IterativeSimulator<Sim, Self>)
	func willStep(simulator: IterativeSimulator<Sim, Self>)
	func didStep(simulator: IterativeSimulator<Sim, Self>, signal: Sim.Signal?)

	func didHalt<Sim>(simulator: IterativeSimulator<Sim, Self>)
}


public class IterativeSimulator<S,
                       D: SimulatorDelegate> where D.Sim == S {
    typealias Signal = S.Signal

    public let simulation: S

    public internal(set) var stepCount: Int = 0
    public internal(set) var isHalted: Bool = false

    public weak var delegate: D?

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

    /// Perform one iteration of the simulation.
    ///
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
