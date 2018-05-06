// Sepro18 grammar
//

import Model
import ParserCombinator

// FIXME: This is required for ParserCombinator, which needs to be rethinked

extension Token: EmptyCheckable {
    public static var emptyValue: Token {
        return Token(.empty, text: "", position: TextPosition())
    }
    public var isEmpty: Bool { return type == .empty }
}

// Convenience grammar operators
// =======================================================================

prefix operator ^
prefix func ^(value: String) -> Parser<Token, String>{
    return keyword(value)
}

prefix func %(value: String) -> Parser<Token, Symbol>{
    return symbol(value)
}

infix operator ... : BindPrecedence
public func ...<T, A, B>(p: Parser<T,A>, sep:Parser<T,B>) -> Parser<T,[A]> {
    return separated(p, sep)
}


// Terminals
// =======================================================================

func token(_ type: TokenType, _ expected: String) -> Parser<Token, Token> {
    return satisfy(expected) { token in token.type == type }
}

func tokenValue(_ type: TokenType, _ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
        token in
            token.type == type && token.text == value
        }
}

func isKeyword(_ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
        token in
            token.type == .symbol && token.text.uppercased() == value
        }
}

let symbol  = { name  in token(.symbol, name)  => { t in Symbol(describing:t.text) } }
let keyword = { kw    in isKeyword(kw)  => { t in t.text.uppercased() } }
let number  = { label in token(.intLiteral, label) => { t in Int(t.text)! } }
let text    = { label in token(.stringLiteral, label) => { t in t.text } }
let op      = { o     in tokenValue(.operator, o) }


// Model Objects
// =======================================================================


let symbol_type =
    ^"TAG" || ^"SLOT"

let define =
    ^"DEF" *> (symbol_type + %"name") => ASTModelObject.define


// ACTUATOR
//

let qualified_symbol =
    %"symbol" + option(op(".") *> %"symbol") =>
        {
            (left, right) in

            ASTQualifiedSymbol(
                // If there is left.right, then qualifier is the left side,
                // otherwise we don't have the qualifier.
                qualifier: right.map { _ in left },
                // If there is left.right, then the symbol is the right side,
                // otherwise the left side (without dot) is the
                // symbol
                symbol: right.map { $0 } ?? left
            )
        }


let symbol_presence =
    optionFlag(op("!")) + qualified_symbol
        => { ASTMatch(isPresent: !$0.0, symbol: $0.1) }


let selector =
    op("(") *> many(symbol_presence) <* op(")") => ASTSelector.match
    || ^"ALL" => { _ in ASTSelector.all }


let modifier =
    (^"BIND" *> %"subject_slot")
        + (^"TO" *> qualified_symbol) => ASTModifier.bind
    || ^"UNBIND" *> ^"subject_slot"           => ASTModifier.unbind
    || ^"SET" *> %"tag"               => ASTModifier.set
    || ^"UNSET" *> %"tag"             => ASTModifier.unset


let unary_subject =
    ^"THIS" + option(op(".") *> %"slot") => { ASTSubject(side: $0.0, slot: $0.1) }
    || ^"slot" => { ASTSubject(side: "this", slot: $0) }


let binary_subject =
    (^"LEFT" || ^"RIGHT") + option(op(".") *> %"slot")
        => { ASTSubject(side: $0.0, slot: $0.1) }

let unary_transition =
    (^"IN" *> unary_subject + many(modifier))
        => { ASTTransition(subject: $0.0, modifiers: $0.1) }

let unary_actuator =
    ((^"ACT" *> %"name") + (^"WHERE" *> selector)) + many(unary_transition)
        => { ASTModelObject.unaryActuator($0.0.0, $0.0.1, $0.1) }


let binary_transition =
    (^"IN" *> binary_subject + many(modifier))
        => { ASTTransition(subject: $0.0, modifiers: $0.1) }


let binary_actuator =
    ((^"REACT" *> %"name") + (^"WHERE" *> selector))
    + ((^"ON" *> selector) + many(binary_transition))
        => { ASTModelObject.binaryActuator($0.0.0, $0.0.1, $0.1.0, $0.1.1) }

let tag_list =
    op("(") *> many(%"tag") <* op(")")

    
let struct_item =
    number("count") + tag_list => { ASTStructItem(count: $0.0, tags: $0.1) }


let structure =
    (^"STRUCT" *> %"name") + many(struct_item)
        => { ASTModelObject.structure($0.0, $0.1) }


let model_object =
    define
    || unary_actuator
    || binary_actuator
    || structure


let model =
    some(model_object)


func parse(source: String) -> [ASTModelObject] {
    let lexer = Lexer(source)
    let tokens = lexer.parse()

    let result = model.parse(tokens.stream())

    switch(result) {
    case .OK(let value, _):
        return value
    case let .Fail(error, token):
        fatalError("FATAL ERROR near \(token): \(error)")
    case let .Error(error, token):
        fatalError("ERROR near \(token): \(error)")
    }
}

