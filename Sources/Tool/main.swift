import Foundation
import Logging
import Commander
import Shell
import Linenoise

LoggingSystem.bootstrap(StreamLogHandler.standardError)
let logger = Logger(label: "sepro.main")

public let SEPRO_VERSION = "0.1"


let group = Group {
    // Run model
    // =========
    $0.command("run",
        Option("output", default: ".", flag:"o"),
        Option("world", default: "main", flag: "w"),
        Argument<String>("model"),
        Argument<Int>("steps")
        ) { (outputURL, worldName, modelPath, steps) in
        let shell = Shell(outputURL: outputURL)

        shell.importModel(path: modelPath)
        shell.runSimulation(steps: steps)
    }

    // Symbols
    // =======
    $0.command("symbols",
        Argument<String>("model",
        description: "Dump symbol table of a model")

        ) { (modelPath) in
        let shell = Shell()

        shell.importModel(path: modelPath)
        shell.printSymbolTable()
    }

    // Version
    // =======
    $0.command("version") {
        print(SEPRO_VERSION)
    }

    // Shell
    // =====
    $0.command("shell",
        Option("output", default: ".", flag:"o")
        ) { (outputURL) in
        let shell = Shell(outputURL: outputURL)

        print("""
              Sepro18 Interpreter

              Type 'help' for help, 'exit' to quit the interpreter.

              """)

        while true {
            guard let line = linenoise("> ") else {
                // We got ^D
                break
            }

            let commandString: String = String(cString: line)

            shell.interpret(source: commandString)

            if shell.shouldStop {
                break
            }

            linenoiseHistoryAdd(commandString)
        }
        print("Bye!")

    }
}

group.run()
