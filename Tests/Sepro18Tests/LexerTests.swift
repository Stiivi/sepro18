import XCTest
@testable import Sepro18

class LexerTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testEmpty() {
        var lexer = Lexer("")
        var token = lexer.nextToken()

        XCTAssertEqual(token.kind, .empty)

        lexer = Lexer("  ")
        token = lexer.nextToken()

        XCTAssertEqual(token.kind, .empty)
    }

    func testNumber() {
        let lexer = Lexer("1234")
        let token = lexer.nextToken()

        XCTAssertEqual(token.kind, .intLiteral)
        XCTAssertEqual(token.text, "1234")
    }

    func assertError(_ token: Token, _ str: String) {
        switch token.kind {
		case .error(let message) where message.contains(str):
            break
        default:
            XCTFail("Token \(token) is not an error containing '\(str)'")
        }
    }

    func testInvalidNumber() {
        let lexer = Lexer("1234x")

        let token = lexer.nextToken()
        self.assertError(token, " in integer")
    }

    func testOperator() {
        var lexer = Lexer("*")

        var token = lexer.nextToken()
        XCTAssertEqual(token.kind, .operator)
        XCTAssertEqual(token.text, "*")
    }

    func testSymbol() {
        let lexer = Lexer("this_is_something")
        let token = lexer.nextToken()

        XCTAssertEqual(token.kind, .symbol)
        XCTAssertEqual(token.text, "this_is_something")
    }

    func testMultiple() {
        let lexer = Lexer("this that 10, 20, 30 ")
        var token: Token
        
        var expectation: [(TokenKind, String)] = [
            (.symbol, "this"),
            (.symbol, "that"),
            (.intLiteral, "10"),
            (.operator, ","),
            (.intLiteral, "20"),
            (.operator, ","),
            (.intLiteral, "30"),
        ]

        for (kind, text) in expectation {
            token = lexer.nextToken()
            XCTAssertEqual(token.kind, kind)
            XCTAssertEqual(token.text, text)
        }

        token = lexer.nextToken()
        XCTAssertEqual(token.kind, .empty)
    }
	func testString() {
		var lexer = Lexer("\"")
		var token = lexer.nextToken()

		assertError(token, "Unexpected end of input in a string")	

		lexer = Lexer("\"\"")
		token = lexer.nextToken()
		XCTAssertEqual(token.kind, .stringLiteral)
        XCTAssertEqual(token.text, "")

		lexer = Lexer("\"\\")
		token = lexer.nextToken()
		assertError(token, "Unexpected end of input in a string")	

		lexer = Lexer("\"\\\"")
		token = lexer.nextToken()
		assertError(token, "Unexpected end of input in a string")	
	}

	func testDocstring() {
		var lexer = Lexer("\"\"\"")
		var token = lexer.nextToken()

		assertError(token, "Unexpected end of input in a string")	

		lexer = Lexer("\"\"\"\"")
		token = lexer.nextToken()
		assertError(token, "Unexpected end of input in a string")	


		lexer = Lexer("\"\"\"\"\"")
		token = lexer.nextToken()

		assertError(token, "Unexpected end of input in a string")	

		lexer = Lexer("\"\"\"\"\"\"")
		token = lexer.nextToken()
		XCTAssertEqual(token.kind, .stringLiteral)
		XCTAssertEqual(token.text, "")


		lexer = Lexer("\"\"\"hello\"\"\"")
		token = lexer.nextToken()
		XCTAssertEqual(token.kind, .stringLiteral)
		XCTAssertEqual(token.text, "hello")

		lexer = Lexer("\"\"\"\"hello\\\"\"\"\"")
		token = lexer.nextToken()
        print("=== token: \(token)")
		XCTAssertEqual(token.kind, .stringLiteral)
		XCTAssertEqual(token.text, "\"hello\\\"")
	}
}


