// Sepro 2018 - Model
//

typealias Symbol = String

// Basic types
//

enum Presence {
    case present
    case absent
}

struct SymbolMask {
    let mask: [Symbol:Presence]

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
struct SelectorPattern {
    let tags: SymbolMask
    let slots: SymbolMask
}

enum Selector {
    case all
    case match([SubjectMode:SelectorPattern])
}

enum SubjectMode: Hashable {
    case direct
    case indirect(Symbol)
}


// Unary
// =====

enum UnaryTarget {
    case none
    case subject
    case direct(Symbol)
    case indirect(Symbol, Symbol)
}

struct UnaryTransition {
    
    let tags: SymbolMask
    let bindings: [Symbol: UnaryTarget]
}

struct UnaryActuator {
    let selector: Selector
    let transitions: [SubjectMode:UnaryTransition]

    let notifications: Set<Symbol>
    let traps: Set<Symbol>
    let halts: Bool
}

// Binary
// ======

enum BinaryTarget {
    case none
    case other
    case inOther(Symbol)
}

struct BinaryTransition {
    let tags: SymbolMask
    let bindings: [Symbol: BinaryTarget]
}

struct BinaryActuator {
    let leftSelector: Selector
    let rightSelector: Selector

    let leftTransitions: [SubjectMode:BinaryTransition]
    let rightTransitions: [SubjectMode:BinaryTransition]

    let notifications: Set<Symbol>
    let traps: Set<Symbol>
    let halts: Bool
}




class Model {
    var unaryActuators: [UnaryActuator] = []
    var binaryActuators: [BinaryActuator] = []
}

