import Model
import ObjectGraph

/// Structure holding an object graph with unique identifiers of the objects.
/// 
/// Object container is guaranteed to maintain internal consistency – there
/// should be no invalid references.
///
public class SeproObjectGraph {
    public struct ObjectState {
        public let tags: Set<Symbol>
    }

    public typealias Graph = ObjectGraph<OID, ObjectState, Symbol>

    var graph: Graph
    var counter: Int

    public init() {
        graph = ObjectGraph()
        counter = 1
    }

    /// Get a list of all object references in the object graph.
    // FIXME: All places labelled with #graph should be reconsidered. They are
    // just aliases for the underlying graph structure.
    // TODO: #graph
    public var references: Graph.References {
        return graph.references
    }

    // TODO: #graph
    public var objects: Graph.Objects {
        return graph.objects
    }

    /// Creates a new object in the container
    ///
    // TODO: Does this has to be here? Not in Sim?
    // TODO: #simulation
    @discardableResult
    public func create(tags: Set<Symbol>) -> OID {
        let oid = OID(id: counter)

        counter += 1
        graph.insert(oid, state: ObjectState(tags: tags))

        return oid
    }

    // TODO: #graph
    public func bind(_ origin: OID, to target: OID, slot: Symbol) {
        graph.connect(origin, to: target, at: slot)
    }

    // TODO: #graph
    public func state(_ oid: OID) -> ObjectState? {
        return graph[oid]
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
            result = AnyCollection(graph.references.lazy)
        case .match(let patterns):
            // TODO: LAZY
            let filtered = graph.references.filter {
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

    func matches(_ oid: OID, patterns: [SubjectMode:SelectorPattern]) -> Bool {
        let flag = patterns.allSatisfy { item in
            effectiveSubject(oid, mode: item.key).map {
                matches($0, pattern: item.value)
            } ?? false
        }

        return flag
    }
    /// Check whether object referenced by `OID` matches `pattern`.
    ///
    /// - Precondition: Object reference must be valid within the container.
    ///
    func matches(_ oid: OID, pattern: SelectorPattern) -> Bool {
        guard let state = graph[oid] else {
            preconditionFailure("Invalid object reference \(oid)")
        }

        return pattern.tags.matches(state.tags)
                && pattern.slots.matches(slots(oid))
    }

    /// Get a set of occupied slots of object `oid`.
    func slots(_ oid: OID) -> Set<Symbol> {
        return Set(graph.slots(oid))
    }

    /// Returns effective subject for given OID. If the `mode` is `direct` then
    /// the effective subject is the object itself, if the `mode` is `indirect`
    /// then the subject is object referenced by the indirect slot.
    ///
    /// - Precondition: Object reference must be valid within the container.
    ///

    func effectiveSubject(_ oid: OID, mode: SubjectMode) -> OID? {
        let effective: OID?

        switch mode {
        case .direct:
            effective = oid
        case .indirect(let slot):
            effective = graph.target(oid, at: slot)
        }

        return effective
    }

    /// Applies set of transitions to object `oid`.
    ///
    func update(_ oid: OID, with transitions: [SubjectMode:UnaryTransition]) -> Graph.TransformList {
        var transforms = Graph.TransformList()

        for transition in transitions {
            if let effective = effectiveSubject(oid, mode: transition.key) {
                transforms += update(effective,
                                     with: transition.value,
                                     subject: oid)
            }
        }

        return transforms
    }

    /// Applies unary transition to `effective` subject with original subject
    /// `subject`.
    func update(_ effective: OID,
                with transition: UnaryTransition,
                subject: OID) -> Graph.TransformList {
        guard let effectiveState = graph[effective] else {
            preconditionFailure("Invalid object reference \(effective)")
        }

        var transforms = Graph.TransformList()

        let newTags = effectiveState.tags.union(transition.tags.presentSymbols)
                            .subtracting(transition.tags.absentSymbols)

        transforms.append {
            $0.updateState(ObjectState(tags: newTags), of: effective)
        }

        for (subjectSlot, targetType) in transition.bindings {
            let target: OID?

            switch targetType {
            case .none:
                target = nil
            case .subject:
                target = subject
            case .direct(let symbol):
                target = graph.target(subject, at: symbol)
            case .indirect(let indirect, let symbol):
                target = graph.target(subject, at: indirect).flatMap {
                    graph.target($0, at: symbol)
                }
            }

        // TODO: #update
            if let target = target {
                transforms.append {
                    $0.connect(effective, to: target, at: subjectSlot)
                }
            }
            else {
                transforms.append {
                    $0.disconnect(effective, at: subjectSlot)
                }
            }
        }

        return transforms
    }


    /// Update object `oid` with with a set of binary transitions in context of
    /// interaction with `other` object.
    ///
    func update(_ oid: OID,
                with transitions: [SubjectMode:BinaryTransition],
                other: OID) -> Graph.TransformList {

        var transforms = Graph.TransformList()

        for (subjectMode, transition) in transitions {
            if let effective = effectiveSubject(oid, mode: subjectMode) {
                transforms += update(effective,
                                     with: transition,
                                     other: other)
            }
        }
        return transforms
    }

    /// Update an object within a binary interaction using `transition` and
    /// other interating object as `other`.
    ///
    func update(_ effective: OID,
                with transition: BinaryTransition,
                other: OID) -> Graph.TransformList {
        guard let effectiveState = graph[effective] else {
            preconditionFailure("Invalid object reference \(effective)")
        }

        var transforms = Graph.TransformList()

        let newTags = effectiveState.tags.union(transition.tags.presentSymbols)
                            .subtracting(transition.tags.absentSymbols)
        // TODO: #update
        transforms.append {
            $0.updateState(ObjectState(tags: newTags), of: effective)
        }

        for (subjectSlot, targetMode) in transition.bindings {
            let target: OID?

            switch targetMode {
            case .none:
                target = nil
            case .other:
                target = other
            case .inOther(let symbol):
                target = graph.target(other, at: symbol)
            }

        // TODO: #update
            if let target = target {
                transforms.append {
                    $0.connect(effective, to: target, at: subjectSlot)
                }
            }
            else {
                transforms.append {
                    $0.disconnect(effective, at: subjectSlot)
                }
            }
        }
        return transforms
    }

    public func slots(object:OID) -> Set<Symbol> {
        return Set(graph.slots(object))
    }

	public func debugDump() {
		debugPrint(">>> OBJECT GRAPH DUMP START\n")
		for object in graph.objects {
			debugPrint("    [\(object.reference)] \(object.state) [\(slots(object.reference))]")
		}
		debugPrint("<<< END OF DUMP\n")
	}
}
