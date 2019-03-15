import Simulator
import Model

// TODO: Unused for now, we just need a signal type
public struct SeproSignal {
    public let traps: Set<Symbol>
    public let notifications: Set<Symbol>
}

/// Simulation of the Sepro model
///
public class SeproSimulation: IterativeSimulation {
    public typealias Signal = SeproSignal

    public let model: Model
    public let graph: SeproObjectGraph

    public init(model: Model) {
        self.model = model
        self.graph = SeproObjectGraph()
    }

    var stepCount: Int = 0

    public func step() -> StepResult<SeproSignal> {
        var notifications = Set<Symbol>()
        var traps = Set<Symbol>()
        var halts: Bool = false

        stepCount += 1
        debugPrint("STEP \(stepCount)")

        // Unary actuators
        // ---------------
        // FIXME: Those inner conditions are not 100% right - what if an object
        // has been changed in a way that it has to be considered?
        for (label, actuator) in model.unaryActuators {
            for oid in graph.select(actuator.selector) {
                if !graph.matches(oid, selector: actuator.selector) {
                    // The object has been modified through some of the rules,
                    // we skip it
                    debugPrint("skip")
                    continue
                }

                if actuator.signal.halts {
                    halts = true
                }
                if !actuator.signal.notifications.isEmpty {
                    notifications.formUnion(actuator.signal.notifications)
                }
                if !actuator.signal.traps.isEmpty {
                    traps.formUnion(actuator.signal.traps)
                }

                debugPrint("ACT \(label):\(oid)")
                graph.update(oid, with: actuator.transitions)
            }
        }

        // Binary actuators
        // ----------------

        for (label, actuator) in model.binaryActuators {
            let leftOnes = graph.select(actuator.leftSelector)
            let rightOnes = graph.select(actuator.rightSelector)

            for left in leftOnes {
                for right in rightOnes {
                    if !graph.matches(left, selector: actuator.leftSelector) {
                        // The left has been modified - the rest of the right
                        // side can't be processed
                        break
                    }
                    if !graph.matches(right, selector: actuator.rightSelector) {
                        // The right has been modified, we skip it
                        continue
                    }

                    if actuator.signal.halts {
                        halts = true
                    }
                    if !actuator.signal.notifications.isEmpty {
                        notifications.formUnion(actuator.signal.notifications)
                    }
                    if !actuator.signal.traps.isEmpty {
                        traps.formUnion(actuator.signal.traps)
                    }

                    debugPrint("REACT \(label): \(left) ON \(right)")
                    graph.update(left,
                                     with: actuator.leftTransitions,
                                     other: right)
                    graph.update(right,
                                     with: actuator.rightTransitions,
                                     other: left)
                }
            }
        }

        if halts {
            return .halt(signal: SeproSignal(traps: traps,
                                             notifications: notifications))
        }
        else {
            return .ok(signal: SeproSignal(traps: traps,
                                             notifications: notifications))
        }
    }

    /// Creates a new structure in the container
    ///
    // returns represented object of the structure
    // represented object for now is the first object
    @discardableResult
    public func create(structure: Structure) -> OID {
        let newObjects: [Symbol:OID]

        newObjects = Dictionary(uniqueKeysWithValues:
            structure.objects.map {
                ($0.key, graph.create(tags: $0.value.tags))
            }
        )

        for binding in structure.bindings {
            guard let origin = newObjects[binding.fromName] else {
                fatalError("Unknown structure origin '\(binding.fromName)'")
            }
            guard let target = newObjects[binding.toName] else {
                fatalError("Unknown structure target '\(binding.toName)'")
            }

            graph.bind(origin, to: target, slot: binding.slot)
        }
        // TODO: represented object for now is the first object
        // FIXME: struct must be non-empty
        return Array(newObjects.values)[0]
    }


	public func debugDump() {
        graph.debugDump()
	}

}
