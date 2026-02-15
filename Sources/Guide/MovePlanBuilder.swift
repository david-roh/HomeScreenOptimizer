import Core
import Foundation

public struct MovePlanBuilder {
    public init() {}

    public func buildMoves(current: [LayoutAssignment], target: [LayoutAssignment]) -> [MoveStep] {
        let currentByApp = Dictionary(uniqueKeysWithValues: current.map { ($0.appID, $0.slot) })

        return target.compactMap { desired in
            guard let currentSlot = currentByApp[desired.appID], currentSlot != desired.slot else {
                return nil
            }

            return MoveStep(appID: desired.appID, fromSlot: currentSlot, toSlot: desired.slot)
        }
    }
}
