// Simulator - object performing execution and signalling of a simulation.
//
// Note: This is meant to be a generic class that will be extracted into a
// separate library later on. It should not contain any domain specifics.
//
// TODO: This is incubated module.
// TODO: Error handling
//

// TODO: Add the following function(s)
//
// run(before: (Simulation) -> None, after: (Simulation, Signal) -> None)
//
// TODO: Use exceptions for error signaling
//

public class IterativeSimulator<S:IterativeSimulation> {
    typealias Signal = S.Signal

    public let simulation: S

    public internal(set) var stepCount: Int = 0
    public internal(set) var isHalted: Bool = false

    /// Error from the last step
    public internal(set) var error: Error?


    public init(simulation: S) {
        self.simulation = simulation
    }
	/// Runs the simulation for `steps`.
    ///
    /// - Returns: Number of steps the simulation run. Note that it might be
    /// less that the number of steps requested due to potential halt.
    ///
    @discardableResult
	public func run(steps:Int, after afterStep: ((S, S.Signal) -> Void)?=nil) -> Int {
        precondition(steps > 0, "Number of steps to run must be greater than 0")
        precondition(!isHalted, "Can't run halted simulator")

        var stepsRun: Int = 0

		for _ in 1...steps {
            let result: StepResult<Signal>
            
            result = simulation.step()
            stepCount += 1
			stepsRun += 1

            if case .error(let resultError) = result {
                error = resultError
                // handle error
            }
            else {
                afterStep?(simulation, result.signal!)
            }

            if case .halt(_) = result {
                isHalted = true
                break
            }
		}

        return stepsRun
	}
}
