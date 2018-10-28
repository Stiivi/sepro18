import struct Model.Symbol
import ParserCombinator

// Required by ParserCombinator recognizer 'satisfy()'r
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

// Recognizers
// =======================================================================

/// Recognizer for a token of a specific type
func token(_ type: TokenType, _ expected: String) -> Parser<Token, Token> {
    return satisfy(expected) { token in token.type == type }
}

/// Recognizer of a token with specific type and value
func tokenValue(_ type: TokenType, _ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
            $0.type == type && $0.text == value
        }
}

/// Recognizer for case insensitive keywords
func isKeyword(_ value: String) -> Parser<Token, Token> {
    return satisfy(value) {
            $0.type == .symbol && $0.text.uppercased() == value
        }
}

// Note: Unused, but we keep it around if we would like to introduce a list of
// separated tokens
infix operator ... : BindPrecedence
public func ... <T, A, B>(parser: Parser<T, A>, sep:Parser<T, B>) -> Parser<T, [A]> {
    return separated(parser, sep)
}


