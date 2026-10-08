//
// Copyright © 2020 osy. All rights reserved.
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

struct VMCardView: View {
    @ObservedObject var vm: VMData
    @EnvironmentObject private var data: UTMData
    
    #if os(macOS)
    typealias PlatformImage = NSImage
    #else
    typealias PlatformImage = UIImage
    #endif
    
    var body: some View {
        HStack {
            if vm.isShortcut {
                Logo(logo: PlatformImage(contentsOfURL: vm.detailsIconUrl))
                        .overlay(Image(systemName: "arrowshape.turn.up.forward.fill")
                                    .resizable()
                                    .frame(width: 8, height: 8)
                                    .aspectRatio(contentMode: .fit), alignment: .bottomLeading)
            } else if vm.isImage {
                Logo(logo: PlatformImage(contentsOfURL: vm.detailsIconUrl))
                    .opacity(0.5)
                    .overlay(Image(systemName: "square.stack.3d.up.fill")
                                .resizable()
                                .frame(width: 12, height: 12)
                                .aspectRatio(contentMode: .fit), alignment: .bottomTrailing)
            } else {
                Logo(logo: PlatformImage(contentsOfURL: vm.detailsIconUrl))
            }
            VStack(alignment: .leading) {
                Text(vm.isImage ? vm.detailsImageLabel : vm.detailsTitleLabel)
                    .font(.headline)
                if vm.isImage && vm.detailsLabels.count > 1 {
                    Text(vm.detailsLabels.dropFirst().joined(separator: ", "))
                        .font(.subheadline)
                } else if !vm.isImage, let parent = data.parent(of: vm) {
                    Text(String.localizedStringWithFormat(NSLocalizedString("from %@", comment: "VMCardView"), parent.detailsImageLabel))
                        .font(.subheadline)
                } else {
                    Text(vm.detailsSubtitleLabel)
                        .font(.subheadline)
                }
            }.lineLimit(1)
            .truncationMode(.tail)
            Spacer()
            if vm.isImage {
                #if !os(visionOS) && !WITH_REMOTE // tap target too small, FIXME: implement remote feature
                Button {
                    data.busyWorkAsync {
                        try await data.derive(from: vm)
                    }
                } label: {
                    Label("New VM from Image", systemImage: "plus.circle")
                        .font(.largeTitle)
                        .labelStyle(.iconOnly)
                }.help("Create a new VM from this image.")
                #endif
            } else if vm.isStopped {
                #if !os(visionOS) // tap target too small
                Button {
                    data.run(vm: vm)
                } label: {
                    Label("Run", systemImage: "play.circle.fill")
                        .font(.largeTitle)
                        .labelStyle(.iconOnly)
                }
                #endif
            } else if vm.isBusy {
                Spinner(size: .large)
            }
        }.padding([.top, .bottom], 10)
        .buttonStyle(.plain)
        #if os(macOS)
        .onDoubleClick {
            if !vm.isImage {
                data.run(vm: vm)
            }
        }
        #else
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if !vm.isImage {
                data.run(vm: vm)
            }
        })
        #endif
    }
}

#if os(macOS)
struct Logo: View {
    let logo: NSImage?
    
    var body: some View {
        Group {
            if logo != nil {
                Image(nsImage: logo!)
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .foregroundColor(.accentColor)
            }
        }
    }
}
#else // iOS
struct Logo: View {
    let logo: UIImage?
    
    var body: some View {
        Group {
            if logo != nil {
                Image(uiImage: logo!)
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .frame(width: 30.0, height: 30.0)
            }
        }
    }
}
#endif

struct VMCardView_Previews: PreviewProvider {
    static var previews: some View {
        VMCardView(vm: VMData(from: .empty))
    }
}
