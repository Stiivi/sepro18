typealias OID = Int


struct Object {
    public var tags: Set<Symbol>
    public var references: [Symbol:OID]

    public var slots: Set<Symbol> {
        return Set(references.keys)
    }
}


/// Simple implementation of object container.
/// 
/// Object container is guaranteed to maintain internal consistency – there
/// should be no invalid references.
///
class Container {
    var objects:[OID:Object]

    init() {
        objects = [OID:Object]()
    }

    /// Selects objects from the container that match patterns of `selector`.
    ///
    /// If a subject mode refers to an indirect object and the referenced
    /// object does not exist, the pattern is evaluated as not matching.
    ///
    /// - Returns: Lazy collection of objects matching the selector pattern
    ///
    func select(_ selector: Selector) -> AnyCollection<OID> {
        switch selector {
        case .all: return selectAll()
        case .match(let patterns): return select(patterns: patterns)
        }
    }

    /// Selects all objects from the container
    ///
    func selectAll() -> AnyCollection<OID> {
        return AnyCollection(objects.keys.lazy)
    }

    func select(patterns: [SubjectMode:SelectorPattern]) -> AnyCollection<OID> {
        let result = objects.keys.lazy.filter {
            oid in

            let containsNotMatching = patterns.contains {
                item in

                self.effectiveSubject(oid, mode: item.key).map {
                    !self.matches($0, pattern: item.value)
                } ?? false
            }

            return !containsNotMatching
        }

        return AnyCollection(result)
    }

    /// Returns effective subject for given OID. If the `mode` is `direct` then
    /// the effective subject is the object itself, if the `mode` is `indirect`
    /// then the subject is object referenced by the indirect slot.
    ///
    /// - Precondition: Object reference must be valid within the container.
    ///

    func effectiveSubject(_ oid: OID, mode: SubjectMode) -> OID? {
        guard let object = objects[oid] else {
            preconditionFailure("Invalid object reference \(oid)")
        }
        switch mode {
        case .direct: return oid
        case .indirect(let slot): return object.references[slot]
        }
    }


    /// Check whether object referenced by `OID` matches `pattern`.
    ///
    /// - Precondition: Object reference must be valid within the container.
    ///
    func matches(_ oid: OID, pattern: SelectorPattern) -> Bool {
        guard let object = objects[oid] else {
            preconditionFailure("Invalid object reference \(oid)")
        }
        
        return pattern.tags.matches(object.tags)
                && pattern.slots.matches(object.slots)
    }

    /// Applies set of transitions to object `oid`.
    ///
    func update(_ oid: OID, with transitions: [SubjectMode:UnaryTransition]) {
        transitions.forEach {
            trans in

            if let effective = effectiveSubject(oid, mode: trans.key) {
                update(effective,
                       with: trans.value,
                       subject: oid)
            }
        }    
         
    }

    /// Applies unary transition to `effective` subject with original subject
    /// `subject`.
    func update(_ effectiveOid: OID,
                with transition: UnaryTransition,
                subject subjectOid: OID) {
        guard var subject = objects[subjectOid] else {
            preconditionFailure("Invalid object reference \(subjectOid)")
        }
        guard var effective = objects[effectiveOid] else {
            preconditionFailure("Invalid object reference \(effectiveOid)")
        }

        effective.tags.formUnion(transition.tags.presentSymbols)
        effective.tags.subtract(transition.tags.absentSymbols)
       
        transition.bindings.forEach {
            binding in

            let target: OID?

            switch binding.value {
            case .none:
                target = nil
            case .subject:
                target = subjectOid
            case .direct(let symbol):
                target = subject.references[symbol]
            case .indirect(let indirect, let symbol):

                target = subject.references[indirect].flatMap {
                                objects[$0].flatMap {
                                    $0.references[symbol]
                                }
                            }
            }

            effective.references[binding.key] = target
        }
    }


    /// Update object `oid` with with a set of binary transitions in context of
    /// interaction with `other` object.
    ///
    func update(_ oid: OID,
                with transitions: [SubjectMode:BinaryTransition],
                other: OID) {

        transitions.forEach {
            trans in

            if let effective = effectiveSubject(oid, mode: trans.key) {
                update(effective,
                       with: trans.value,
                       other: other)
            }
        }    
         
    }
    /// Update an object within a binary interaction using `transition` and
    /// other interating object as `other`.
    ///
    func update(_ effectiveOid: OID,
                with transition: BinaryTransition,
                other otherOid: OID) {
        guard var effective = objects[effectiveOid] else {
            preconditionFailure("Invalid object reference \(effectiveOid)")
        }
        guard var other = objects[otherOid] else {
            preconditionFailure("Invalid object reference \(otherOid)")
        }

        effective.tags.formUnion(transition.tags.presentSymbols)
        effective.tags.subtract(transition.tags.absentSymbols)
       
        transition.bindings.forEach {
            binding in

            let target: OID?

            switch binding.value {
            case .none:
                target = nil
            case .other:
                target = otherOid
            case .inOther(let symbol):
                target = other.references[symbol]
            }

            effective.references[binding.key] = target
        }
    }
}


class Simulator {
    let model: Model
    let container: Container

    init(model: Model, container: Container) {
        self.model = model
        self.container = container
    }

    func step() {
        // var notifications = Set<Symbol>()
        // var traps = Set<Symbol>()
        // var halts: Bool = false

        // Unary actuators
        // ---------------
        model.unaryActuators.values.forEach {
            actuator in

            container.select(actuator.selector).forEach {
                oid in 
                container.update(oid, with: actuator.transitions)
            }
        }

        // Binary actuators
        // ----------------

        model.binaryActuators.values.forEach {
            actuator in
            let leftOnes = container.select(actuator.leftSelector)
            let rightOnes = container.select(actuator.rightSelector)

            leftOnes.forEach {
                left in
                rightOnes.forEach {
                    right in
                    container.update(left,
                                     with: actuator.leftTransitions,
                                     other: right)
                    // TODO: Should we validate potential change in the right
                    // one?
                    container.update(right,
                                     with: actuator.rightTransitions,
                                     other: left)
                }
            }
        }
    }
}

