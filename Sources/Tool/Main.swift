// TODO: This is preliminary implementation of the tool.
//
import Foundation
import Simulator
import Compiler
import Model


let filename = CommandLine.arguments[1]

let url = NSURL.fileURL(withPath: filename)
let compiler = Compiler()


func usage() {
    print("Usage: \(CommandLine.arguments[0]) MODEL STEPS")
}


func main() {
    let args = CommandLine.arguments
    let source: String
    let modelFile: String
    let stepCount: Int

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

    do {
        let source = try String(contentsOf: url)
        compiler.compile(source: source)
    }
    catch {
        print("Unknown error")
		exit(1)
    }

    let model: Model = compiler.model

    print("Model compiled: \(model.unaryActuators.count) UN, \(model.binaryActuators.count) BIN")

    let container = Container()
    let simulator = Simulator(model: compiler.model, container: container)

    // FIXME: Untie this initialization
    let mainStruct = compiler.model.structures["main"]!

    mainStruct.prototypes.forEach {
        proto in
        (0..<proto.count).forEach {
            _ in
            container.create(prototype: proto.prototype)
        }
    }

    simulator.debugDump()
    simulator.run(steps: stepCount)
    simulator.debugDump()

}

main()
