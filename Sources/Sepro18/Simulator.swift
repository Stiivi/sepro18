public class Simulator {
    let model: Model
    let container: Container

    public init(model: Model, container: Container) {
        self.model = model
        self.container = container
    }

    public func step() {
        // var notifications = Set<Symbol>()
        // var traps = Set<Symbol>()
        // var halts: Bool = false

        // Unary actuators
        // ---------------
        // FIXME: Those inner conditions are not 100% right - what if an object
        // has been changed in a way that it has to be considered?
        for actuator in model.unaryActuators.values {

            for oid in container.select(actuator.selector) {
                if !container.matches(oid, selector: actuator.rightSelector) {
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
}

