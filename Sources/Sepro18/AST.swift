// Abstract Syntax Tree Nodes
//

struct ASTTypedSymbol {
    let type: SymbolType?
    let symbol: String

    init(_ sym: String, type: SymbolType?) {
        self.symbol = sym
        self.type = type
    }
}

enum ASTModelObject {
    case define(String, String)
    case unaryActuator(String, ASTSelector, [ASTTransition])
    case binaryActuator(String, ASTSelector, ASTSelector, [ASTTransition])
    case structure(String, [ASTStructItem])

    var symbols: [ASTTypedSymbol] {
        let result: [ASTTypedSymbol]

        switch self {
        case let .define(type, sym):
            result = [ASTTypedSymbol(sym, type: SymbolType(name: type))]

        case let .unaryActuator(name, sel, mods):
            result = [ASTTypedSymbol(name, type: .actuator)]
                     + sel.symbols
                     + mods.flatMap { $0.symbols } 

        case let .binaryActuator(name, lsel, rsel, mods):
            result = [ASTTypedSymbol(name, type: .actuator)]
                     + lsel.symbols
                     + rsel.symbols
                     + mods.flatMap { $0.symbols } 

        case let .structure(name, items):
            result = [ASTTypedSymbol(name, type: .structure)]
                     + items.flatMap { $0.symbols } 
        }
        return result
    }

}

enum ASTSelector {
    case all
    case match([ASTMatch])

    var symbols: [ASTTypedSymbol] {
        switch self {
        case .all: return []
        case .match(let matches): return matches.flatMap { $0.symbols }
        }
    }
}

struct ASTMatch {
    let isPresent: Bool
    let symbol: ASTQualifiedSymbol

    var symbols: [ASTTypedSymbol] {
        return symbol.symbols
    }
}

enum ASTModifier {
    case bind(ASTQualifiedSymbol, ASTQualifiedSymbol)
    case unbind(ASTQualifiedSymbol)
    case set(String)
    case unset(String)

    var symbols: [ASTTypedSymbol] {
        switch self {
        case let .bind(lhs, rhs):
            let syms = [
                    lhs.qualifier.map { ASTTypedSymbol($0, type: .slot) },
                    ASTTypedSymbol(lhs.symbol, type: .slot),
                    rhs.qualifier.map { ASTTypedSymbol($0, type: .slot) },
                    ASTTypedSymbol(rhs.symbol, type: .slot)
                ]
            return syms.compactMap { $0 }

        case let .unbind(tgt):
            let syms = [
                    tgt.qualifier.map { ASTTypedSymbol($0, type: .slot) },
                    ASTTypedSymbol(tgt.symbol, type: .slot)
                ]
            return syms.compactMap { $0 }

        case let .set(sym):
            return [ASTTypedSymbol(sym, type: .tag)]
        case let .unset(sym):
            return [ASTTypedSymbol(sym, type: .tag)]
        }
    }
}

// Model equivalent: Unary/Binary transition
struct ASTTransition {
    let subject: ASTSubject
    let modifiers: [ASTModifier]

    var symbols: [ASTTypedSymbol] {
        return subject.symbols + modifiers.flatMap { $0.symbols }
    }
}


struct ASTStructItem {
    let count: Int
    let tags: [String]

    var symbols: [ASTTypedSymbol] { return [] }
}

struct ASTQualifiedSymbol {
    let qualifier: Symbol?
    let symbol: Symbol

    var symbols: [ASTTypedSymbol] {
        // We have no type information about the referenced symbol
        let referenced = ASTTypedSymbol(symbol, type: nil)

        // We assume the qualifier to be a slot, since we are referencing
        // some other symbol at that location.
        //
        if let qualifier = qualifier {
            return [ASTTypedSymbol(qualifier, type: .slot),
                    referenced]
        }
        else {
            return [referenced]
        }
    }
}

struct ASTSubject {
    // THIS, LEFT, RIGHT
    let side: String
    let slot: String?

    var symbols: [ASTTypedSymbol] {
        return slot.map { [ASTTypedSymbol($0, type: .slot)] } ?? []
    }
}
