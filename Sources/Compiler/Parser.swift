// FIXME: Model import should not be necessary for the parser
import Model

public enum CompilerError: Error {
    case endOfInput
    case unexpectedTokenType(String)
    case symbolExpected(String)
    case expectedToken(String)
    case badSymbolType(String)
    case tagListExpected
    case selectorExpected
    case subjectExpected
    case qualifiedSymbolExpected
}

func parse(source: String) -> [ASTModelObject] {
    let lexer = Lexer(source)
    let parser = Parser(lexer: lexer)

    let result: [ASTModelObject]

    do {
        result = try parser.parseModel()
    }
    catch {
        let context = parser.currentToken.map{ "'\($0.text)'" } ?? "(empty token)"
        fatalError("Compiler error: \(parser.textPosition) around \(context): \(error)")
    }

    return result

}

public final class Parser {
    var lexer: Lexer

    init(lexer: Lexer) {
        self.lexer = lexer

        // Advance one token if we are (supposedly) at the beginning. Nothing
        // should happen if we are at the end.
        if lexer.currentToken == nil {
            lexer.next()
        }
    }

    var textPosition: TextPosition { return lexer.position }
    var currentToken: Token? { return lexer.currentToken }

    func parseModel() throws -> [ASTModelObject] {
        let objects = try many(modelObject)

        guard lexer.atEnd else {
            throw CompilerError.unexpectedTokenType("expected model object")
        }
        return objects
    }

    @discardableResult
    func accept(_ satisfy: (Token) -> Bool) -> Token? {
        guard let token = lexer.currentToken else {
            return nil
        }

        if satisfy(token) {
            lexer.next()
            return token
        }
        else{
            return nil
        }
    }

    func expect<T>(_ fetch: () throws -> T?, error: CompilerError) throws -> T {
        guard let result = try fetch() else {
            throw error
        } 
        return result
    }

    func many<T>(_ fetch: () throws -> T?) throws -> [T] {
        var list: [T] = []

        while let item = try fetch() {
            list.append(item)
        }

        return list
    }

    // Atom Helpers
    // -----------------------------------------------------------------

    func _symbol() -> String? {
        return accept { $0.type == .symbol }.map { $0.text }
    }
    func _integer() -> Int? {
        // TODO: We assume here that the integer literals are Int convertible
        return accept { $0.type == .intLiteral }.map { Int($0.text)! }
    }
    func _text() -> String? {
        return accept { $0.type == .stringLiteral }.map { $0.text }
    }

    func _operator(_ op: String) -> Bool {
        return accept {
            $0.type == .operator && $0.text == op
        }.map { _ in true } ?? false
    }
    func keyword(_ keyword: String) -> Bool {
        return accept {
            $0.type == .symbol && $0.text.uppercased() == keyword
        }.map { _ in true } ?? false
    }


    // Model and Model Objects
    // -----------------------------------------------------------------

    // modelObject := define
    //                | unaryActuator
    //                | binaryActuator
    //                | structure
    //                | world
    //                | data

    func modelObject() throws -> ASTModelObject? {
        return try _define()
                ?? _unaryActuator()
                ?? _binaryActuator()
                ?? _world()
                ?? _struct()
                ?? _data()
    }


    // Rule:
    //
    // define := "DEF" symbol_type symbol_name
    //
    func _define() throws -> ASTModelObject? {
        guard keyword("DEF") else { return nil }

        guard let typeName = _symbol() else {
            throw CompilerError.symbolExpected("symbol type")
        }
        // TODO: Make better error reporting here, don't point context to the
        // symbol name
        guard let symbolType = SymbolType(name: typeName.lowercased()) else {
            throw CompilerError.badSymbolType(typeName)
        }
        guard let symbolName = _symbol() else {
            throw CompilerError.symbolExpected("defined symbol name")
        }

        return ASTModelObject.define(symbolType, symbolName)
    }

    // world := "WORLD" symbol {worldItem}
    //
    func _world() throws -> ASTModelObject? {
        guard keyword("WORLD") else { return nil }
        guard let name = _symbol() else {
            throw CompilerError.symbolExpected("world name")
        }

        let items = try many(_worldItem)

        return ASTModelObject.world(name, items)
    }

    // worldItem := integer (symbol | tagList)
    //
    func _worldItem() throws -> ASTWorldItem? {
        guard let count = _integer() else {
            return nil
        }
        
        if let symbol = _symbol() {
            return .quantifiedStructure(count, symbol)
        }
        else if let list = try _tagList() {
            return .quantifiedObject(count, list)
        }
        else {
            throw CompilerError.unexpectedTokenType("structure name or tag list expected")
        }
    }

    // struct := "STRUCT" symbol {structItem}
    func _struct() throws -> ASTModelObject? {
        guard keyword("STRUCT") else { return nil }
        guard let name = _symbol() else {
            throw CompilerError.symbolExpected("struct name")
        }

        let items = try many(_structItem)

        return .structure(name, items)
    }

    // data := "DATA" tagList text
    func _data() throws -> ASTModelObject? {
        guard keyword("DATA") else { return nil }
        guard let tags = try _tagList() else {
            throw CompilerError.tagListExpected
        }

        guard let text = _text() else {
            throw CompilerError.unexpectedTokenType("expected string")
        }

        return .data(tags, text)
    }

    // structItem := structObject | structBinding
    func _structItem() throws -> ASTStructItem? {
        return try _structObject() ?? _structBinding()
    }
    // structObject := "OBJ" symbol tagList
    func _structObject() throws -> ASTStructItem? {
        guard keyword("OBJ") else { return nil }
        guard let name = _symbol() else {
            throw CompilerError.symbolExpected("object name")
        }

        guard let tags = try _tagList() else {
            throw CompilerError.tagListExpected
        }

        return .object(name, tags)
    }

    // structBinding := "BIND" symbol ["." symbol] "TO" target
    func _structBinding() throws -> ASTStructItem? {
        guard keyword("BIND") else { return nil }
        guard let origin = try _qualifiedSymbol() else {
            throw CompilerError.symbolExpected("binding origin expected")
        }

        guard keyword("TO") else {
            throw CompilerError.expectedToken("keyword TO")
        }

        guard let target = _symbol() else {
            throw CompilerError.symbolExpected("binding target expected")
        }
        // TODO: Why not just .binding(origin, target)?
        return .binding(origin.qualifier!, origin.symbol, target)
    }
    


    // signal := "HALT"
    //           | "NOTIFY" tagList
    //           | "TRAP" tagList
    //
    func _signal() throws -> ASTSignal? {
        if keyword("HALT") {
            return ASTSignal.halt
        }
        else if keyword("NOTIFY") {
            guard let tags = try _tagList() else {
                throw CompilerError.tagListExpected
            }

            return ASTSignal.notify(tags)
        }
        else if keyword("TRAP") {
            guard let tags = try _tagList() else {
                throw CompilerError.tagListExpected
            }

            return ASTSignal.trap(tags)
        }
        else {
            return nil
        }
    }

    // Rule:
    //     unary_actuator := ACT name
    //                       WHERE selector {signal}
    //                       {unary_transition}
    func _unaryActuator() throws -> ASTModelObject? {
        guard keyword("ACT") else {
            return nil
        }

        guard let name = _symbol() else {
            throw CompilerError.symbolExpected("actuator name")
        }

        guard keyword("WHERE") else {
            throw CompilerError.expectedToken("keyword WHERE")

        }

        guard let selector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        let signals = try many(_signal)
        let transitions = try many(_unaryTransition)

        return ASTModelObject.unaryActuator(name, selector,
                                            transitions, signals)
    }

    // Rule:
    //     binary_actuator := REACT name
    //                        WHERE selector
    //                        ON selector
    //                        {signal}
    //                        {binary_transition}
    func _binaryActuator() throws -> ASTModelObject? {
        guard keyword("REACT") else {
            return nil
        }

        guard let name = _symbol() else {
            throw CompilerError.symbolExpected("actuator name")
        }

        guard keyword("WHERE") else {
            throw CompilerError.expectedToken("keyword WHERE")

        }

        guard let leftSelector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        guard keyword("ON") else {
            throw CompilerError.expectedToken("keyword ON")

        }

        guard let rightSelector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        let signals = try many(_signal)
        let transitions = try many(_binaryTransition)

        return ASTModelObject.binaryActuator(name, leftSelector, rightSelector,
                                            transitions, signals)
    }

    // binary_transition := binary_subject {modifier}
    func _binaryTransition() throws -> ASTTransition? {
        guard keyword("IN") else {
            return nil
        }

        guard let subject = try binarySubject() else {
            throw CompilerError.subjectExpected
        }
        let modifiers = try many(modifier)

        return ASTTransition(subject: subject, modifiers: modifiers)
    }

    // binary_subject := (LEFT | RIGHT) ["." slot]
    //
    func binarySubject() throws -> ASTSubject? {
        let side: String

        if keyword("LEFT") {
            side = "left"
        }
        else if keyword("RIGHT") {
            side = "right"
        }
        else  {
            return nil
        }

        if _operator(".") {
            guard let slot = _symbol() else {
                throw CompilerError.symbolExpected("subject slot")
            }

            return ASTSubject(side: side, slot: slot)
        }
        else {
            return ASTSubject(side: side, slot: nil)
        }
    }


    // unary_transition := IN unary_subject {modifier}
    //
    func _unaryTransition() throws -> ASTTransition? {
        guard keyword("IN") else {
            return nil
        }

        guard let subject = try _unarySubject() else {
            throw CompilerError.subjectExpected
        }

        let modifiers = try many(modifier)

        return ASTTransition(subject: subject, modifiers: modifiers)
    }

    func modifier() throws -> ASTModifier? {
        if keyword("BIND") {
            guard let subjectSlot = _symbol() else {
                throw CompilerError.symbolExpected("bind subject slot")
            }
            guard keyword("TO") else {
                throw CompilerError.expectedToken("TO")
            }
            guard let target = try _qualifiedSymbol() else {
                throw CompilerError.symbolExpected("qualified symbol of binding target")
            }
            return .bind(subjectSlot, target)
        }
        else if keyword("UNBIND") {
            guard let subjectSlot = _symbol() else {
                throw CompilerError.symbolExpected("unbind subject slot")
            }
            return .unbind(subjectSlot)
        }
        else if keyword("SET") {
            guard let tag = _symbol() else {
                throw CompilerError.symbolExpected("tag")
            }
            return .set(tag)
        }
        else if keyword("UNSET") {
            guard let tag = _symbol() else {
                throw CompilerError.symbolExpected("tag")
            }
            return .unset(tag)
        }
        else {
            return nil
        }
    }

    // unary_subject := THIS ["." symbol]
    //                  | symbol
    func _unarySubject() throws -> ASTSubject? {
        if keyword("THIS") {
            if _operator(".") {
                guard let slot = _symbol() else {
                    throw CompilerError.symbolExpected("slot")
                }
                return ASTSubject(side: "this", slot: slot)
            }
            else {
                return ASTSubject(side: "this", slot: nil)
            }
        }
        else {
            guard let slot = _symbol() else {
                return nil
            }
            return ASTSubject(side: "this", slot: slot)
        }
    }

    // selector := "(" {symbol_presence} ")"
    //             | "ALL"

    func _selector() throws -> ASTSelector? {
        if keyword("ALL") {
            return .all
        }

        guard _operator("(") else {
            return nil
        }

        let presences = try many(_symbolPresence)

        guard _operator(")") else {
            throw CompilerError.expectedToken("right parenthesis ')'")
        }

        return ASTSelector.match(presences)
    }

    // symbol_presence := [!] qualified_symbol
    //
    func _symbolPresence() throws -> ASTMatch? {
        let negate = _operator("!")
        let symbol = try _qualifiedSymbol()

        if symbol == nil {
            if negate {
                throw CompilerError.qualifiedSymbolExpected
            }
            else {
                return nil
            }
        }
        else {
            return ASTMatch(isPresent: !negate, symbol: symbol!)
        }
    }

    // qualified_symbol := symbol ["." symbol]
    //
    func _qualifiedSymbol() throws -> ASTQualifiedSymbol? {
        guard let left = _symbol() else {
            return nil
        }

        if _operator(".") {
            guard let right = _symbol() else {
                throw CompilerError.symbolExpected("symbol expected")
            }
            return ASTQualifiedSymbol(qualifier: left, symbol: right)
        }
        else {
            return ASTQualifiedSymbol(qualifier: nil, symbol: left)
        }

    }

    // Low Level Rules
    //
    // tagList := '(' {qualifiedSymbol} ')'
    //
    func _tagList() throws -> [Symbol]? {
        guard _operator("(") else {
            return nil
        }

        let tags: [String] = try many(_symbol)

        guard _operator(")") else {
            throw CompilerError.unexpectedTokenType("expected tag symbol or ')'")
        }

        return tags
    }


}
