import Compiler
import Simulator
import Simulation
import DotWriter
import Model

import Foundation
import Logging

final class Tool {

    let logger = Logger(label: "sepro.main")
    
	let outputPath: String
    let dotsPath: String

    let simulator: IterativeSimulator<SeproSimulation>
    public let model: Model

	init(modelPath: String, outputPath: String) {
        let model = Model()

        let compiler = ModelCompiler(model: model)
        let source: String

        self.model = model

        logger.info("Loading model from \(modelPath)...")

        do {
            source = try String(contentsOfFile: modelPath, encoding:String.Encoding.utf8)
        } catch {
            logger.error("Unable to read model '\(modelPath)'")
            exit(1)
        }

        logger.info("Compiling model...")

        compiler.compile(source: source)

        logger.info("Model compiled")
        logger.info("    Symbol count    : \(model.symbols.count)")
        logger.info("    Unary actuators : \(model.unaryActuators.count)")
        logger.info("    Binary actuators: \(model.unaryActuators.count)")

        let simulation = SeproSimulation(model: model)
        simulator = IterativeSimulator(simulation: simulation)

        self.outputPath = outputPath
        dotsPath = outputPath + "/dots"
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
        let graph = simulator.simulation.state.graph

        for object in graph.objects {
            // Get raw dot attribute string for every tag of the object
            // FIXME: This is _very_ unsafe, but helps us style our output for
            // the time being
            let tags = object.state.tags
            var attributeData: [String:[DataItem]] = [:]
            attributeData["color"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_color", $0]))
            }
            attributeData["shape"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_shape", $0]))
            }
            attributeData["style"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_style", $0]))
            }
            attributeData["fillcolor"] = tags.flatMap {
                simulator.simulation.model.getData(tags:Set(["dot_fillcolor", $0]))
            }
            writeObject(oid: object.reference, object: object.state, attributeData: attributeData, into: writer)

            // Edges
            // ----------------

            for (slot, target) in object.references {
                var edgeAttrs: [String: String] = [:]

                // TODO: Default attributes
                edgeAttrs["label"] = slot
                edgeAttrs["fontname"] = "Helvetica"
                edgeAttrs["fontsize"] = "9"

                writer.writeEdge(from: object.reference.description,
                                 to: target.description,
                                 attributes: edgeAttrs)
            }
        }

        writer.close()
    }
	/// Write object node and it's relationships from slots. Nodes
	/// are labelled with object ids.
	func writeObject(oid: OID, object: SimulationState.ObjectState,
                  attributeData: [String:[DataItem]], into writer: DotWriter) {
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

	}

}
