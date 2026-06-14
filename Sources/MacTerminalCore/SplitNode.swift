import Foundation

public enum SplitAxis: String, Codable, Equatable, Sendable {
    case leftRight
    case topBottom
}

public indirect enum SplitNode: Codable, Equatable, Sendable {
    case pane(UUID)
    case split(axis: SplitAxis, ratio: Double, first: SplitNode, second: SplitNode)

    private enum CodingKeys: String, CodingKey {
        case kind
        case paneID
        case axis
        case ratio
        case first
        case second
    }

    private enum Kind: String, Codable {
        case pane
        case split
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .pane:
            self = .pane(try container.decode(UUID.self, forKey: .paneID))
        case .split:
            let axis = try container.decode(SplitAxis.self, forKey: .axis)
            let ratio = try container.decode(Double.self, forKey: .ratio)
            let first = try container.decode(SplitNode.self, forKey: .first)
            let second = try container.decode(SplitNode.self, forKey: .second)
            self = .split(axis: axis, ratio: ratio, first: first, second: second)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .pane(paneID):
            try container.encode(Kind.pane, forKey: .kind)
            try container.encode(paneID, forKey: .paneID)
        case let .split(axis, ratio, first, second):
            try container.encode(Kind.split, forKey: .kind)
            try container.encode(axis, forKey: .axis)
            try container.encode(ratio, forKey: .ratio)
            try container.encode(first, forKey: .first)
            try container.encode(second, forKey: .second)
        }
    }

    public var paneIDs: [UUID] {
        switch self {
        case let .pane(id):
            return [id]
        case let .split(_, _, first, second):
            return first.paneIDs + second.paneIDs
        }
    }

    public func replacingPane(_ target: UUID, with replacement: SplitNode) -> SplitNode {
        switch self {
        case let .pane(id):
            return id == target ? replacement : self
        case let .split(axis, ratio, first, second):
            return .split(
                axis: axis,
                ratio: ratio,
                first: first.replacingPane(target, with: replacement),
                second: second.replacingPane(target, with: replacement)
            )
        }
    }

    public func clampingRatios(minimum: Double = 0.15, maximum: Double = 0.85) -> SplitNode {
        switch self {
        case .pane:
            return self
        case let .split(axis, ratio, first, second):
            return .split(
                axis: axis,
                ratio: min(max(ratio, minimum), maximum),
                first: first.clampingRatios(minimum: minimum, maximum: maximum),
                second: second.clampingRatios(minimum: minimum, maximum: maximum)
            )
        }
    }

    public func balancingEqualSplitRatios() -> SplitNode {
        switch self {
        case .pane:
            return self
        case let .split(axis, _, first, second):
            let balancedFirst = first.balancingEqualSplitRatios()
            let balancedSecond = second.balancingEqualSplitRatios()
            let firstWeight = balancedFirst.layoutWeight(along: axis)
            let secondWeight = balancedSecond.layoutWeight(along: axis)
            let totalWeight = firstWeight + secondWeight
            let ratio = totalWeight > 0 ? firstWeight / totalWeight : 0.5
            return .split(axis: axis, ratio: ratio, first: balancedFirst, second: balancedSecond)
        }
    }

    private func layoutWeight(along axis: SplitAxis) -> Double {
        switch self {
        case .pane:
            return 1
        case let .split(splitAxis, _, first, second):
            if splitAxis == axis {
                return first.layoutWeight(along: axis) + second.layoutWeight(along: axis)
            }
            return 1
        }
    }
}
