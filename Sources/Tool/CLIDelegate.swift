import Simulator
import Simulation
import DotWriter
import Model

import Foundation

final class CLIDelegate: SimulatorDelegate {
    typealias S = SeproSimulation

	let outputPath: String
    let dotsPath: String

	init(outputPath: String) {
        self.outputPath = outputPath
        dotsPath = outputPath + "/dots"
	}

	func didHalt(simulator: IterativeSimulator<S, CLIDelegate>) {
		print("Halted!")
	}

	func handleTrap(simulator: IterativeSimulator<S, CLIDelegate>, traps: Set<Symbol>) {
		print("Traps!")
	}

	func dotFileName(sequence: Int) -> String {
		let name = String(format: "%06d.dot", sequence)
		return dotsPath + name
	}

	func willRun(simulator: IterativeSimulator<S, CLIDelegate>) {
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

		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	func didRun(simulator: IterativeSimulator<S, CLIDelegate>) {
		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	func willStep(simulator: IterativeSimulator<S, CLIDelegate>) {
		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	func didStep(simulator: IterativeSimulator<S, CLIDelegate>,
                 signal: S.Signal?) {
		// do nothing
	}

    func writeDot(path: String, simulator: IterativeSimulator<S, CLIDelegate>) {
        let writer = DotWriter(path: path,
                               name: "g",
                               type: .directed)

        // FIXME: This is accessing internal
        simulator.simulation.container.references.forEach {
            oid in
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
		var attrs = Dictionary<String, String>()
		let tagsString = object.tags.sorted().joined(separator:",")
		let label = "\(oid):\(tagsString)"

        let color = attributeData["color"]?.first {
            item in
            !item.tags.isDisjoint(with:object.tags)
        }?.text

        let shape = attributeData["shape"]?.first {
            item in
            !item.tags.isDisjoint(with:object.tags)
        }?.text

        let style = attributeData["style"]?.first {
            item in
            !item.tags.isDisjoint(with:object.tags)
        }?.text
        let fillcolor = attributeData["fillcolor"]?.first {
            item in
            !item.tags.isDisjoint(with:object.tags)
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

        object.references.forEach {
            key, value in
            var edgeAttrs = Dictionary<String, String>() 

            // TODO: Default attributes
			edgeAttrs["label"] = key
			edgeAttrs["fontname"] = "Helvetica"
			edgeAttrs["fontsize"] = "9"

            writer.writeEdge(from: oid.description,
                             to: value.description,
                             attributes: edgeAttrs)
		}
	}

}
