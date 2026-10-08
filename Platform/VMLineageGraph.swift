//
// Copyright © 2026 Brady Richards. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/// Rows and lanes for drawing images and the VMs derived from them as a tree, like a git history.
///
/// Roots come first and every node is followed by its descendants. A node's first child continues
/// in its lane and every other child branches off into a lane of its own.
struct VMLineageGraph<ID: Hashable> {
    /// One piece of an edge drawn within a single row
    enum Stroke: Equatable {
        /// From the top edge of the row to the node
        case top(lane: Int)
        /// From the node to the bottom edge of the row
        case bottom(lane: Int)
        /// Across the whole row
        case through(lane: Int)
        /// From the node in one lane to the bottom edge of the row in another
        case branch(from: Int, to: Int)
    }

    struct Segment: Equatable {
        var stroke: Stroke
        /// The edge belongs to this node and its parent
        var child: ID
    }

    struct Row: Equatable {
        var id: ID
        var lane: Int
        var segments: [Segment]
    }

    private(set) var rows: [Row] = []

    /// Lanes needed to draw every row
    private(set) var laneCount: Int = 0

    private var parents: [ID: ID] = [:]

    /// - Parameters:
    ///   - nodes: Every node in the order siblings should appear
    ///   - parent: The parent of a node, ignored when it is not one of the nodes
    init(nodes: [ID], parent: (ID) -> ID?) {
        var known = Set<ID>()
        let nodes = nodes.filter { known.insert($0).inserted }
        var children: [ID: [ID]] = [:]
        var roots: [ID] = []
        for node in nodes {
            if let parent = parent(node), known.contains(parent), parent != node {
                parents[node] = parent
                children[parent, default: []].append(node)
            } else {
                roots.append(node)
            }
        }
        breakCycles(nodes: nodes, children: &children, roots: &roots)

        var order: [ID] = []
        var visit: [ID] = roots.reversed()
        while let node = visit.popLast() {
            order.append(node)
            visit.append(contentsOf: (children[node] ?? []).reversed())
        }
        let rowOf = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        // a chain is a node followed by first children for as long as there are any
        var lanes: [ID: Int] = [:]
        var occupied: [ClosedRange<Int>] = []
        var laneOfRange: [Int] = []
        for node in order where parents[node] == nil || children[parents[node]!]!.first != node {
            var tail = node
            while let first = children[tail]?.first {
                tail = first
            }
            let start = parents[node].map { rowOf[$0]! } ?? rowOf[node]!
            let span = start...rowOf[tail]!
            var lane = 0
            while zip(occupied, laneOfRange).contains(where: { $1 == lane && $0.overlaps(span) }) {
                lane += 1
            }
            occupied.append(span)
            laneOfRange.append(lane)
            var member: ID? = node
            while let current = member {
                lanes[current] = lane
                member = children[current]?.first
            }
        }
        laneCount = (lanes.values.max() ?? -1) + 1

        rows = order.map { Row(id: $0, lane: lanes[$0]!, segments: []) }
        for (row, node) in order.enumerated() {
            let lane = lanes[node]!
            guard let parent = parents[node] else {
                continue
            }
            let parentRow = rowOf[parent]!
            let parentLane = lanes[parent]!
            rows[row].segments.append(Segment(stroke: .top(lane: lane), child: node))
            if parentLane == lane {
                rows[parentRow].segments.append(Segment(stroke: .bottom(lane: lane), child: node))
            } else {
                rows[parentRow].segments.append(Segment(stroke: .branch(from: parentLane, to: lane), child: node))
            }
            for between in (parentRow + 1)..<row {
                rows[between].segments.append(Segment(stroke: .through(lane: lane), child: node))
            }
        }
    }

    /// A parent loop can only come from hand-edited configurations; break it so every node is shown.
    private mutating func breakCycles(nodes: [ID], children: inout [ID: [ID]], roots: inout [ID]) {
        var reached = Set<ID>()
        var visit = roots
        while let node = visit.popLast() {
            reached.insert(node)
            visit.append(contentsOf: children[node] ?? [])
        }
        for node in nodes where !reached.contains(node) {
            if let parent = parents.removeValue(forKey: node) {
                children[parent]?.removeAll { $0 == node }
            }
            roots.append(node)
            var visit = [node]
            while let next = visit.popLast() {
                reached.insert(next)
                visit.append(contentsOf: children[next] ?? [])
            }
        }
    }

    /// The node and every node it was derived from
    func ancestry(of node: ID) -> Set<ID> {
        var result: Set<ID> = [node]
        var current = node
        while let parent = parents[current], !result.contains(parent) {
            result.insert(parent)
            current = parent
        }
        return result
    }
}
