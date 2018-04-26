import Model

// TODO: Make Simulator an abstract class/lib for iterative simulations
// TODO: make this a protocol, since we can't expose our internal
// implementation of object

public protocol SimulatorDelegate {
	func willRun(simulator: Simulator)
	func didRun(simulator: Simulator)
	func willStep(simulator: Simulator)
	func didStep(simulator: Simulator)

	func handleTrap(simulator: Simulator, traps: Set<Symbol>)
	func handleHalt(simulator: Simulator)
}

extension SimulatorDelegate {
	func willRun(simulator: Simulator) { /* Empty */ }
	func didRun(simulator: Simulator) { /* Empty */ }
	func willStep(simulator: Simulator) { /* Empty */ }
	func didStep(simulator: Simulator) { /* Empty */ }

	func handleTrap(simulator: Simulator, traps: Set<Symbol>) { /* Empty */ }
	func handleHalt(simulator: Simulator) { /* Empty */ }
}

public class Simulator {
    let model: Model
    let container: Container
    var stepCount: Int = 0
    var delegate: SimulatorDelegate? = nil

    var isHalted: Bool = false

    public init(model: Model, container: Container) {
        self.model = model
        self.container = container
    }

	/// Runs the simulation for `steps`.
    ///
    /// - Returns: Number of steps the simulation run. Note that it might be
    /// less that the number of steps requested due to potential halt.
    ///
    @discardableResult
	public func run(steps:Int) -> Int {
        precondition(steps > 0, "Number of steps to run must be greater than 0")
        precondition(!isHalted, "Can't run halted simulator")

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
				delegate?.handleHalt(simulator:self)
				break
			}

			stepsRun += 1
		}

		// collector?.collectingDidEnd(steps: stepsRun)
        return stepsRun
	}

    public func step() {
		delegate?.willStep(simulator: self)
        // FIXME: Make this Simulation.step()
        stepBody()
        stepCount += 1
		delegate?.didStep(simulator: self)
    }

    public func stepBody() {
        // var notifications = Set<Symbol>()
        // var traps = Set<Symbol>()
        // var halts: Bool = false

        // Unary actuators
        // ---------------
        // FIXME: Those inner conditions are not 100% right - what if an object
        // has been changed in a way that it has to be considered?
        for actuator in model.unaryActuators.values {

            for oid in container.select(actuator.selector) {
                if !container.matches(oid, selector: actuator.selector) {
                    // The object has been modified through some of the rules,
                    // we skip it
                    continue
                }
                container.update(oid, with: actuator.transitions)
            }
        }

        // Binary actuators
        // ----------------

        for actuator in model.binaryActuators.values {
            let leftOnes = container.select(actuator.leftSelector)
            let rightOnes = container.select(actuator.rightSelector)

            for left in leftOnes {
                for right in rightOnes {
                    if !container.matches(left, selector: actuator.leftSelector) {
                        // The left has been modified - the rest of the right
                        // side can't be processed
                        break
                    }
                    if !container.matches(right, selector: actuator.rightSelector) {
                        // The right has been modified, we skip it
                        continue
                    }
                    container.update(left,
                                     with: actuator.leftTransitions,
                                     other: right)
                    container.update(right,
                                     with: actuator.rightTransitions,
                                     other: left)
                }
            }
        }
    }

	public func debugDump() {
		debugPrint(">>> SIMULATOR DUMP START\n")
		debugPrint("--- STEP \(self.stepCount)")
		self.container.objects.keys.forEach {
			ref in
            let obj = container[ref]
			debugPrint("    \(obj)")
		}
		debugPrint("<<< END OF DUMP\n")
	}
}

