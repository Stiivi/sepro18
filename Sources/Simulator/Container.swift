import Model

/// Simple implementation of object container.
/// 
/// Object container is guaranteed to maintain internal consistency – there
/// should be no invalid references.
///
public class Container {
    var objects:[OID:Object]
    var counter: Int
    

    public init() {
        objects = [OID:Object]()
        counter = 1
    }

    /// Creates a new object in the container
    ///
    @discardableResult
    public func create(prototype: Prototype) -> OID {
        let oid = OID(id: counter)

        counter += 1

        objects[oid] = Object(tags: prototype.tags, references: [:])

        return oid
    }

    /// Selects objects from the container that match patterns of `selector`.
    ///
    /// If a subject mode refers to an indirect object and the referenced
    /// object does not exist, the pattern is evaluated as not matching.
    ///
    /// - Returns: Lazy collection of objects matching the selector pattern
    ///
    public func select(_ selector: Selector) -> AnyCollection<OID> {
        let result: AnyCollection<OID>

        switch selector {
        case .all: 
            result = AnyCollection(objects.keys.lazy)
        case .match(let patterns): 
            let filtered = objects.keys.lazy.filter {
                self.matches($0, patterns: patterns)
            }
            result = AnyCollection(filtered)
        }

        return result
    }


    /// Test whether an object `oid` matches `selector`.
    ///
    func matches(_ oid: OID, selector: Selector) -> Bool {
        switch selector {
        case .all: 
            return true 
        case .match(let patterns): 
            return matches(oid, patterns: patterns)
        }

    }

    /// FIXME: 
    func matches(_ oid: OID, patterns: [SubjectMode:SelectorPattern]) -> Bool{
        let containsNotMatching = patterns.contains {
            item in

            self.effectiveSubject(oid, mode: item.key).map {
                !self.matches($0, pattern: item.value)
            } ?? false
        }

        return !containsNotMatching
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

        objects[effectiveOid] = effective
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

        objects[effectiveOid] = effective
    }

    public subscript(oid: OID) -> Object {
        // index is expeced to be valid
        // FIXME: Should invalid oid be an error?
        return objects[oid]!
    }

    public func slots(object:OID) -> Set<Symbol> {
        return objects[object]!.slots
    }
}


