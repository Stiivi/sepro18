// FIXME: Model import should not be necessary for the parser
import Model

// TODO: Add human readable descriptions for the errors. #good-first
public enum ParserError: Error, CustomStringConvertible {
    case unexpectedToken
    case unexpectedTokenType(String)
    case symbolExpected(String)
    case keywordExpected(String)
    case tagListExpected(String)

    case selectorExpected
    case subjectExpected
    case qualifiedSymbolExpected

    case badSymbolType(String)

    public var description: String {
        switch self {
        case .unexpectedToken:
            return "Unexpected token"
        case .unexpectedTokenType(let type):
            return "Unexpected token type: \(type)"
        case .symbolExpected(let sym):
            return "Expected symbol \(sym)"
        case .keywordExpected(let keyword):
            return "Expected keyword \(keyword)"
        case .tagListExpected(let label):
            return "Expected list of tags - \(label)"
        case .selectorExpected:
            return "Selector expected"
        case .subjectExpected:
            return "Subject expected"
        case .qualifiedSymbolExpected:
            return "Qualified symbol expected"
        case .badSymbolType(let type):
            return "Bad symbol type: \(type)"
        }
    }

}

/// Parser for Sepro source code. Takes a textual input (a string) and
/// generates AST nodes.
///
public final class Parser {
    var lexer: Lexer

    /// Create a parser for model source `source`.
    ///
    // FIXME: This is public temporarily only for commands until we have a
    // better way of handling compilation of them.
    public convenience init(source: String) {
        self.init(lexer: Lexer(source))
    }

    /// Create a parser f/rom already initialized lexer.
    ///
    init(lexer: Lexer) {
        self.lexer = lexer

        // Advance one token if we are (supposedly) at the beginning. Nothing
        // should happen if we are at the end.
        if lexer.currentToken == nil {
            lexer.next()
        }
    }

    // FIXME: remove public, interpreter is using this
    public var sourceLocation: SourceLocation { return lexer.location }
    // FIXME: remove public, interpreter is using this
    public var currentToken: Token? { return lexer.currentToken }

    // Basic parser methods
    // -----------------------------------------------------------------

    /// Accept a token that satisfies condition `satisfy`. If the token
    /// satisfies the condition, then lexer is advanced and the token is
    /// returned. Otherwise `nil` is returned.
    ///
    @discardableResult
    public func accept(_ satisfy: (Token) -> Bool) -> Token? {
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

    /// Accepts zero or multiple rules `fetch` and returns a list of accepted
    /// objects. Returns an empty list when no objects are parsed.
    ///
    public func many<T>(_ fetch: () throws -> T?) throws -> [T] {
        var list: [T] = []

        while let item = try fetch() {
            list.append(item)
        }

        return list
    }

    // Atom Helpers
    // -----------------------------------------------------------------

    /// Accepts a symbol token.
    ///
    public func symbol() -> String? {
        return accept { $0.type == .symbol }.map { $0.text }
    }

    /// Accept an integer token.
    public func integer() -> Int? {
        // TODO: We assume here that the integer literals are Int convertible
        return accept { $0.type == .intLiteral }.map { Int($0.text)! }
    }

    /// Accept a string token.
    ///
    public func string() -> String? {
        return accept { $0.type == .stringLiteral }.map { $0.text }
    }

    /// Accept an operator.
    ///
    public func oper(_ op: String) -> Bool {
        return accept {
            $0.type == .operator && $0.text == op
        }.map { _ in true } ?? false
    }

    /// Accept a case-insensitive keyword.
    ///
    public func keyword(_ keyword: String) -> Bool {
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
    public func tagList() throws -> [String]? {
        guard oper("(") else {
            return nil
        }

        let tags: [String] = try many(symbol)

        guard oper(")") else {
            throw ParserError.unexpectedTokenType("expected tag symbol or ')'")
        }

        return tags
    }

    /// Expect a symbol. If the expected token is not a symbol then
    /// `symbolExpected` error is thrown with a `label` of the symbol which
    /// should provide more information to the user..
    ///
    public func expect(symbol label: String) throws -> String {
        guard let symbol = symbol() else {
            throw ParserError.symbolExpected(label)
        }
        return symbol
    }
    /// Expects a keyword. If the keyword is not present then `keywordExpected`
    /// exception is raised with the expected keyword as an argument.
    ///
    public func expect(keyword: String) throws {
        guard self.keyword(keyword) else {
            throw ParserError.keywordExpected(keyword)
        }
    }

    /// Expects a tag list. If the tag list is not present then
    /// `tagListExpected` exception is raised with the expected tag list label
    /// as an argument.
    ///
    public func expect(tagList label: String) throws -> [String] {
        guard let list = try tagList() else {
            throw ParserError.tagListExpected(label)
        }
        return list
    }

    /// Expects end of stream.
    public func expectEnd() throws {
        // Do we have something parsed but not yet recognized?
        if !lexer.atEnd || lexer.currentToken != nil {
            throw ParserError.unexpectedToken
        }
    }

    // Model and Model Objects
    // -----------------------------------------------------------------

    /// Parses model and returs list of model objects. Expects end of source
    /// stream after last model object.
    ///
    func parseModel() throws -> [ASTModelObject] {
        let objects = try many(modelObject)

        guard lexer.atEnd else {
            throw ParserError.unexpectedTokenType("expected model object")
        }
        return objects
    }

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
            throw ParserError.badSymbolType(typeName)
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
            throw ParserError.unexpectedTokenType("structure name or tag list expected")
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
            throw ParserError.unexpectedTokenType("expected string")
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
            throw ParserError.symbolExpected("binding origin expected")
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
            throw ParserError.selectorExpected
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
            throw ParserError.selectorExpected
        }

        try expect(keyword: "ON")

        guard let rightSelector = try _selector() else {
            throw ParserError.selectorExpected
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
            throw ParserError.subjectExpected
        }
        let modifiers = try many(modifier)

        let t = ASTTransition(subject: subject, modifiers: modifiers)
        return t
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
        else if keyword("THIS") {
            throw ParserError.keywordExpected("Reference to THIS can not be used in binary actuator")
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
            throw ParserError.subjectExpected
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
            throw ParserError.symbolExpected("qualified symbol of binding target")
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
            throw ParserError.unexpectedTokenType("expected right parenthesis ')'")
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
                throw ParserError.qualifiedSymbolExpected
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
