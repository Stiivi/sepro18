// TODO: This is preliminary implementation of the tool.
//
import Foundation
import Simulation
import Simulator
import Compiler
import Model


func usage() {
    print("""
          Usage: \(CommandLine.arguments[0]) [-o OUTPUT] MODEL STEPS

          Options:
            -o                Output directory. Default: ./out
            --dump-symbols    Dump symbol table
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
    let _ = iterator.next()
    
    while let arg = iterator.next() {
        switch arg {
        case       "--dump-symbols":
            // TODO: bool!
            options["dump_symbols"] = "true"
        case "-o", "--output":
            options["output"] = iterator.next()
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

func printSymbolTable(symbols: [String:SymbolType]) {
    print("Symbol Table:")
    symbols.sorted {
        rhs, lhs in
        lhs.key.lowercased() > rhs.key.lowercased()
    }
    .forEach {
        print(String(format: "    %16@ %@", $0.key, $0.value.rawValue)) 
    }
}

func main() {
    let args = parseArguments(args: CommandLine.arguments)
    let source: String
    let modelFile: String
    let compiler = Compiler()
    let outPath: String = args.options["output", default: "out"]
    let dumpSymbols: Bool = args.options["dump_symbols"] == "true"

    guard args.positional.count == 2 else {
        usage()
        return
    }

    guard let stepCount = Int(args.positional[1]) else {
        errorExit("Invalid number of steps '\(args.positional[1])'")
    }

    // Create output directories
    // -----------------------------------------------------------------------
    let fileManager = FileManager()
    do {
        try fileManager.createDirectory(atPath:outPath,
                                        withIntermediateDirectories: true)
    }
    catch {
        errorExit("Unable to create output directory '\(outPath)'")
    }


    // Load and Compile model
    // -----------------------------------------------------------------------
    modelFile = args.positional[0]

    print("Loading model from \(modelFile)...")

    do {
        source = try String(contentsOfFile: modelFile, encoding:String.Encoding.utf8)
    } catch {
        errorExit("Unable to read model '\(modelFile)'")
    }

    print("Compiling model...")

    compiler.compile(source: source)

    let model: Model = compiler.model

    print("Model compiled")
    print("    Symbol count    : \(model.symbols.count)")
    print("    Unary actuators : \(model.unaryActuators.count)")
    print("    Binary actuators: \(model.unaryActuators.count)")

    if dumpSymbols {
        printSymbolTable(symbols: model.symbols) 
    }


    print("Initializing simulation...")

    let container = Container()
    let simulation = SeproSimulation(model: compiler.model, container: container)
    let delegate = CLIDelegate(outputPath: outPath)
    let simulator = IterativeSimulator(simulation: simulation, delegate: delegate)


    // FIXME: Untie this initialization
    guard let mainWorld = compiler.model.worlds["main"] else {
        errorExit("No world with name 'main' found")
    }

    mainWorld.structs.forEach {
        qstruct in
        (0..<qstruct.count).forEach {
            _ in
            guard let structure = model.structs[qstruct.structName] else {
                fatalError("No structure '\(qstruct.structName)'")
            }
            container.create(structure: structure)
        }
    }

    simulator.run(steps: stepCount)

}

main()

