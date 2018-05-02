import Simulator
import Simulation
import GraphvizWriter
import Model

final class CLIDelegate: SimulatorDelegate {
    typealias S = SeproSimulation

	let path: String

	init(outputPath: String) {
        path = outputPath
	}

	func didHalt(simulator: IterativeSimulator<S, CLIDelegate>) {
		print("Halted!")
	}

	func handleTrap(simulator: IterativeSimulator<S, CLIDelegate>, traps: Set<Symbol>) {
		print("Traps!")
	}

	func dotFileName(sequence: Int) -> String {
		let name = String(format: "%06d.dot", sequence)
        // FIXME: crete path
		return self.path + "/dots/" + name
	}

	func willRun(simulator: IterativeSimulator<S, CLIDelegate>) {
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
            writeObject(oid: oid, object: obj, into: writer)
        }

        writer.close()
    }
	/// Write object node and it's relationships from slots. Nodes
	/// are labelled with object ids.
	func writeObject(oid: OID, object: Object, into writer: DotWriter) {
		var attrs = Dictionary<String, String>()
		let tags = object.tags.sorted().joined(separator:",")
		let label = "\(oid):\(tags)"

        // Node
        // ----------------

		attrs["fontname"] = "Helvetica"
		attrs["shape"] = "box"
		attrs["style"] = "rounded"
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
