/// Matched geometry hero transition for book covers.
/// Uses SwiftUI's matchedGeometryEffect to animate the cover image
/// from a grid/list position to the detail view hero position.

import SwiftUI

// MARK: - Namespace Environment Key

struct CoverTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var coverTransitionNamespace: Namespace.ID? {
        get { self[CoverTransitionNamespaceKey.self] }
        set { self[CoverTransitionNamespaceKey.self] = newValue }
    }
}

// MARK: - Transition Source Modifier

extension View {
    /// Marks this view as the source of a cover hero transition.
    func coverTransitionSource(id: UUID, namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: "cover-\(id)", in: namespace, isSource: true)
    }

    /// Marks this view as the destination of a cover hero transition.
    func coverTransitionDestination(id: UUID, namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: "cover-\(id)", in: namespace, isSource: false)
    }
}
