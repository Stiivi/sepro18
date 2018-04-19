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

    var presentSymbols: Set<Symbol> {
        let result = mask.filter {
            item in item.1 == .present
        }.map { $0.0 }

        return Set(result)
    }
    var absentSymbols: Set<Symbol> {
        let result = mask.filter {
            item in item.1 == .absent
        }.map { $0.0 }

        return Set(result)
    }

    /// - Returns: true if the mask matches set of symbols.
    ///
    func matches(_ symbols: Set<Symbol>) -> Bool {
        return presentSymbols.isSubset(of: symbols)
                && absentSymbols.isDisjoint(with: symbols)
    }

}

/// Pattern matching an object based on presence or absence of tags or synbols
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
}

/// Type specifying indirection of a subject to be considered in a selector.
///
public enum SubjectMode: Hashable {
    /// Refers to a direct subject
    case direct
    /// Refers to a slot in a subject
    case indirect(Symbol)
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

public struct BinaryTransition {
    public let tags: SymbolMask
    public let bindings: [Symbol: BinaryTarget]

    public init(tags: SymbolMask, bindings: [Symbol:BinaryTarget]) {
        self.tags = tags
        self.bindings = bindings
    }
}

public struct BinaryActuator {
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
}

public struct Prototype {
    public let tags: [Symbol]
}

public struct DuplicatedPrototype {
    public let count: Int
    public let prototype: Prototype
}

public struct Structure {
    public let prototypes: [DuplicatedPrototype]
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

    public func setActuator(unary: UnaryActuator, name: String) {
        unaryActuators[name] = unary
    }

    public func setActuator(binary: BinaryActuator, name: String) {
        binaryActuators[name] = binary
    }

    public var description: String {
        var items: Array<String> = []

        items += symbols.filter {
            (key, value) in value == .slot || value == .tag
        }.map { (key, value) in "DEF \(value) \(key)" }

        return items.joined(separator: "\n")

    }
}

