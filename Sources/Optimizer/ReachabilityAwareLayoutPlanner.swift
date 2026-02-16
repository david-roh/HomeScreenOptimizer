import Core
import Foundation

public struct GeneratedLayoutPlan: Sendable {
    public var currentScore: ScoreBreakdown
    public var recommendedPlan: LayoutPlan

    public init(currentScore: ScoreBreakdown, recommendedPlan: LayoutPlan) {
        self.currentScore = currentScore
        self.recommendedPlan = recommendedPlan
    }
}

public struct ReachabilityAwareLayoutPlanner {
    private let scorer: LayoutScorer

    public init(scorer: LayoutScorer = LayoutScorer()) {
        self.scorer = scorer
    }

    public func generate(
        profile: Profile,
        apps: [AppItem],
        currentAssignments: [LayoutAssignment]
    ) -> GeneratedLayoutPlan {
        guard !apps.isEmpty, !currentAssignments.isEmpty else {
            let emptyBreakdown = ScoreBreakdown(utilityScore: 0, flowScore: 0, aestheticScore: 0, moveCostPenalty: 0)
            return GeneratedLayoutPlan(
                currentScore: emptyBreakdown,
                recommendedPlan: LayoutPlan(profileID: profile.id, assignments: [], scoreBreakdown: emptyBreakdown)
            )
        }

        let slots = currentAssignments.map(\.slot)
        let usageByApp = usageScores(for: apps)
        let reachabilityBySlot = reachabilityScores(for: slots, profile: profile)
        let context = LayoutScoringContext(usageByApp: usageByApp, reachabilityBySlot: reachabilityBySlot)

        let currentScore = scorer.score(
            assignments: currentAssignments,
            weights: profile.goalWeights,
            context: context
        )

        let sortedApps = apps.sorted { lhs, rhs in
            let lhsUsage = usageByApp[lhs.id] ?? 0
            let rhsUsage = usageByApp[rhs.id] ?? 0

            if lhsUsage != rhsUsage {
                return lhsUsage > rhsUsage
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        let sortedSlots = slots.sorted { lhs, rhs in
            let lhsReach = reachabilityBySlot[lhs] ?? 0
            let rhsReach = reachabilityBySlot[rhs] ?? 0

            if lhsReach != rhsReach {
                return lhsReach > rhsReach
            }

            if lhs.page != rhs.page {
                return lhs.page < rhs.page
            }
            if lhs.row != rhs.row {
                return lhs.row > rhs.row
            }

            return lhs.column < rhs.column
        }

        let recommendedAssignments = zip(sortedApps, sortedSlots).map { app, slot in
            LayoutAssignment(appID: app.id, slot: slot)
        }

        let candidateScore = scorer.score(
            assignments: recommendedAssignments,
            weights: profile.goalWeights,
            context: context
        )

        let plan = LayoutPlan(
            profileID: profile.id,
            assignments: recommendedAssignments,
            scoreBreakdown: candidateScore
        )

        return GeneratedLayoutPlan(currentScore: currentScore, recommendedPlan: plan)
    }

    private func usageScores(for apps: [AppItem]) -> [UUID: Double] {
        let fallbackByRank = Dictionary(uniqueKeysWithValues: apps.enumerated().map { index, app in
            let rankWeight = max(0.05, 1.0 - (Double(index) / Double(max(apps.count - 1, 1))))
            return (app.id, rankWeight)
        })

        return Dictionary(uniqueKeysWithValues: apps.map { app in
            let explicit = max(0, app.usageScore ?? -1)
            if explicit >= 0 {
                return (app.id, explicit)
            }

            return (app.id, fallbackByRank[app.id] ?? 0.1)
        })
    }

    private func reachabilityScores(for slots: [Slot], profile: Profile) -> [Slot: Double] {
        let rows = max((slots.map(\.row).max() ?? 0) + 1, 1)
        let columns = max((slots.map(\.column).max() ?? 0) + 1, 1)

        return Dictionary(uniqueKeysWithValues: slots.map { slot in
            if let calibrated = profile.reachabilityMap.slotWeights[slot] {
                return (slot, calibrated)
            }

            return (slot, heuristicReachability(slot: slot, rows: rows, columns: columns, profile: profile))
        })
    }

    private func heuristicReachability(slot: Slot, rows: Int, columns: Int, profile: Profile) -> Double {
        let vertical = rows > 1 ? Double(slot.row) / Double(rows - 1) : 1
        let rightBias = columns > 1 ? Double(slot.column) / Double(columns - 1) : 0.5
        let leftBias = 1 - rightBias

        let handednessFactor: Double
        switch profile.handedness {
        case .left:
            handednessFactor = leftBias
        case .right:
            handednessFactor = rightBias
        case .alternating:
            handednessFactor = max(leftBias, rightBias)
        }

        switch profile.gripMode {
        case .oneHand:
            return max(0, min(1, (0.7 * vertical) + (0.3 * handednessFactor)))
        case .twoHand:
            let centerDistance = abs(rightBias - 0.5) * 2
            let centerEase = 1 - centerDistance
            return max(0, min(1, (0.45 * vertical) + (0.35 * centerEase) + (0.20 * handednessFactor)))
        }
    }
}
