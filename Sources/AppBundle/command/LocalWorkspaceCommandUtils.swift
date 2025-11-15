import Common

@MainActor
func requirePerMonitorMode(_ io: CmdIo, commandName: String) -> Bool {
    if config.workspaceIndexingMode == .perMonitor {
        return true
    } else {
        io.err("'\(commandName)' requires workspace_mode = 'per-monitor'")
        return false
    }
}

@MainActor
func resolveLocalWorkspace(slot: Int, monitor: Monitor, io: CmdIo, createIfNeeded: Bool = true) -> Workspace? {
    if slot <= 0 {
        io.err("Slot index must be greater than zero")
        return nil
    }
    if let workspace = WorkspaceLocalIndexing.shared.workspace(at: slot, monitor: monitor) {
        return workspace
    }
    if config.workspaceIndexingMode == .perMonitor, createIfNeeded {
        return WorkspaceLocalIndexing.shared.ensureLocalWorkspace(slot: slot, monitor: monitor)
    }
    io.err("Can't resolve workspace slot \(slot) on monitor '\(monitor.name)'")
    return nil
}

@MainActor
func resolveMonitor(from monitorId: MonitorId, io: CmdIo) -> Monitor? {
    let monitors = monitorId.resolve(io, sortedMonitors: sortedMonitors)
    return monitors.first
}

@MainActor
func resolveMonitor(selection: MonitorSelection, baseMonitor: Monitor, wrapAround: Bool, io: CmdIo) -> Monitor? {
    switch selection {
        case .id(let id):
            return resolveMonitor(from: id, io: io)
        case .target(let target):
            return resolveMonitor(target: target, relativeTo: baseMonitor, wrapAround: wrapAround, io: io)
    }
}

@MainActor
func resolveMonitor(target: MonitorTarget, relativeTo baseMonitor: Monitor, wrapAround: Bool, io: CmdIo) -> Monitor? {
    switch target.resolve(baseMonitor, wrapAround: wrapAround) {
        case .success(let monitor):
            return monitor
        case .failure(let msg):
            io.err(msg)
            return nil
    }
}

@MainActor
func slotsDebugDescription(for monitor: Monitor) -> String {
    let point = monitor.rect.topLeftCorner
    let list = WorkspaceLocalIndexing.shared.slots[point] ?? []
    return list.enumerated().map { "\($0.offset + 1):\(workspaceDebugIdentifier($0.element))" }.joined(separator: ", ")
}

func workspaceDebugIdentifier(_ workspace: Workspace) -> String {
    "\(workspace.name)#\(ObjectIdentifier(workspace).hashValue)"
}

@MainActor
func slotIndex(of workspace: Workspace?, on monitor: Monitor) -> Int? {
    guard let workspace else { return nil }
    return WorkspaceLocalIndexing.shared.index(of: workspace, on: monitor.rect.topLeftCorner).map { $0 + 1 }
}
