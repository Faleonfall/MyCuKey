import CoreGraphics
import Foundation

// MARK: - Keyboard Geometry
// QWERTY key centers in key-width units (one unit = one key width). The row
// stagger matches the physical layout. Distances between centers are all that
// matter for the spatial model, so absolute units are arbitrary but consistent.
enum KeyGeometry {
    static let centers: [Character: CGPoint] = {
        var result: [Character: CGPoint] = [:]
        let rows: [(y: CGFloat, offset: CGFloat, keys: String)] = [
            (0, 0.0, "qwertyuiop"),
            (1, 0.5, "asdfghjkl"),
            (2, 1.5, "zxcvbnm"),
        ]
        for row in rows {
            for (index, character) in row.keys.enumerated() {
                result[character] = CGPoint(x: row.offset + CGFloat(index), y: row.y)
            }
        }
        return result
    }()

    static func center(for character: Character) -> CGPoint? {
        guard let lower = character.lowercased().first else { return nil }
        return centers[lower]
    }
}

// MARK: - Spatial Model
// log P(tap landed where it did | the user intended `character`): a 2D Gaussian
// over the distance from the tap to that key's center. Constant terms dropped
// (only relative scores matter). sigma is in key-width units.
struct KeySpatialModel {
    var sigma: CGFloat = 0.9
    var centers: [Character: CGPoint] = KeyGeometry.centers

    func logLikelihood(tap: CGPoint, intended character: Character) -> Double {
        guard let lower = character.lowercased().first, let center = centers[lower] else {
            return -8
        }
        let dx = Double(tap.x - center.x)
        let dy = Double(tap.y - center.y)
        let s = Double(sigma)
        return -(dx * dx + dy * dy) / (2 * s * s)
    }
}

// MARK: - Tap Decoder (noisy-channel over taps)
extension UnifiedDecoder {
    // Beam search over the trie that explains a sequence of tap points as the
    // most likely real word: spatial likelihood per tap fused with unigram
    // frequency, with insertion (extra tap) and deletion (missing tap) handled
    // so a word need not be exactly as long as the tap sequence.
    func decodeTaps(
        _ taps: [CGPoint],
        centers: [Character: CGPoint] = KeyGeometry.centers,
        sigma: CGFloat = 0.9,
        beamWidth: Int = 24,
        limit: Int = 5
    ) -> [Candidate] {
        guard !taps.isEmpty else { return [] }
        let model = KeySpatialModel(sigma: sigma, centers: centers)
        let insertionPenalty = -4.0
        let deletionPenalty = -4.0

        struct Beam {
            let node: WordTrie.Node
            let tapIndex: Int
            let logProb: Double
        }
        var beams = [Beam(node: trie.root, tapIndex: 0, logProb: 0)]
        var best: [String: Double] = [:]

        var iterations = 0
        let maxIterations = taps.count + 6
        while !beams.isEmpty && iterations < maxIterations {
            iterations += 1
            var next: [Beam] = []
            for beam in beams {
                if beam.tapIndex == taps.count, let word = beam.node.word {
                    if best[word] == nil || beam.logProb > best[word]! {
                        best[word] = beam.logProb
                    }
                }
                if beam.tapIndex < taps.count {
                    let tap = taps[beam.tapIndex]
                    for (character, child) in beam.node.children {
                        next.append(
                            Beam(
                                node: child, tapIndex: beam.tapIndex + 1,
                                logProb: beam.logProb
                                    + model.logLikelihood(tap: tap, intended: character)))
                    }
                    // insertion: an extra/spurious tap not part of the word
                    next.append(
                        Beam(
                            node: beam.node, tapIndex: beam.tapIndex + 1,
                            logProb: beam.logProb + insertionPenalty))
                }
                // deletion: a word letter the user never tapped
                for (_, child) in beam.node.children {
                    next.append(
                        Beam(
                            node: child, tapIndex: beam.tapIndex,
                            logProb: beam.logProb + deletionPenalty))
                }
            }
            next.sort { $0.logProb > $1.logProb }
            beams = Array(next.prefix(beamWidth))
        }

        let logMax = Foundation.log(10000.0)
        let scored = best.map { word, spatial -> Candidate in
            let frequency = trie.score(for: word) ?? 1
            let lm = Foundation.log(max(frequency, 1)) / logMax
            let total = spatial + lm
            let perTap = spatial / Double(taps.count)
            let confidence = min(1, max(0, 1 + perTap / 3))
            return Candidate(word: word, score: total, distance: 0, confidence: confidence)
        }
        .sorted { $0.score > $1.score }
        return Array(scored.prefix(limit))
    }
}
