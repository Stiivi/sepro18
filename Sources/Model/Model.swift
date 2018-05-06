// Sepro 2018 - Model
//

public typealias Symbol = String

/// Type of a symbol within a model.
///
public enum SymbolType {
    /// Symbol represents a slot
    case slot
    /// Symbol represents a tag
    case tag
    case structure
    case actuator

    public init?(name: String) {
        switch name {
        case "slot": self = .slot
        case "tag": self = .tag
        case "structure": self = .structure
        case "actuator": self = .actuator
        default: return nil
        }
    }
}

// Basic types
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
public struct SymbolMask {
    public let mask: [Symbol:Presence]

    public init(mask: [Symbol:Presence]) {
        self.mask = mask
    }

    public var presentSymbols: Set<Symbol> {
        let result = mask.filter {
            item in item.1 == .present
        }.map { $0.0 }

        return Set(result)
    }
    public var absentSymbols: Set<Symbol> {
        let result = mask.filter {
            item in item.1 == .absent
        }.map { $0.0 }

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
            item in
            let symbol = item.key
            let presence = item.value

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
}

/// Pattern matching an object based on presence or absence of tags or slots
///
public struct SelectorPattern {
    public let tags: SymbolMask
    public let slots: SymbolMask

    public init(tags: SymbolMask, slots: SymbolMask) {
        self.tags = tags
        self.slots = slots
    }

}

/// Object specifying which objects to select based on a pattern matching mask.
///
public enum Selector {
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
                item in
                let mode = item.key
                let pattern = item.value
                return pattern.tags.descriptionWithSubject(mode)
            }
            result += matches.compactMap {
                item in
                let mode = item.key
                let pattern = item.value
                return pattern.slots.descriptionWithSubject(mode)
            }
        }

        return result.joined(separator: " ")
    }
}

/// Type specifying indirection of a subject to be considered in a selector.
///
public enum SubjectMode: Hashable {
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
}


// Unary
// =====

public enum UnaryTarget {
    case none
    case subject
    case direct(Symbol)
    case indirect(Symbol, Symbol)
}

public struct UnaryTransition {
    
    public let tags: SymbolMask
    public let bindings: [Symbol: UnaryTarget]

    public init(tags: SymbolMask, bindings: [Symbol:UnaryTarget]){
        self.tags = tags
        self.bindings = bindings
    }
}

public struct UnaryActuator {
    public let selector: Selector
    public let transitions: [SubjectMode:UnaryTransition]

    public let notifications: Set<Symbol>
    public let traps: Set<Symbol>
    public let halts: Bool

    public init(selector: Selector, transitions: [SubjectMode:UnaryTransition],
                notifications: Set<Symbol>, traps: Set<Symbol>, halts: Bool) {
                
        self.selector = selector
        self.transitions = transitions
        self.notifications = notifications
        self.traps = traps
        self.halts = halts
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
            item in
            let symbol = item.key
            let target = item.value

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

    public let notifications: Set<Symbol>
    public let traps: Set<Symbol>
    public let halts: Bool

    public init(leftSelector: Selector, rightSelector: Selector,
                leftTransitions: [SubjectMode:BinaryTransition],
                rightTransitions: [SubjectMode:BinaryTransition],
                notifications: Set<Symbol>,
                traps: Set<Symbol>,
                halts: Bool) {
        self.leftSelector = leftSelector
        self.rightSelector = rightSelector
        self.leftTransitions = leftTransitions
        self.rightTransitions = rightTransitions
        self.notifications = notifications
        self.traps = traps
        self.halts = halts
    }

    public var description: String {
        var result: [String] = []

        result = [
            "WHERE", "(", leftSelector.description, ")",
            "ON", "(", rightSelector.description, ")",
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

public struct Prototype {
    public let tags: Set<Symbol>

    public init(tags: Set<Symbol>) {
        self.tags = tags
    }
}

public struct MultiPrototype {
    public let count: Int
    public let prototype: Prototype

    public init(count: Int, prototype: Prototype) {
        self.count = count
        self.prototype = prototype
    }
}

public struct Structure {
    public let prototypes: [MultiPrototype]

    public init(prototypes: [MultiPrototype]) {
        self.prototypes = prototypes
    }
}

/// Sepro model description.
///
public class Model: CustomStringConvertible {
    // FIXME: Make all properties immutable (let)
    //        - they are made mutable for the compiler
    //
    public var symbols: [Symbol:SymbolType] = [:]
    public var unaryActuators: [String:UnaryActuator] = [:]
    public var binaryActuators: [String:BinaryActuator] = [:]
    public var structures: [String:Structure] = [:]

    public init() {
    }

    /// - Returns: Type of a symbol `symbol`. If symbol is not defined, then
    /// returns `SymbolType.undefined`
    public func typeOf(symbol: Symbol) -> SymbolType? {
        return symbols[symbol]
    }

    // Mutation methods
    // ================

    /// Define a symbol `symbol` to be of `type` if it is not defined.
    /// - Returns: `true` if the symbol was successfully defined or if symbol
    /// existed and was of the same type. Returns `false` if the symbol was
    /// already defined but was of another type.

    @discardableResult
    public func define(symbol: Symbol, type: SymbolType) -> Bool {
        if let previous = symbols[symbol] {
            if previous == type {
                return true
            } 
            else {
                return false
            }
        }

        symbols[symbol] = type
        return true
    }

    public func insertActuator(unary: UnaryActuator, name: String) {
        unaryActuators[name] = unary
    }

    public func insertActuator(binary: BinaryActuator, name: String) {
        binaryActuators[name] = binary
    }

    public var description: String {
        var items: Array<String> = []

        items += symbols.filter {
            (key, value) in value == .slot || value == .tag
        }.map { (key, value) in "DEF \(value) \(key)" }

        items += unaryActuators.map {
            (key, value) in
            "ACT \(key) ..."
        }

        items += binaryActuators.map {
            (key, value) in
            "REACT \(key) \(value)"
        }

        items += structures.map {
            (key, value) in
            "STRUCT \(key) ..."
        }

        return items.joined(separator: "\n")

    }

    public func insertStructure(_ structure: Structure, name: String) {
        structures[name] = structure 
    }
}

