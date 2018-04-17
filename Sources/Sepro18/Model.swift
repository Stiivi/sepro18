// Sepro 2018 - Model
//

public typealias Symbol = String

/// Type of a symbol within a model.
///
public enum SymbolType {
    /// Symbol is not defined within the model
    case undefined
    /// Symbol represents a slot
    case slot
    /// Symbol represents a tag
    case tag
}

// Basic types
//

public enum Presence {
    case present
    case absent
}

public struct SymbolMask {
    public let mask: [Symbol:Presence]

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
public struct SelectorPattern {
    public let tags: SymbolMask
    public let slots: SymbolMask
}

public enum Selector {
    case all
    case match([SubjectMode:SelectorPattern])
}

public enum SubjectMode: Hashable {
    case direct
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
}

public struct UnaryActuator {
    public let selector: Selector
    public let transitions: [SubjectMode:UnaryTransition]

    public let notifications: Set<Symbol>
    public let traps: Set<Symbol>
    public let halts: Bool
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
}

public struct BinaryActuator {
    public let leftSelector: Selector
    public let rightSelector: Selector

    public let leftTransitions: [SubjectMode:BinaryTransition]
    public let rightTransitions: [SubjectMode:BinaryTransition]

    public let notifications: Set<Symbol>
    public let traps: Set<Symbol>
    public let halts: Bool
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
public class Model {
    // FIXME: Make all properties immutable (let)
    //        - they are made mutable for the compiler
    //
    public var symbols: [Symbol:SymbolType] = [:]
    public var unaryActuators: [String:UnaryActuator] = [:]
    public var binaryActuators: [String:BinaryActuator] = [:]
    public var structures: [String:Structure] = [:]

    /// - Returns: Type of a symbol `symbol`. If symbol is not defined, then
    /// returns `SymbolType.undefined`
    public func typeOf(symbol: Symbol) -> SymbolType {
        return symbols[symbol] ?? .undefined
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
}

