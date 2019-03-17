// Actuator related structures
//

/// Type used in a symbol mask specifying whether a matched symbol should be
/// present or not.
///
public enum Presence {
    case present
    case absent
}

/// Mask for symbol matching in a selector
///
public struct SymbolMask: CustomStringConvertible {
    public let mask: [Symbol:Presence]

    public init(mask: [Symbol:Presence]) {
        self.mask = mask
    }

    public var presentSymbols: Set<Symbol> {
        let result = mask.filter { $0.1 == .present }.map { $0.0 }

        return Set(result)
    }
    public var absentSymbols: Set<Symbol> {
        let result = mask.filter { $0.1 == .absent }.map { $0.0 }

        return Set(result)
    }

    /// - Returns: true if the mask matches set of symbols.
    ///
    public func matches(_ symbols: Set<Symbol>) -> Bool {
        return presentSymbols.isSubset(of: symbols)
                && absentSymbols.isDisjoint(with: symbols)
    }

    public func descriptionWithSubject(_ mode: SubjectMode) -> String {
        var result: [String] = []

        result += mask.map {
            let symbol = $0.key
            let presence = $0.value

            let prefix: String
            let subject: String

            switch presence {
            case .present: prefix = ""
            case .absent: prefix = "!"
            }

            switch mode {
            case .direct: subject = ""
            case .indirect(let slot): subject = "\(slot)."
            }


            return prefix + subject + symbol
        }

        return result.joined(separator: " ")

    }

    public var description: String {
        var result: [String] = []

        result += mask.map {
            let (symbol, presence) = ($0.key, $0.value)

            let prefix: String

            switch presence {
            case .present: prefix = ""
            case .absent: prefix = "!"
            }

            return prefix + symbol
        }

        return "(" + result.joined(separator: " ") + ")"

    }
}

/// Pattern matching an object based on presence or absence of tags or slots
///
public struct SelectorPattern: CustomStringConvertible {
    public let tags: SymbolMask
    public let slots: SymbolMask

    public init(tags: SymbolMask, slots: SymbolMask) {
        self.tags = tags
        self.slots = slots
    }

    public var description: String {
        return "{tags: \(tags), slots: \(slots)}"
    }
}

/// Object specifying which objects to select based on a pattern matching mask.
///
public enum Selector: CustomStringConvertible {
    /// Match all objects.
    case all
    /// Match only objects matching a patter.
    case match([SubjectMode:SelectorPattern])

    public var description: String {
        var result: [String] = []

        switch self {
        case .all: result = ["ALL"]
        case .match(let matches):
            result += matches.compactMap {
                let mode = $0.key
                let pattern = $0.value
                return pattern.tags.descriptionWithSubject(mode)
            }
            result += matches.compactMap {
                let mode = $0.key
                let pattern = $0.value
                return pattern.slots.descriptionWithSubject(mode)
            }
        }

        return result.joined(separator: " ")
    }
}

/// Type specifying indirection of a subject to be considered in a selector.
///
public enum SubjectMode: Hashable, CustomStringConvertible {
    /// Refers to a direct subject
    case direct
    /// Refers to a slot in a subject
    case indirect(Symbol)

    public func descriptionForSubject(_ subject: String) -> String {
        switch self {
        case .direct: return subject
        case .indirect(let slot): return "\(subject).\(slot)"
        }
    }

    public var description: String {
        switch self {
        case .direct: return "direct"
        case .indirect(let slot): return "indirect(\(slot))"
        }
    }
}


public struct Signal {
    public let notifications: Set<Symbol>
    public let traps: Set<Symbol>
    public let halts: Bool

    public init(notifications: Set<Symbol>, traps: Set<Symbol>, halts: Bool) {
        self.notifications = notifications
        self.traps = traps
        self.halts = halts
    }
}


// Unary
// =====

public enum UnaryTarget {
    case none
    case subject
    case direct(Symbol)
    case indirect(Symbol, Symbol)
}

public struct UnaryTransition: CustomStringConvertible {

    public let tags: SymbolMask
    public let bindings: [Symbol: UnaryTarget]

    public init(tags: SymbolMask, bindings: [Symbol:UnaryTarget]) {
        self.tags = tags
        self.bindings = bindings
    }

    public var description: String {
        var result: [String] = []

        result += tags.presentSymbols.map { "SET \($0)" }
        result += tags.absentSymbols.map { "UNSET \($0)" }
        result += bindings.map {
            let symbol = $0.key
            let target = $0.value

            switch target {
            case .none: return "UNBIND \(symbol)"
            case .subject: return "BIND \(symbol) TO SELF"
            case let .direct(target): return "BIND \(symbol) TO \(target)"
            case let .indirect(slot, target):
                return "BIND \(symbol) TO \(slot).\(target)"
            }
        }

        return result.joined(separator: " ")
    }
}

public struct UnaryActuator {
    public let selector: Selector
    public let transitions: [SubjectMode:UnaryTransition]

    public let signal: Signal

    public init(selector: Selector, transitions: [SubjectMode:UnaryTransition],
                signal: Signal) {

        self.selector = selector
        self.transitions = transitions
        self.signal = signal
    }
}

// Binary
// ======

public enum BinaryTarget {
    case none
    case other
    case inOther(Symbol)
}

public struct BinaryTransition: CustomStringConvertible {
    public let tags: SymbolMask
    public let bindings: [Symbol: BinaryTarget]

    public init(tags: SymbolMask, bindings: [Symbol:BinaryTarget]) {
        self.tags = tags
        self.bindings = bindings
    }

    public var description: String {
        var result: [String] = []

        result += tags.presentSymbols.map { "SET \($0)" }
        result += tags.absentSymbols.map { "UNSET \($0)" }
        result += bindings.map {
            let symbol = $0.key
            let target = $0.value

            switch target {
            case .none: return "UNBIND \(symbol)"
            case .other: return "BIND \(symbol) TO OTHER"
            case .inOther(let indirect): return "BIND \(symbol) TO OTHER.\(indirect)"
            }
        }

        return result.joined(separator: " ")
    }
}

public struct BinaryActuator: CustomStringConvertible {
    public let leftSelector: Selector
    public let rightSelector: Selector

    public let leftTransitions: [SubjectMode:BinaryTransition]
    public let rightTransitions: [SubjectMode:BinaryTransition]

    public let signal: Signal

    public init(leftSelector: Selector, rightSelector: Selector,
                leftTransitions: [SubjectMode:BinaryTransition],
                rightTransitions: [SubjectMode:BinaryTransition],
                signal: Signal) {
        self.leftSelector = leftSelector
        self.rightSelector = rightSelector
        self.leftTransitions = leftTransitions
        self.rightTransitions = rightTransitions
        self.signal = signal
    }

    public var description: String {
        var result: [String] = []

        result = [
            "WHERE", "(", leftSelector.description, ")",
            "ON", "(", rightSelector.description, ")"
        ]

        result += leftTransitions.map {
            return "IN \($0.key.descriptionForSubject("LEFT")) \($0.value)"
        }

        result += rightTransitions.map {
            return "IN \($0.key.descriptionForSubject("RIGHT")) \($0.value)"
        }

        // TODO: add control

        return result.joined(separator: " ")
    }
}

