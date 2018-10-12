// TODO: This is preliminary implementation of the tool.
//
import Foundation
import Simulation
import Simulator
import Compiler
import Model


func usage() {
    print("Usage: \(CommandLine.arguments[0]) MODEL STEPS")
}


func main() {
    let args = CommandLine.arguments
    let source: String
    let modelFile: String
    let stepCount: Int
    let compiler = Compiler()
    let outPath = "out"

    if args.count < 2 {
        usage()
        return
    }
    else {
        modelFile = args[1]
        stepCount = Int(args[2])!
    }

    print("Loading model from \(modelFile)...")

    do {
        source = try String(contentsOfFile: modelFile, encoding:String.Encoding.utf8)
    } catch {
        print("Error: Unable to read model.")
		exit(1)
    }

    print("Compiling model...")

    compiler.compile(source: source)

    let model: Model = compiler.model

    print("Model compiled: \(model.unaryActuators.count) UN, \(model.binaryActuators.count) BIN")

    let container = Container()
    let simulation = SeproSimulation(model: compiler.model, container: container)
    let delegate = CLIDelegate(outputPath: outPath)
    let simulator = IterativeSimulator(simulation: simulation, delegate: delegate)


    // FIXME: Untie this initialization
    guard let mainWorld = compiler.model.worlds["main"] else {
        print("Error: no world with name 'main' found")
        exit(1)
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

