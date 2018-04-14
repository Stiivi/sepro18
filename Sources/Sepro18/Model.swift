// Sepro 2018 - Model
//

public typealias Symbol = String

public enum SymbolType {
    case tag
    case slot
}

// Basic types
//

public enum Presence {
    case present
    case absent
}

public struct SymbolMask {
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
public struct SelectorPattern {
    let tags: SymbolMask
    let slots: SymbolMask
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
    
    let tags: SymbolMask
    let bindings: [Symbol: UnaryTarget]
}

public struct UnaryActuator {
    let selector: Selector
    let transitions: [SubjectMode:UnaryTransition]

    let notifications: Set<Symbol>
    let traps: Set<Symbol>
    let halts: Bool
}

// Binary
// ======

public enum BinaryTarget {
    case none
    case other
    case inOther(Symbol)
}

public struct BinaryTransition {
    let tags: SymbolMask
    let bindings: [Symbol: BinaryTarget]
}

public struct BinaryActuator {
    let leftSelector: Selector
    let rightSelector: Selector

    let leftTransitions: [SubjectMode:BinaryTransition]
    let rightTransitions: [SubjectMode:BinaryTransition]

    let notifications: Set<Symbol>
    let traps: Set<Symbol>
    let halts: Bool
}




public class Model {
    public var symbols: [Symbol:SymbolType] = [:]
    public var unaryActuators: [UnaryActuator] = []
    public var binaryActuators: [BinaryActuator] = []

}

