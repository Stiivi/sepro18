import Simulator
import Model

// TODO: Unused for now, we just need a signal type
public struct SeproSignal {
    let traps: Set<Symbol>
    let messages: Set<Symbol>
}

/// Simulation of the Sepro model
///
public class SeproSimulation: IterativeSimulation {
    public typealias Signal = SeproSignal

    public let model: Model
    // FIXME: [IMPORTANT] Don't make it public!
    public let container: Container

    public init(model: Model, container: Container) {
        self.model = model
        self.container = container
    }

    var stepCount: Int = 0

    public func step() -> StepResult<SeproSignal> {
        // var notifications = Set<Symbol>()
        // var traps = Set<Symbol>()
        // var halts: Bool = false

        stepCount += 1
        debugPrint("STEP \(stepCount)")

        // Unary actuators
        // ---------------
        // FIXME: Those inner conditions are not 100% right - what if an object
        // has been changed in a way that it has to be considered?
        for (label, actuator) in model.unaryActuators {
            for oid in container.select(actuator.selector) {
                if !container.matches(oid, selector: actuator.selector) {
                    // The object has been modified through some of the rules,
                    // we skip it
                    debugPrint("skip")
                    continue
                }
                debugPrint("ACT \(label):\(oid)")
                container.update(oid, with: actuator.transitions)
            }
        }

        // Binary actuators
        // ----------------

        for (label, actuator) in model.binaryActuators {
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

                    debugPrint("REACT \(label): \(left) ON \(right)")
                    container.update(left,
                                     with: actuator.leftTransitions,
                                     other: right)
                    container.update(right,
                                     with: actuator.rightTransitions,
                                     other: left)
                }
            }
        }

        return .ok(signal: nil)
    }

	public func debugDump() {
		debugPrint(">>> SIMULATOR DUMP START\n")
		for key in container.objects.keys {
            let obj = container[key]
			debugPrint("    \(obj)")
		}
		debugPrint("<<< END OF DUMP\n")
	}

}
