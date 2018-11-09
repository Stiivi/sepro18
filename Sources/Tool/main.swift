// TODO: This is preliminary implementation of the tool.
//
import Foundation


let SEPRO_VERSION = "0.1"


func usage() {
    print("""
          Sepro18 simulator runner v\(SEPRO_VERSION)

          Usage: \(CommandLine.arguments[0]) [options] MODEL STEPS

          Options:
            --dump-symbols    Dump symbol table.
            -o DIR            Output directory. Default: ./out
            -w WORLD          World name to initialize simlation. Default: main
          """)
}

struct ParsedArguments {
    let options: [String:String]
    let positional: [String]
}

func parseArguments(args: [String]) -> ParsedArguments {
    var iterator = args.makeIterator()
    var options: [String:String] = [:]
    var positional: [String] = []
    // Eat the command name
    _ = iterator.next()

    while let arg = iterator.next() {
        switch arg {
        case       "--dump-symbols":
            // TODO: bool!
            options["dump_symbols"] = "true"
        case "-o", "--output":
            options["output"] = iterator.next()
        case "-w", "--world":
            options["world"] = iterator.next()
        default:
            positional.append(arg)

        }
    }

    return ParsedArguments(options: options, positional: positional)
}

struct FileOutputStream: TextOutputStream {
    let handle: FileHandle

    func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            handle.write(data)
        }
        else {
            fatalError("Can't convert string to data: \(string)")
        }
    }
}

func errorExit(_ message: String) -> Never {
    var stderrStream = FileOutputStream(handle: FileHandle.standardError)
    print("ERROR: \(message)", to: &stderrStream)
    exit(1)
}

func printVersion() -> Never {
    print(SEPRO_VERSION)
    exit(0)
}

func main() {
    let args = parseArguments(args: CommandLine.arguments)
    let modelFile: String
    let outPath: String = args.options["output", default: "out"]
    let dumpSymbols: Bool = args.options["dump_symbols"] == "true"
    let worldName: String = args.options["world", default: "main"]

    guard args.positional.count == 2 else {
        usage()
        return
    }

    guard let stepCount = Int(args.positional[1]) else {
        errorExit("Invalid number of steps '\(args.positional[1])'")
    }

    // Load and Compile model
    // -----------------------------------------------------------------------
    modelFile = args.positional[0]


    let tool = Tool(modelPath: modelFile, outputPath: outPath)

    if dumpSymbols {
        tool.printSymbolTable()
    }

    // Initialize the simulator
    // -----------------------------------------------------------------------
    // FIXME: Untie this initialization
    guard tool.model.worlds[worldName] != nil else {
        errorExit("No world with name '\(worldName)' found")
    }
    tool.initializeWorld(worldName)
    tool.run(stepCount: stepCount)
}

main()
