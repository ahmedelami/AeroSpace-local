import AppKit
import Common

@MainActor private var workspaceNameToWorkspace: [String: Workspace] = [:]

@MainActor private var screenPointToPrevVisibleWorkspace: [CGPoint: String] = [:]
@MainActor private var screenPointToVisibleWorkspace: [CGPoint: Workspace] = [:]
@MainActor private var visibleWorkspaceToScreenPoint: [Workspace: CGPoint] = [:]

@MainActor
final class WorkspaceLocalIndexing {
    static let shared = WorkspaceLocalIndexing()
    var slots: [CGPoint: [Workspace]] = [:]

    func index(of workspace: Workspace, on monitorPoint: CGPoint) -> Int? {
        slots[monitorPoint]?.firstIndex(of: workspace)
    }

    func workspace(at slot: Int, monitorPoint: CGPoint) -> Workspace? {
        guard slot > 0, let list = slots[monitorPoint] else { return nil }
        let index = slot - 1
        return list.indices.contains(index) ? list[index] : nil
    }

    func workspace(at slot: Int, monitor: Monitor) -> Workspace? {
        workspace(at: slot, monitorPoint: monitor.rect.topLeftCorner)
    }

    func ensureLocalWorkspace(slot: Int, monitor: Monitor) -> Workspace {
        let monitorPoint = monitor.rect.topLeftCorner
        let name = localWorkspaceName(for: monitor, slot: slot)
        let workspace = Workspace.get(byName: name)
        workspace.assignedMonitorPoint = monitorPoint
        move(workspace, to: monitorPoint, at: slot)
        return workspace
    }

    private func localWorkspaceName(for monitor: Monitor, slot: Int) -> String {
        "@local-\(monitor.monitorAppKitNsScreenScreensId)-\(slot)"
    }

    func ensureStub(at monitorPoint: CGPoint, slot: Int) {
        var list = slots[monitorPoint] ?? []
        guard list.isEmpty else { return }
        let stub = newStub(excluding: list, at: monitorPoint, slot: slot)
        stub.assignedMonitorPoint = monitorPoint
        list.append(stub)
        slots[monitorPoint] = list
    }

    func move(_ workspace: Workspace, to monitorPoint: CGPoint, at slot: Int?) {
        let previousLocation = remove(workspace)
        workspace.assignedMonitorPoint = monitorPoint
        var list = slots[monitorPoint] ?? []
        if let slot, slot > 0 {
            let desiredIndex = slot - 1
            while list.count < desiredIndex {
                let stub = newStub(excluding: list, at: monitorPoint, slot: list.count + 1)
                stub.assignedMonitorPoint = monitorPoint
                list.append(stub)
            }
            let insertionIndex = min(desiredIndex, list.count)
            list.insert(workspace, at: insertionIndex)
        } else if let previousLocation, previousLocation.0 == monitorPoint {
            let insertionIndex = min(previousLocation.1, list.count)
            list.insert(workspace, at: insertionIndex)
        } else {
            list.append(workspace)
        }
        slots[monitorPoint] = deduplicated(list)
    }

    func handleMonitorTopologyChange(newMonitors: [Monitor]) {
        let oldSlots = slots
        slots = [:]
        var oldPoints = Array(oldSlots.keys)
        var mapping: [CGPoint: CGPoint] = [:]

        for monitor in newMonitors {
            let newPoint = monitor.rect.topLeftCorner
            if let closest = oldPoints.minBy({ ($0 - newPoint).vectorLength }) {
                mapping[newPoint] = closest
                if let idx = oldPoints.firstIndex(of: closest) {
                    oldPoints.remove(at: idx)
                }
            }
        }

        for monitor in newMonitors {
            let newPoint = monitor.rect.topLeftCorner
            if let oldPoint = mapping[newPoint], let list = oldSlots[oldPoint] {
                let reassigned = list.map { workspace in
                    workspace.assignedMonitorPoint = newPoint
                    return workspace
                }
                slots[newPoint] = reassigned
            } else {
                slots[newPoint] = []
                ensureStub(at: newPoint, slot: 1)
            }
        }
    }

    @discardableResult
    private func remove(_ workspace: Workspace) -> (CGPoint, Int)? {
        for (point, list) in slots {
            if let index = list.firstIndex(of: workspace) {
                var updated = list
                updated.remove(at: index)
                if updated.isEmpty {
                    slots.removeValue(forKey: point)
                } else {
                    slots[point] = updated
                }
                return (point, index)
            }
        }
        return nil
    }

    private func newStub(excluding existing: [Workspace], at monitorPoint: CGPoint, slot: Int) -> Workspace {
        if config.workspaceIndexingMode == .perMonitor {
            return ensureLocalWorkspace(slot: slot, monitor: monitorPoint.monitorApproximation)
        }
        if let candidate = Workspace.all
            .first(where: { !$0.isVisible && $0.workspaceMonitor.rect.topLeftCorner == monitorPoint && !existing.contains($0) })
        {
            return candidate
        }
        return getStubWorkspace(forPoint: monitorPoint)
    }

    private func deduplicated(_ workspaces: [Workspace]) -> [Workspace] {
        var seen: Set<Workspace> = []
        return workspaces.filter { workspace in
            if seen.contains(workspace) {
                return false
            } else {
                seen.insert(workspace)
                return true
            }
        }
    }
}

// The returned workspace must be invisible and it must belong to the requested monitor
@MainActor func getStubWorkspace(for monitor: Monitor, preferredSlot: Int? = nil) -> Workspace {
    if config.workspaceIndexingMode == .perMonitor {
        let slot = preferredSlot ?? 1
        return WorkspaceLocalIndexing.shared.ensureLocalWorkspace(slot: slot, monitor: monitor)
    }
    return getStubWorkspace(forPoint: monitor.rect.topLeftCorner)
}

@MainActor
private func getStubWorkspace(forPoint point: CGPoint) -> Workspace {
    if let prev = screenPointToPrevVisibleWorkspace[point].map({ Workspace.get(byName: $0) }),
       !prev.isVisible && prev.workspaceMonitor.rect.topLeftCorner == point && prev.forceAssignedMonitor == nil
    {
        return prev
    }
    if let candidate = Workspace.all
        .first(where: { !$0.isVisible && $0.workspaceMonitor.rect.topLeftCorner == point })
    {
        return candidate
    }
    let preservedNames = config.preservedWorkspaceNames.toSet()
    return (1 ... Int.max).lazy
        .map { Workspace.get(byName: String($0)) }
        .first { $0.isEffectivelyEmpty && !$0.isVisible && !preservedNames.contains($0.name) && $0.forceAssignedMonitor == nil }
        .orDie("Can't create empty workspace")
}

final class Workspace: TreeNode, NonLeafTreeNodeObject, Hashable, Comparable {
    let name: String
    private nonisolated let nameLogicalSegments: StringLogicalSegments
    /// `assignedMonitorPoint` must be interpreted only when the workspace is invisible
    fileprivate var assignedMonitorPoint: CGPoint? = nil

    @MainActor
    private init(_ name: String) {
        self.name = name
        self.nameLogicalSegments = name.toLogicalSegments()
        super.init(parent: NilTreeNode.instance, adaptiveWeight: 0, index: 0)
    }

    @MainActor static var all: [Workspace] {
        workspaceNameToWorkspace.values.sorted()
    }

    @MainActor static func get(byName name: String) -> Workspace {
        if let existing = workspaceNameToWorkspace[name] {
            return existing
        } else {
            let workspace = Workspace(name)
            workspaceNameToWorkspace[name] = workspace
            return workspace
        }
    }

    nonisolated static func < (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.nameLogicalSegments < rhs.nameLogicalSegments
    }

    override func getWeight(_ targetOrientation: Orientation) -> CGFloat {
        workspaceMonitor.visibleRectPaddedByOuterGaps.getDimension(targetOrientation)
    }

    override func setWeight(_ targetOrientation: Orientation, _ newValue: CGFloat) {
        die("It's not possible to change weight of Workspace")
    }

    @MainActor
    var description: String {
        let preservedNames = config.preservedWorkspaceNames.toSet()
        let description = [
            ("name", name),
            ("isVisible", String(isVisible)),
            ("isEffectivelyEmpty", String(isEffectivelyEmpty)),
            ("doKeepAlive", String(preservedNames.contains(name))),
        ].map { "\($0.0): '\(String(describing: $0.1))'" }.joined(separator: ", ")
        return "Workspace(\(description))"
    }

    @MainActor
    static func garbageCollectUnusedWorkspaces() {
        let preservedNames = config.preservedWorkspaceNames.toSet()
        for name in preservedNames {
            _ = get(byName: name) // Make sure that all preserved workspaces are "cached"
        }
        // Keep workspaces referenced by per-monitor slots alive so they aren't recreated
        let slotWorkspaces = WorkspaceLocalIndexing.shared.slots.values.flatMap { $0 }
        workspaceNameToWorkspace = workspaceNameToWorkspace.filter { (_, workspace: Workspace) in
            preservedNames.contains(workspace.name) ||
                !workspace.isEffectivelyEmpty ||
                workspace.isVisible ||
                workspace.name == focus.workspace.name ||
                slotWorkspaces.contains { $0 === workspace }
        }
    }

    nonisolated static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        check((lhs === rhs) == (lhs.name == rhs.name), "lhs: \(lhs) rhs: \(rhs)")
        return lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension Workspace {
    @MainActor
    var isVisible: Bool { visibleWorkspaceToScreenPoint.keys.contains(self) }
    @MainActor
    var workspaceMonitor: Monitor {
        forceAssignedMonitor
            ?? visibleWorkspaceToScreenPoint[self]?.monitorApproximation
            ?? assignedMonitorPoint?.monitorApproximation
            ?? mainMonitor
    }
}

extension Monitor {
    @MainActor
    var activeWorkspace: Workspace {
        if let existing = screenPointToVisibleWorkspace[rect.topLeftCorner] {
            return existing
        }
        // What if monitor configuration changed? (frame.origin is changed)
        rearrangeWorkspacesOnMonitors()
        // Normally, recursion should happen only once more because we must take the value from the cache
        // (Unless, monitor configuration data race happens)
        return self.activeWorkspace
    }

    @MainActor
    func setActiveWorkspace(_ workspace: Workspace, slot: Int? = nil) -> Bool {
        let status = rect.topLeftCorner.setActiveWorkspace(workspace)
        if status {
            WorkspaceLocalIndexing.shared.move(workspace, to: rect.topLeftCorner, at: slot)
        }
        return status
    }
}

@MainActor
func gcMonitors() {
    if screenPointToVisibleWorkspace.count != monitors.count {
        rearrangeWorkspacesOnMonitors()
    }
}

extension CGPoint {
    @MainActor
    fileprivate func setActiveWorkspace(_ workspace: Workspace) -> Bool {
        if !isValidAssignment(workspace: workspace, screen: self) {
            return false
        }
        if let prevMonitorPoint = visibleWorkspaceToScreenPoint[workspace] {
            visibleWorkspaceToScreenPoint.removeValue(forKey: workspace)
            screenPointToPrevVisibleWorkspace[prevMonitorPoint] =
                screenPointToVisibleWorkspace.removeValue(forKey: prevMonitorPoint)?.name
        }
        if let prevWorkspace = screenPointToVisibleWorkspace[self] {
            screenPointToPrevVisibleWorkspace[self] =
                screenPointToVisibleWorkspace.removeValue(forKey: self)?.name
            visibleWorkspaceToScreenPoint.removeValue(forKey: prevWorkspace)
        }
        visibleWorkspaceToScreenPoint[workspace] = self
        screenPointToVisibleWorkspace[self] = workspace
        workspace.assignedMonitorPoint = self
        return true
    }
}

@MainActor
private func rearrangeWorkspacesOnMonitors() {
    var oldVisibleScreens: Set<CGPoint> = screenPointToVisibleWorkspace.keys.toSet()

    let newScreens = monitors.map(\.rect.topLeftCorner)
    var newScreenToOldScreenMapping: [CGPoint: CGPoint] = [:]
    for newScreen in newScreens {
        if let oldScreen = oldVisibleScreens.minBy({ ($0 - newScreen).vectorLength }) {
            check(oldVisibleScreens.remove(oldScreen) != nil)
            newScreenToOldScreenMapping[newScreen] = oldScreen
        }
    }

    let oldScreenPointToVisibleWorkspace = screenPointToVisibleWorkspace
    screenPointToVisibleWorkspace = [:]
    visibleWorkspaceToScreenPoint = [:]

    for newScreen in newScreens {
        if let existingVisibleWorkspace = newScreenToOldScreenMapping[newScreen].flatMap({ oldScreenPointToVisibleWorkspace[$0] }),
           newScreen.setActiveWorkspace(existingVisibleWorkspace)
        {
            continue
        }
        let stubWorkspace = getStubWorkspace(for: newScreen.monitorApproximation)
        check(newScreen.setActiveWorkspace(stubWorkspace),
              "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(newScreen)")
    }
    WorkspaceLocalIndexing.shared.handleMonitorTopologyChange(newMonitors: monitors)
}

@MainActor
private func isValidAssignment(workspace: Workspace, screen: CGPoint) -> Bool {
    if let forceAssigned = workspace.forceAssignedMonitor, forceAssigned.rect.topLeftCorner != screen {
        return false
    } else {
        return true
    }
}
