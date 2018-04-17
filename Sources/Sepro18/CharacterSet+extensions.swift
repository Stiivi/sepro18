// Convenience extensions to CharacterSet

import Foundation

func |(left: CharacterSet, right: CharacterSet) -> CharacterSet {
    return left.union(right)
}

func |(left: CharacterSet, right: String) -> CharacterSet {
    return left.union(CharacterSet(charactersIn:right))
}

