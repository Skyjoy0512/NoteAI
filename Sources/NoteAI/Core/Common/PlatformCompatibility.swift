import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
#endif

extension Color {
    static var platformSystemBackground: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    static var platformSystemGray6: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
}

#if os(iOS)
struct NavigationModifier: ViewModifier {
    let displayMode: NavigationBarItem.TitleDisplayMode
    
    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(displayMode)
    }
}
#endif

extension View {
    func compatibleNavigationBarTitleDisplayMode(_ displayMode: Any) -> some View {
        #if os(iOS)
        if let iosDisplayMode = displayMode as? NavigationBarItem.TitleDisplayMode {
            return AnyView(self.modifier(NavigationModifier(displayMode: iosDisplayMode)))
        } else {
            return AnyView(self)
        }
        #else
        return AnyView(self)
        #endif
    }
    
    func compatibleToolbarItem<Content: View>(placement: Any, @ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        if let iosPlacement = placement as? ToolbarItemPlacement {
            return AnyView(self.toolbar {
                ToolbarItem(placement: iosPlacement) {
                    content()
                }
            })
        } else {
            return AnyView(self)
        }
        #else
        return AnyView(self.toolbar {
            ToolbarItem(placement: .primaryAction) {
                content()
            }
        })
        #endif
    }
    
    func compatiblePickerStyle(_ style: Any) -> some View {
        #if os(iOS)
        if style as? String == "navigationLink" {
            return AnyView(self.pickerStyle(.navigationLink))
        } else {
            return AnyView(self)
        }
        #else
        return AnyView(self.pickerStyle(.menu))
        #endif
    }
}