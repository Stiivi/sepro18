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
prefix func ^ (value: String) -> Parser<Token, String> {
    return keyword(value)
}

prefix func % (value: String) -> Parser<Token, Symbol> {
    return symbol(value)
}

infix operator ... : BindPrecedence
public func ... <T, A, B>(parser: Parser<T, A>, sep:Parser<T, B>) -> Parser<T, [A]> {
    return separated(parser, sep)
}


// Terminals
// =======================================================================

func token(_ type: TokenType, _ expected: String) -> Parser<Token, Token> {
    return satisfy(expected) { token in token.type == type }
}

func tokenValue(_ type: TokenType, _ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
            $0.type == type && $0.text == value
        }
}

func isKeyword(_ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
            $0.type == .symbol && $0.text.uppercased() == value
        }
}

let symbol  = { name    in token(.symbol, name)  => { Symbol(describing: $0.text) } }
let keyword = { keyword in isKeyword(keyword)  => { $0.text.uppercased() } }
let number  = { label   in token(.intLiteral, label) => { Int($0.text)! } }
let text    = { label   in token(.stringLiteral, label) => { $0.text } }
let op      = {            tokenValue(.operator, $0) }


// Model Objects
// =======================================================================


let symbol_type =
    ^"TAG" || ^"SLOT"

let define =
    ^"DEF" *> (symbol_type + %"name") => ASTModelObject.define

let tag_list =
    op("(") *> many(%"tag") <* op(")")


// ACTUATOR
//

let signal =
    ^"HALT" => { _ in ASTSignal.halt }
    || ^"NOTIFY" + tag_list => { ASTSignal.notify($0.1)}
    || ^"TRAP" + tag_list => { ASTSignal.trap($0.1)}

let qualified_symbol =
    %"symbol" + option(op(".") *> %"symbol") => { (left, right) in

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
    || ^"UNBIND" *> %"subject_slot"           => ASTModifier.unbind
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
    ((^"ACT" *> %"name") + (^"WHERE" *> selector))
    + (many(signal) + many(unary_transition))
        => { ASTModelObject.unaryActuator($0.0.0, $0.0.1, $0.1.1, $0.1.0) }


let binary_transition =
    (^"IN" *> binary_subject + many(modifier))
        => { ASTTransition(subject: $0.0, modifiers: $0.1) }


let binary_selector =
    (^"WHERE" *> selector) + (^"ON" *> selector)


let binary_actuator =
    ((^"REACT" *> %"name") + binary_selector)
    + (many(signal) + many(binary_transition))
        => { ASTModelObject.binaryActuator($0.0.0, $0.0.1.0, $0.0.1.1,
                                           $0.1.1, $0.1.0) }


let struct_object =
    (^"OBJ" *> %"name") + tag_list
        => { ASTStructItem.object($0.0, $0.1) }

let struct_binding_origin =
    %"origin" + (op(".") *> %"slot")
        => { ASTQualifiedSymbol(qualifier: $0.0, symbol: $0.1) }

let struct_binding =
    (^"BIND" *> struct_binding_origin) + (^"TO" *> %"target")
      => { ASTStructItem.binding($0.0.qualifier!, $0.0.symbol, $0.1) }

let struct_item =
    struct_object
    || struct_binding

let struct_ =
    (^"STRUCT" *> %"name") + some(struct_item)
        => { ASTModelObject.structure($0.0, $0.1)}

let quantified_object =
    number("count") + tag_list
        => { ASTWorldItem.quantifiedObject($0.0, $0.1) }

let quantified_struct =
    number("count") + %"struct name"
        => { ASTWorldItem.quantifiedStructure($0.0, $0.1) }

let world_item =
    quantified_struct
    || quantified_object


let world =
    (^"WORLD" *> %"name") + many(world_item)
        => { ASTModelObject.world($0.0, $0.1) }


let data =
    ^"DATA" *> (tag_list + text("data string"))
        => { ASTModelObject.data($0.0, $0.1) }

let model_object =
    define
    || unary_actuator
    || binary_actuator
    || struct_
    || world
    || data


let model =
    some(model_object)


func parse(source: String) -> [ASTModelObject] {
    let lexer = Lexer(source)
    let tokens = lexer.parse()

    let result = model.parse(tokens.stream())

    switch result {
    case .OK(let value, _):
        return value
    case let .Fail(error, token):
        fatalError("FATAL ERROR near \(token): \(error)")
    case let .Error(error, token):
        fatalError("ERROR near \(token): \(error)")
    }
}
