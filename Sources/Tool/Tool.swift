import Compiler
import Simulator
import Simulation
import DotWriter
import Model

import Foundation

final class Tool {

	let outputPath: String
    let dotsPath: String

    let simulator: IterativeSimulator<SeproSimulation>
    public let model: Model

	init(modelPath: String, outputPath: String) {
        let compiler = Compiler()
        let source: String

        print("Loading model from \(modelPath)...")

        do {
            source = try String(contentsOfFile: modelPath, encoding:String.Encoding.utf8)
        } catch {
            errorExit("Unable to read model '\(modelPath)'")
        }

        print("Compiling model...")

        compiler.compile(source: source)
        model = compiler.model

        print("Model compiled")
        print("    Symbol count    : \(model.symbols.count)")
        print("    Unary actuators : \(model.unaryActuators.count)")
        print("    Binary actuators: \(model.unaryActuators.count)")

        let container = Container()
        let simulation = SeproSimulation(model: model, container: container)
        simulator = IterativeSimulator(simulation: simulation)

        self.outputPath = outputPath
        dotsPath = outputPath + "/dots"
	}

    func initializeWorld(_ name: String) {
        guard let world = model.worlds[name] else {
            fatalError("Unknown world '\(name)'")
        }

        print("Initializing simulation with world '\(name)'...")

        // Initialize the structures
        // -----------------------------------------------------------------------
        for qstruct in world.structs {
            for _ in 0..<qstruct.count {
                guard let structure = model.structs[qstruct.structName] else {
                    fatalError("No structure '\(qstruct.structName)'")
                }
                // FIXME: too deep access
                simulator.simulation.container.create(structure: structure)
            }
        }
    }

    func printSymbolTable() {
        let symbols = simulator.simulation.model.symbols
        print("Symbol Table:")
        symbols.sorted { rhs, lhs in
            lhs.key.lowercased() > rhs.key.lowercased()
        }
        .forEach {
            print("    \($0.key) \($0.value.rawValue)")
        }
    }

    func run(stepCount: Int) {
        prepareOutput()

        // Write initial state
		writeDot(path: dotFileName(sequence: simulator.stepCount))

        // Run the simulation
        // -----------------------------------------------------------------------
        simulator.run(steps: stepCount) { (_, signal) in
            if !signal.traps.isEmpty {
                print("Traps: \(signal.traps)")
            }
            if !signal.notifications.isEmpty {
                print("Notifications: \(signal.notifications)")
            }

            self.writeDot(path: self.dotFileName(sequence: self.simulator.stepCount))
        }

    }

	func dotFileName(sequence: Int) -> String {
		let name = String(format: "%06d.dot", sequence)
		return "\(dotsPath)/\(name)"
	}

	func prepareOutput() {
        // Create output directories
        // -----------------------------------------------------------------------
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(atPath:outputPath,
                                            withIntermediateDirectories: true)
        }
        catch {
            fatalError("Unable to create output directory '\(outputPath)'")
        }

        do {
            try fileManager.createDirectory(atPath:dotsPath,
                                            withIntermediateDirectories: true)
        }
        catch {
            fatalError("Unable to create dot files directory '\(dotsPath)'")
        }

		writeDot(path: dotFileName(sequence: simulator.stepCount))
	}

    func writeDot(path: String) {
        let writer = DotWriter(path: path,
                               name: "g",
                               type: .directed)

        // FIXME: This is accessing internal
        for oid in simulator.simulation.container.references {
            let obj = simulator.simulation.container[oid]

            // Get raw dot attribute string for every tag of the object
            // FIXME: This is _very_ unsafe, but helps us style our output for
            // the time being
            var attributeData: [String:[DataItem]] = [:]
            attributeData["color"] = obj.tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_color", $0]))
            }
            attributeData["shape"] = obj.tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_shape", $0]))
            }
            attributeData["style"] = obj.tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_style", $0]))
            }
            attributeData["fillcolor"] = obj.tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_fillcolor", $0]))
            }
            writeObject(oid: oid, object: obj, attributeData: attributeData, into: writer)
        }

        writer.close()
    }
	/// Write object node and it's relationships from slots. Nodes
	/// are labelled with object ids.
	func writeObject(oid: OID, object: Object, attributeData: [String:[DataItem]], into writer: DotWriter) {
		var attrs: [String:String] = [:]
		let tagsString = object.tags.sorted().joined(separator:",")
		let label = "\(oid):\(tagsString)"

        let color = attributeData["color"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        let shape = attributeData["shape"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        let style = attributeData["style"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text
        let fillcolor = attributeData["fillcolor"]?.first {
            !$0.tags.isDisjoint(with:object.tags)
        }?.text

        // Node
        // ----------------

		attrs["fontname"] = "Helvetica"
        attrs["color"] = color ?? "black"
        attrs["fillcolor"] = fillcolor ?? "white"
		attrs["shape"] = shape ?? "box"
		attrs["style"] = style ?? "rounded"
        attrs["label"] = label
		attrs["fontsize"] = "11"
        writer.writeNode(oid.description, attributes: attrs)

        // Edges
        // ----------------

        for (slot, target) in object.references {
            var edgeAttrs: [String: String] = [:]

            // TODO: Default attributes
			edgeAttrs["label"] = slot
			edgeAttrs["fontname"] = "Helvetica"
			edgeAttrs["fontsize"] = "9"

            writer.writeEdge(from: oid.description,
                             to: target.description,
                             attributes: edgeAttrs)
		}
	}

}
