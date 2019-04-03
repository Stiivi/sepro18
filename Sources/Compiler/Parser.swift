// FIXME: Model import should not be necessary for the parser
import Model

public enum CompilerError: Error {
    case unexpectedTokenType(String)
    case symbolExpected(String)
    case keywordExpected(String)
    case tagListExpected(String)

    case selectorExpected
    case subjectExpected
    case qualifiedSymbolExpected

    case badSymbolType(String)
}

public final class Parser {
    var lexer: Lexer

    convenience init(source: String) {
        self.init(lexer: Lexer(source))
    }

    init(lexer: Lexer) {
        self.lexer = lexer

        // Advance one token if we are (supposedly) at the beginning. Nothing
        // should happen if we are at the end.
        if lexer.currentToken == nil {
            lexer.next()
        }
    }

    var sourceLocation: SourceLocation { return lexer.location }
    var currentToken: Token? { return lexer.currentToken }

    func parseModel() throws -> [ASTModelObject] {
        let objects = try many(modelObject)

        guard lexer.atEnd else {
            throw CompilerError.unexpectedTokenType("expected model object")
        }
        return objects
    }

    // Basic parser methods
    // -----------------------------------------------------------------

    @discardableResult
    func accept(_ satisfy: (Token) -> Bool) -> Token? {
        guard let token = lexer.currentToken else {
            return nil
        }

        if satisfy(token) {
            lexer.next()
            return token
        }
        else {
            return nil
        }
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

    func symbol() -> String? {
        return accept { $0.type == .symbol }.map { $0.text }
    }

    /// Accept an integer.
    func integer() -> Int? {
        // TODO: We assume here that the integer literals are Int convertible
        return accept { $0.type == .intLiteral }.map { Int($0.text)! }
    }

    /// Accept a string.
    ///
    func string() -> String? {
        return accept { $0.type == .stringLiteral }.map { $0.text }
    }

    /// Accept an operator.
    ///
    func oper(_ op: String) -> Bool {
        return accept {
            $0.type == .operator && $0.text == op
        }.map { _ in true } ?? false
    }

    /// Accept a case-insensitive keyword.
    ///
    func keyword(_ keyword: String) -> Bool {
        return accept {
            $0.type == .symbol && $0.text.uppercased() == keyword
        }.map { _ in true } ?? false
    }

    // Low Level Rules
    //
    /// Accept a parenthesis enclosed tag list.
    ///
    // tagList := '(' {qualifiedSymbol} ')'
    //
    func tagList() throws -> [String]? {
        guard oper("(") else {
            return nil
        }

        let tags: [String] = try many(symbol)

        guard oper(")") else {
            throw CompilerError.unexpectedTokenType("expected tag symbol or ')'")
        }

        return tags
    }

    /// Expect a symbol. If the expected token is not a symbol then
    /// `symbolExpected` error is thrown with a `label` of the symbol which
    /// should provide more information to the user..
    ///
    func expect(symbol label: String) throws -> String {
        guard let symbol = symbol() else {
            throw CompilerError.symbolExpected(label)
        }
        return symbol
    }
    func expect(keyword: String) throws {
        guard self.keyword(keyword) else {
            throw CompilerError.keywordExpected(keyword)
        }
    }
    func expect(tagList label: String) throws -> [String] {
        guard let list = try tagList() else {
            throw CompilerError.tagListExpected(label)
        }
        return list
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

        let typeName = try expect(symbol: "symbol type")

        // TODO: Make better error reporting here, don't point context to the
        // symbol name
        guard let symbolType = SymbolType(name: typeName.lowercased()) else {
            throw CompilerError.badSymbolType(typeName)
        }
        let symbolName = try expect(symbol: "symbol name")

        return ASTModelObject.define(symbolType, symbolName)
    }

    // world := "WORLD" symbol {worldItem}
    //
    func _world() throws -> ASTModelObject? {
        guard keyword("WORLD") else { return nil }

        let name = try expect(symbol: "world name")
        let items = try many(_worldItem)

        return ASTModelObject.world(name, items)
    }

    // worldItem := integer (symbol | tagList)
    //
    func _worldItem() throws -> ASTWorldItem? {
        guard let count = integer() else {
            return nil
        }

        if let structName = symbol() {
            return .quantifiedStructure(count, structName)
        }
        else if let list = try tagList() {
            return .quantifiedObject(count, list)
        }
        else {
            throw CompilerError.unexpectedTokenType("structure name or tag list expected")
        }
    }

    // struct := "STRUCT" symbol {structItem}
    func _struct() throws -> ASTModelObject? {
        guard keyword("STRUCT") else { return nil }

        let name = try expect(symbol: "structure name")
        let items = try many(_structItem)

        return .structure(name, items)
    }

    // data := "DATA" tagList text
    func _data() throws -> ASTModelObject? {
        guard keyword("DATA") else { return nil }

        let tags = try expect(tagList: "data tags")

        guard let text = string() else {
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

        let name = try expect(symbol: "object name")
        let tags = try expect(tagList: "object tags")

        return .object(name, tags)
    }

    // structBinding := "BIND" symbol ["." symbol] "TO" target
    func _structBinding() throws -> ASTStructItem? {
        guard keyword("BIND") else { return nil }

        guard let origin = try _qualifiedSymbol() else {
            throw CompilerError.symbolExpected("binding origin expected")
        }

        try expect(keyword: "TO")

        let target = try expect(symbol: "binding target")

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
            let tags = try expect(tagList: "notification tags")

            return ASTSignal.notify(tags)
        }
        else if keyword("TRAP") {
            let tags = try expect(tagList: "trap tags")

            return ASTSignal.trap(tags)
        }
        else {
            return nil
        }
    }

    // Rule:
    //     unaryActuator := ACT name
    //                      WHERE selector {signal}
    //                      {unaryTransition}
    func _unaryActuator() throws -> ASTModelObject? {
        guard keyword("ACT") else {
            return nil
        }

        let name = try expect(symbol: "actuator name")

        try expect(keyword: "WHERE")

        guard let selector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        let signals = try many(_signal)
        let transitions = try many(_unaryTransition)

        return ASTModelObject.unaryActuator(name, selector,
                                            transitions, signals)
    }

    // Rule:
    //     binaryActuator := REACT name
    //                        WHERE selector
    //                        ON selector
    //                        {signal}
    //                        {binaryTransition}
    func _binaryActuator() throws -> ASTModelObject? {
        guard keyword("REACT") else { return nil }

        let name = try expect(symbol: "actuator name")

        try expect(keyword: "WHERE")

        guard let leftSelector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        try expect(keyword: "ON")

        guard let rightSelector = try _selector() else {
            throw CompilerError.selectorExpected
        }

        let signals = try many(_signal)
        let transitions = try many(_binaryTransition)
        if transitions.isEmpty{
        }

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
        let side: ASTSubject.Side

        // FIXME: Parse a qualified symbol here
        if keyword("LEFT") {
            side = .left
        }
        else if keyword("RIGHT") {
            side = .right
        }
        else {
            return nil
        }

        if oper(".") {
            let slot = try expect(symbol: "subject slot")

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

    // modifier := bindModifier
    //             | unbindModifier
    //             | setModifier
    //             | unsetModifier
    //
    func modifier() throws -> ASTModifier? {
        return try bindModifier()
                    ?? unbindModifier()
                    ?? setModifier()
                    ?? unsetModifier()
    }

    // bindModifier := "BIND" symbol "TO" qualifiedSymbol
    //
    func bindModifier() throws -> ASTModifier? {
        guard keyword("BIND") else { return nil }

        let subjectSlot = try expect(symbol: "bind subject slot")

        try expect(keyword: "TO")

        guard let target = try _qualifiedSymbol() else {
            throw CompilerError.symbolExpected("qualified symbol of binding target")
        }

        return .bind(subjectSlot, target)
    }

    // unbindModifier := "UNBIND" symbol
    //
    func unbindModifier() throws -> ASTModifier? {
        guard keyword("UNBIND") else { return nil }

        let subjectSlot = try expect(symbol: "unbind subject slot")

        return .unbind(subjectSlot)
    }

    // setModifier := "SET" symbol
    //
    func setModifier() throws -> ASTModifier? {
        guard keyword("SET") else { return nil }

        let tag = try expect(symbol: "tag")

        return .set(tag)
    }

    // unsetModifier := "UNSET" symbol
    //
    func unsetModifier() throws -> ASTModifier? {
        guard keyword("UNSET") else { return nil }

        let tag = try expect(symbol: "tag")

        return .unset(tag)
    }

    // unary_subject := THIS ["." symbol]
    //                  | symbol
    func _unarySubject() throws -> ASTSubject? {
        if keyword("THIS") {
            if oper(".") {
                let slot = try expect(symbol: "slot")
                return ASTSubject(side: .this, slot: slot)
            }
            else {
                return ASTSubject(side: .this, slot: nil)
            }
        }
        else {
            guard let slot = symbol() else {
                return nil
            }
            return ASTSubject(side: .this, slot: slot)
        }
    }

    // selector := "(" {symbol_presence} ")"
    //             | "ALL"

    func _selector() throws -> ASTSelector? {
        if keyword("ALL") {
            return .all
        }

        guard oper("(") else {
            return nil
        }

        let presences = try many(symbolPresence)

        guard oper(")") else {
            throw CompilerError.unexpectedTokenType("expected right parenthesis ')'")
        }

        return ASTSelector.match(presences)
    }

    // symbol_presence := [!] qualifiedSymbol
    //
    func symbolPresence() throws -> ASTMatch? {
        let negate = oper("!")
        let qualSymbol = try _qualifiedSymbol()

        if let qualSymbol = qualSymbol {
            return ASTMatch(isPresent: !negate, symbol: qualSymbol)
        }
        else {
            if negate {
                throw CompilerError.qualifiedSymbolExpected
            }
            else {
                return nil
            }
        }
    }

    // qualifiedSymbol := symbol ["." symbol]
    //
    func _qualifiedSymbol() throws -> ASTQualifiedSymbol? {
        guard let left = symbol() else {
            return nil
        }

        if oper(".") {
            let right = try expect(symbol: "qualified symbol")
            return ASTQualifiedSymbol(qualifier: left, symbol: right)
        }
        else {
            return ASTQualifiedSymbol(qualifier: nil, symbol: left)
        }
    }

}
