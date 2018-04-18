import ParserCombinator

// Terminals
// =======================================================================
func token(_ kind: TokenKind, _ expected: String) -> Parser<Token, Token> {
    return satisfy(expected) { token in token.kind == kind }
}

func tokenValue(_ kind: TokenKind, _ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
        token in
            token.kind == kind && token.text == value
        }
}

func isKeyword(_ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
        token in
            token.kind == .symbol && token.text.uppercased() == value
        }
}

let symbol  = { name  in token(.symbol, name)  => { t in Symbol(describing:t.text) } }
let keyword = { kw    in isKeyword(kw)  => { t in t.text.uppercased() } }
let number  = { label in token(.intLiteral, label) => { t in Int(t.text)! } }
let text    = { label in token(.stringLiteral, label) => { t in t.text } }
let op      = { o     in tokenValue(.operator, o) }

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

//

let symbol_type =
    ^"TAG" || ^"SLOT"

let define =
    ^"DEF" *> (symbol_type + %"name") => ASTModelObject.define


// ACTUATOR
//

let qualified_symbol =
    option(%"indirect" <* op(".")) + %"symbol"
        => { ASTQualifiedSymbol(qualifier: $0.0, symbol: $0.1) }


let symbol_presence =
    optionFlag(op("!")) + qualified_symbol
        => { ASTMatch(isPresent: $0.0, symbol: $0.1) }


let selector =
    op("(") *> many(symbol_presence) <* op(")") => ASTSelector.match
    || ^"ALL" => { _ in ASTSelector.all }


let trans =
    (^"BIND" *> qualified_symbol)
        + (^"TO" *> qualified_symbol) => ASTTransition.bind
    || ^"UNBIND" *> qualified_symbol  => ASTTransition.unbind
    || ^"SET" *> %"tag"               => ASTTransition.set
    || ^"UNSET" *> %"tag"             => ASTTransition.unset


let modifier =
    (^"IN" *> qualified_symbol) + many(trans)
        => { ASTModifier(target: $0.0, transitions: $0.1) }


// FIXME: Clean-up this rule a bit to get rid of those unclear tuple references
let actuator =
    ((^"ACT" *> %"name")
    + ((^"WHERE" *> selector) + option(^"ON" *> selector)))
    + many(modifier)
    => { ASTModelObject.actuator($0.0.0, $0.0.1.0, $0.0.1.1, $0.1) }


let tag_list =
    op("(") *> many(%"tag") <* op(")")

    
let struct_item =
    number("count") + tag_list => { ASTStructItem(count: $0.0, tags: $0.1) }


let structure =
    (^"STRUCT" *> %"name") + many(struct_item)
        => { ASTModelObject.structure($0.0, $0.1) }


let model_object =
    define
    || actuator
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

