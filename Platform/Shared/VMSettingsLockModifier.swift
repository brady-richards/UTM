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

/// Disables a setting that cannot change while the VM in the environment is running or suspended,
/// and says why on hover.
struct VMSettingsLockModifier: ViewModifier {
    @EnvironmentObject private var vm: VMData
    /// Shown on hover while the setting can be changed
    var help: LocalizedStringKey?
    /// The setting can always be changed when this is false
    var isActive: Bool = true

    func body(content: Content) -> some View {
        if isActive, let reason = vm.settingsLockReason {
            content
                .disabled(true)
                .help(reason)
        } else if let help = help {
            content
                .help(help)
        } else {
            content
        }
    }
}

extension View {
    /// Disables this while the VM is running or suspended, with a hover explaining why
    /// - Parameters:
    ///   - help: Hover shown otherwise, in place of a `help` modifier
    ///   - isActive: The setting can always be changed when this is false
    func lockedWhileRunning(help: LocalizedStringKey? = nil, isActive: Bool = true) -> some View {
        modifier(VMSettingsLockModifier(help: help, isActive: isActive))
    }
}
