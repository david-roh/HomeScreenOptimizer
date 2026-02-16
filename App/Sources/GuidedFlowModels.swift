import Core
import Foundation

enum OptimizationIntent: String, CaseIterable, Identifiable {
    case balanced
    case reachFirst
    case visualHarmony
    case minimalDisruption

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .reachFirst:
            return "Reach"
        case .visualHarmony:
            return "Visual"
        case .minimalDisruption:
            return "Stable"
        }
    }

    var shortDescription: String {
        switch self {
        case .balanced:
            return "General purpose"
        case .reachFirst:
            return "Fast thumb access"
        case .visualHarmony:
            return "Pattern-first layout"
        case .minimalDisruption:
            return "Minimal movement"
        }
    }

    var iconName: String {
        switch self {
        case .balanced:
            return "square.grid.2x2"
        case .reachFirst:
            return "hand.tap"
        case .visualHarmony:
            return "paintpalette"
        case .minimalDisruption:
            return "lock.shield"
        }
    }

    var bestFor: String {
        switch self {
        case .balanced:
            return "mixed priorities and daily reliability"
        case .reachFirst:
            return "one-hand speed and reduced thumb stretch"
        case .visualHarmony:
            return "color/pattern consistency with acceptable movement"
        case .minimalDisruption:
            return "small edits to an already familiar layout"
        }
    }

    var tradeoff: String {
        switch self {
        case .balanced:
            return "does not maximize any single metric"
        case .reachFirst:
            return "can move more icons than stable mode"
        case .visualHarmony:
            return "may place lower-usage apps in premium spots"
        case .minimalDisruption:
            return "can leave high-usage apps in harder zones"
        }
    }

    var engineDescription: String {
        switch self {
        case .balanced:
            return "Uses all four signals with moderate weights so recommendations stay practical."
        case .reachFirst:
            return "Pushes high-usage apps toward your highest-reach zones, accepting moderate movement."
        case .visualHarmony:
            return "Boosts aesthetic score, then applies a visual-pattern pass across the final grid."
        case .minimalDisruption:
            return "Strongly penalizes moves so the optimizer keeps your current layout mostly intact."
        }
    }

    var weights: GoalWeights {
        switch self {
        case .balanced:
            return GoalWeights(utility: 0.45, flow: 0.20, aesthetics: 0.20, moveCost: 0.15)
        case .reachFirst:
            return GoalWeights(utility: 0.58, flow: 0.18, aesthetics: 0.09, moveCost: 0.15)
        case .visualHarmony:
            return GoalWeights(utility: 0.24, flow: 0.20, aesthetics: 0.46, moveCost: 0.10)
        case .minimalDisruption:
            return GoalWeights(utility: 0.28, flow: 0.14, aesthetics: 0.08, moveCost: 0.50)
        }
    }

    static func nearest(to weights: GoalWeights) -> OptimizationIntent {
        allCases.min { lhs, rhs in
            lhs.distance(to: weights) < rhs.distance(to: weights)
        } ?? .balanced
    }

    private func distance(to other: GoalWeights) -> Double {
        let w = weights
        let utility = (w.utility - other.utility) * (w.utility - other.utility)
        let flow = (w.flow - other.flow) * (w.flow - other.flow)
        let aesthetics = (w.aesthetics - other.aesthetics) * (w.aesthetics - other.aesthetics)
        let moveCost = (w.moveCost - other.moveCost) * (w.moveCost - other.moveCost)
        return utility + flow + aesthetics + moveCost
    }
}

struct ProfileNameResolver {
    let existingNames: [String]
    let maxLength: Int

    init(existingNames: [String], maxLength: Int = 80) {
        self.existingNames = existingNames
        self.maxLength = maxLength
    }

    func resolve(
        typedName: String,
        context: ProfileContext,
        customContextLabel: String,
        handedness: Handedness,
        gripMode: GripMode
    ) -> String {
        let typed = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = typed.isEmpty
            ? generatedDefaultBaseName(
                context: context,
                customContextLabel: customContextLabel,
                handedness: handedness,
                gripMode: gripMode
            )
            : typed
        return dedupedName(for: clamped(base))
    }

    static func middleTruncated(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 1, text.count > maxCharacters else {
            return text
        }

        let keep = maxCharacters - 1
        let headCount = Int(ceil(Double(keep) / 2.0))
        let tailCount = keep - headCount
        let head = String(text.prefix(headCount))
        let tail = String(text.suffix(tailCount))
        return "\(head)…\(tail)"
    }

    private func generatedDefaultBaseName(
        context: ProfileContext,
        customContextLabel: String,
        handedness: Handedness,
        gripMode: GripMode
    ) -> String {
        let contextBase: String
        switch context {
        case .workday:
            contextBase = "Workday"
        case .weekend:
            contextBase = "Weekend"
        case .custom:
            let custom = customContextLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            contextBase = custom.isEmpty ? "Custom" : custom
        }
        return "\(contextBase) · \(displayTitle(for: handedness)) · \(displayTitle(for: gripMode))"
    }

    private func displayTitle(for handedness: Handedness) -> String {
        switch handedness {
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .alternating:
            return "Alternating"
        }
    }

    private func displayTitle(for gripMode: GripMode) -> String {
        switch gripMode {
        case .oneHand:
            return "One-Hand"
        case .twoHand:
            return "Two-Hand"
        }
    }

    private func dedupedName(for baseName: String) -> String {
        let existing = Set(existingNames.map(normalized))
        var candidate = baseName
        var index = 2

        while existing.contains(normalized(candidate)) {
            let suffix = " #\(index)"
            let prefixLength = max(1, maxLength - suffix.count)
            let head = String(baseName.prefix(prefixLength)).trimmingCharacters(in: .whitespacesAndNewlines)
            candidate = "\(head)\(suffix)"
            index += 1
        }
        return candidate
    }

    private func clamped(_ name: String) -> String {
        if name.count <= maxLength {
            return name
        }
        return String(name.prefix(maxLength))
    }

    private func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct PreviewLayoutModel {
    enum Phase {
        case current
        case recommended
    }

    let currentAssignments: [LayoutAssignment]
    let recommendedAssignments: [LayoutAssignment]

    var movedAppIDs: Set<UUID> {
        let currentByID = Dictionary(uniqueKeysWithValues: currentAssignments.map { ($0.appID, $0.slot) })
        let recommendedByID = Dictionary(uniqueKeysWithValues: recommendedAssignments.map { ($0.appID, $0.slot) })
        let union = Set(currentByID.keys).union(recommendedByID.keys)
        return Set(union.filter { currentByID[$0] != recommendedByID[$0] })
    }

    var pageIndices: [Int] {
        let pages = Set(currentAssignments.map(\.slot.page) + recommendedAssignments.map(\.slot.page))
        let sorted = pages.sorted()
        return sorted.isEmpty ? [0] : sorted
    }

    func assignments(on page: Int, phase: Phase, movedOnly: Bool) -> [LayoutAssignment] {
        let source: [LayoutAssignment]
        switch phase {
        case .current:
            source = currentAssignments
        case .recommended:
            source = recommendedAssignments
        }

        let moved = movedAppIDs
        return source.filter { assignment in
            assignment.slot.page == page && (!movedOnly || moved.contains(assignment.appID))
        }
    }
}
