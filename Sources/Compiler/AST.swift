import Model
// Abstract Syntax Tree Nodes
//

// TODO: Introduce "children" to node

protocol ASTNode {
    var symbols: [ASTTypedSymbol] { get }
}

struct ASTTypedSymbol {
    let type: SymbolType?
    let symbol: String

    init(_ sym: String, type: SymbolType?) {
        self.symbol = sym
        self.type = type
    }
}

enum ASTSignal {
    case halt
    case notify([String])
    case trap([String])
}

enum ASTModelObject: ASTNode {
    case define(SymbolType, String)
    case unaryActuator(String, ASTSelector, [ASTTransition], [ASTSignal])
    case binaryActuator(String, ASTSelector, ASTSelector,
                        [ASTTransition], [ASTSignal])
    case structure(String, [ASTStructItem])
    case world(String, [ASTWorldItem])
    case data([String], String)

    var symbols: [ASTTypedSymbol] {
        let result: [ASTTypedSymbol]

        switch self {
        case let .define(type, sym):
            // FIXME: that lowercased() should happen earlier
            result = [ASTTypedSymbol(sym, type: type)]

        case let .unaryActuator(name, sel, mods, _):
            result = [ASTTypedSymbol(name, type: .actuator)]
                     + sel.symbols
                     + mods.flatMap { $0.symbols }

        case let .binaryActuator(name, lsel, rsel, mods, _):
            result = [ASTTypedSymbol(name, type: .actuator)]
                     + lsel.symbols
                     + rsel.symbols
                     + mods.flatMap { $0.symbols }

        case let .structure(name, items):
            result = [ASTTypedSymbol(name, type: .structure)]
                     + items.flatMap { $0.symbols }

        case let .world(name, items):
            result = [ASTTypedSymbol(name, type: .world)]
                     + items.flatMap { $0.symbols }
        case .data:
            // DATA tags are free of type
            result = []
        }
        return result
    }

}

enum ASTStructItem: ASTNode {
    case object(String, [String])
    case binding(String, String, String)

    var symbols: [ASTTypedSymbol] {
        let result: [ASTTypedSymbol]

        switch self {
        case let .object(_, tags):
            // Note: we ignore the name, as it is struct-local
            result = tags.map {
                        ASTTypedSymbol($0, type: .tag)
                     }
        case let .binding(_, slot, _):
            // Note: we ignore the object names as, they are struct-local
            result = [ASTTypedSymbol(slot, type: .slot)]
        }
        return result
    }
}

enum ASTSelector: ASTNode {
    case all
    case match([ASTMatch])

    var symbols: [ASTTypedSymbol] {
        switch self {
        case .all: return []
        case .match(let matches): return matches.flatMap { $0.symbols }
        }
    }
}

struct ASTMatch: ASTNode {
    let isPresent: Bool
    let symbol: ASTQualifiedSymbol

    var symbols: [ASTTypedSymbol] {
        return symbol.symbols
    }
}

// Model equivalent: unary/binary target and bindings in unary/binary trnsition
//
enum ASTModifier: ASTNode {
    case bind(String, ASTQualifiedSymbol)
    case unbind(String)
    case set(String)
    case unset(String)

    var symbols: [ASTTypedSymbol] {
        switch self {
        case let .bind(lhs, rhs):
            let syms = [
                    ASTTypedSymbol(lhs, type: .slot),
                    rhs.qualifier.map { ASTTypedSymbol($0, type: .slot) },
                    ASTTypedSymbol(rhs.symbol, type: .slot)
                ]
            return syms.compactMap { $0 }

        case let .unbind(tgt):
            let syms = [
                    ASTTypedSymbol(tgt, type: .slot)
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
//
struct ASTTransition: ASTNode {
    let subject: ASTSubject
    let modifiers: [ASTModifier]

    var symbols: [ASTTypedSymbol] {
        return subject.symbols + modifiers.flatMap { $0.symbols }
    }
}

enum ASTWorldItem: ASTNode {
    case quantifiedStructure(Int, String)
    case quantifiedObject(Int, [String])

    var symbols: [ASTTypedSymbol] {
        let result: [ASTTypedSymbol]

        switch self {
        case let .quantifiedStructure(_, name):
            result = [ASTTypedSymbol(name, type: .structure)]
        case let .quantifiedObject(_, tags):
            result = tags.map {
                ASTTypedSymbol($0, type: .tag)
            }
        }
        return result
    }
}

struct ASTQualifiedSymbol: ASTNode {
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

struct ASTSubject: ASTNode {
    enum Side {
        case this
        case left
        case right
    }

    // THIS, LEFT, RIGHT
    let side: Side
    let slot: String?

    var symbols: [ASTTypedSymbol] {
        return slot.map { [ASTTypedSymbol($0, type: .slot)] } ?? []
    }
}
