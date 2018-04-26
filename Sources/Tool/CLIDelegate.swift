import Simulator
import GraphvizWriter
import Model

class CLIDelegate: SimulatorDelegate {
	let path: String

	public init(outputPath: String) {
        path = outputPath
	}

	public func handleHalt(simulator: Simulator) {
		print("Halted!")
	}

	public func handleTrap(simulator: Simulator, traps: Set<Symbol>) {
		print("Traps!")
	}

	public func dotFileName(sequence: Int) -> String {
		let name = String(format: "%06d.dot", sequence)
        // FIXME: crete path
		return self.path + "/dots/" + name
	}

	public func willRun(simulator: Simulator) {
		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	public func didRun(simulator: Simulator) {
		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	public func willStep(simulator: Simulator) {
		writeDot(path: dotFileName(sequence: simulator.stepCount),
                 simulator: simulator)
	}

	public func didStep(simulator: Simulator) {
		// do nothing
	}

    func writeDot(path: String, simulator: Simulator) {
        let writer = DotWriter(path: path,
                               name: "g",
                               type: .directed)

        // FIXME: This is accessing internal
        simulator.container.references.forEach {
            oid in
            let obj = simulator.container[oid]
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
