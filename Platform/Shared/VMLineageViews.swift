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

import SwiftUI

/// Lines connecting one row of the lineage graph to the rows above and below it.
struct VMLineageGutter: View {
    let row: VMLineageGraph<UUID>.Row
    let laneCount: Int
    let isImage: Bool
    /// Edges into these nodes and the nodes themselves are drawn in the accent color
    let highlighted: Set<UUID>

    static let laneWidth: CGFloat = 14
    /// Matches the center of the icon in `VMCardView`, so rows that grow keep their node beside the icon
    static let nodeY: CGFloat = 25
    private static let nodeSize: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            let lineWidth: CGFloat = 2
            for segment in row.segments {
                var path = Path()
                switch segment.stroke {
                case .top(let lane):
                    path.move(to: CGPoint(x: x(lane), y: 0))
                    path.addLine(to: CGPoint(x: x(lane), y: Self.nodeY))
                case .bottom(let lane):
                    path.move(to: CGPoint(x: x(lane), y: Self.nodeY))
                    path.addLine(to: CGPoint(x: x(lane), y: size.height))
                case .through(let lane):
                    path.move(to: CGPoint(x: x(lane), y: 0))
                    path.addLine(to: CGPoint(x: x(lane), y: size.height))
                case .branch(let from, let to):
                    path.move(to: CGPoint(x: x(from), y: Self.nodeY))
                    path.addCurve(to: CGPoint(x: x(to), y: size.height),
                                  control1: CGPoint(x: x(to), y: Self.nodeY),
                                  control2: CGPoint(x: x(to), y: Self.nodeY))
                }
                context.stroke(path, with: .color(color(segment.child)), lineWidth: lineWidth)
            }
            let center = CGPoint(x: x(row.lane), y: Self.nodeY)
            let rect = CGRect(x: center.x - Self.nodeSize / 2, y: center.y - Self.nodeSize / 2, width: Self.nodeSize, height: Self.nodeSize)
            let node = isImage ? Path(roundedRect: rect, cornerRadius: 2) : Path(ellipseIn: rect)
            context.fill(node, with: .color(color(row.id)))
        }
        .frame(width: CGFloat(max(laneCount, 1)) * Self.laneWidth)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private func x(_ lane: Int) -> CGFloat {
        (CGFloat(lane) + 0.5) * Self.laneWidth
    }

    private func color(_ id: UUID) -> Color {
        highlighted.contains(id) ? .accentColor : .secondary
    }
}

#if !WITH_REMOTE
/// Snapshots of a VM folded into its row in the lineage graph.
struct VMLineageSnapshots: View {
    @ObservedObject var vm: VMData
    @ObservedObject var list: VMSnapshotList

    var body: some View {
        // modifiers on a Group apply to its children, so the task needs a container that exists without snapshots
        VStack(alignment: .leading) {
            if !list.snapshots.isEmpty {
                DisclosureGroup {
                    ForEach(list.snapshots) { snapshot in
                        Label(snapshot.title, systemImage: snapshot.id == list.currentParentID ? "smallcircle.filled.circle" : "circle")
                            .font(.subheadline)
                    }
                } label: {
                    Text(String.localizedStringWithFormat(NSLocalizedString("%lld snapshots", comment: "VMLineageViews"), list.snapshots.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }.task(id: vm.state) {
            try? await list.refresh()
        }
    }
}

#endif

/// Asks for the names of an image.
struct VMImageLabelsView: View {
    let title: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    @State var text: String
    let onConfirm: ([String]) -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            TextField("ubuntu:base, lts", text: $text)
                .textFieldStyle(.roundedBorder)
            Text("Separate names with commas.")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)
                Button(confirmTitle) {
                    presentationMode.wrappedValue.dismiss()
                    onConfirm(Self.labels(from: text))
                }.keyboardShortcut(.defaultAction)
            }
        }.padding()
        #if os(macOS)
        .frame(minWidth: 320)
        #endif
    }

    static func labels(from text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
