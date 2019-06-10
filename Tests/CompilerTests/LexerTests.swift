import XCTest
@testable import Compiler

class LexerTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testEmptyString() {
        let lexer = Lexer("")

        XCTAssertNil(lexer.next())
    }

    func testWhitespacesOnly() {
        let lexer = Lexer("  ")

        XCTAssertNil(lexer.next())
    }

    func testNumber() {
        let lexer = Lexer("1234")
        guard let token = lexer.next() else {
            XCTFail("Token is nil")
            return
        }

        XCTAssertEqual(token.type, .intLiteral)
        XCTAssertEqual(token.text, "1234")
    }

    func testInvalidNumber() {
        let lexer = Lexer("1234x")

        guard let token = lexer.next() else {
            XCTFail("Token is nil")
            return
        }

        XCTAssertEqual(token.type, .error(.invalidCharacterInInt))
    }

    func testOperator() {
        let lexer = Lexer("!")

        guard let token = lexer.next() else {
            XCTFail("Token is nil")
            return
        }

        XCTAssertEqual(token.type, .operator)
        XCTAssertEqual(token.text, "!")
    }

    func testSymbol() {
        let lexer = Lexer("this_is_something")
        guard let token = lexer.next() else {
            XCTFail("Token is nil")
            return
        }

        XCTAssertEqual(token.type, .symbol)
        XCTAssertEqual(token.text, "this_is_something")
    }

    func testMultiple() {
        let lexer = Lexer(" this !that 10 20 30 ")

        let expectation: [(TokenType, String)] = [
            (.symbol, "this"),
            (.operator, "!"),
            (.symbol, "that"),
            (.intLiteral, "10"),
            (.intLiteral, "20"),
            (.intLiteral, "30")
        ]

        for (type, text) in expectation {
            guard let token = lexer.next() else {
                XCTFail("Token is nil")
                break
            }

            XCTAssertEqual(token.type, type)
            XCTAssertEqual(token.text, text)
        }

        XCTAssertNil(lexer.next())
    }

    func testAtEnd() {
        var lexer = Lexer("")

        // We have empty string - we are at end and we don't have a token
        XCTAssertTrue(lexer.atEnd)
        XCTAssertNil(lexer.currentToken)

        // We are at the beginning - we are not at end, but we did not read
        // anything yet
        lexer = Lexer("help")
        XCTAssertFalse(lexer.atEnd)
        XCTAssertNil(lexer.currentToken)

        // We are at the beginning - we are not at end, but we did not read
        // anything yet
        lexer = Lexer("help")
        lexer.next()
        XCTAssertTrue(lexer.atEnd)
        XCTAssertNotNil(lexer.currentToken)

        lexer.next()
        XCTAssertTrue(lexer.atEnd)
        XCTAssertNil(lexer.currentToken)
    }

	func testString() {
		var lexer = Lexer("\"")
        var token: Token?
        token = lexer.next()

        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))

		lexer = Lexer("\"\"")
		token = lexer.next()
		XCTAssertEqual(token!.type, .stringLiteral)
        XCTAssertEqual(token!.text, "")

		lexer = Lexer("\"\\")
		token = lexer.next()
        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))

		lexer = Lexer("\"\\\"")
		token = lexer.next()
        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))
    }

	func testDocstring() {
		var lexer = Lexer("\"\"\"")
		var token: Token?

        token = lexer.next()

        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))

		lexer = Lexer("\"\"\"\"")
		token = lexer.next()
        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))


		lexer = Lexer("\"\"\"\"\"")
		token = lexer.next()

        XCTAssertEqual(token!.type, .error(.unexpectedEndOfString))

		lexer = Lexer("\"\"\"\"\"\"")
		token = lexer.next()
		XCTAssertEqual(token!.type, .stringLiteral)
		XCTAssertEqual(token!.text, "")


		lexer = Lexer("\"\"\"hello\"\"\"")
		token = lexer.next()
		XCTAssertEqual(token!.type, .stringLiteral)
		XCTAssertEqual(token!.text, "hello")
	}

    func testEscapeStringCharacter() {
		var lexer = Lexer("\"\\a\"")
        var token: Token?
        token = lexer.next()
		XCTAssertEqual(token!.text, "\\a")

		lexer = Lexer("\"\"\"\\a\"\"\"")
        token = lexer.next()
		XCTAssertEqual(token!.text, "\\a")

        // Test escape quote
		lexer = Lexer("\"\\\"\"")
        token = lexer.next()
		XCTAssertEqual(token!.text, "\\\"")

        // Test escape quote in a triple-quoted string
		lexer = Lexer("\"\"\"\\\"\"\"\"")
        token = lexer.next()
		XCTAssertEqual(token!.text, "\\\"")

        // FIXME: Parsing a quote in a triple-quote string is failing.
		/*
        let text = "\"\"\"a\"b\"\"\""
		lexer = Lexer(text)
		token = lexer.next()
		XCTAssertEqual(token!.type, .stringLiteral)
		XCTAssertEqual(token!.text, "a\"b")
        */
    }
}
