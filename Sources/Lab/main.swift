import Foundation
import Linenoise
import Compiler


func usage() {
    print("""
          Sepro18 Interactive

          Usage: \(CommandLine.arguments[0]) [WORKSPACE] 
          """)
}

func main() {
    let args = CommandLine.arguments
    let workspacePath: String

    if args.count > 1 {
        workspacePath = args[1]
    }
    else {
        workspacePath = "."
    }

    let workspace = Workspace(path: workspacePath)
    let interpreter = CommandInterpreter()

    print("""
          Sepro18 Interpreter

          Type 'help' for help, 'exit' to quit the interpreter.

          """)

    while(true) {
        guard let line = linenoise("> ") else {
            // We got ^D
            break
        }

        let commandString: String = String(cString: line)

        interpreter.interpret(source: commandString)

        if interpreter.shouldStop {
            break
        }

        linenoiseHistoryAdd(commandString)
    }
    print("Bye!")

}

main()
