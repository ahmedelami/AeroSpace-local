import Common

struct WorkspaceLocalCommand: Command {
    let args: WorkspaceLocalCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard requirePerMonitorMode(io, commandName: "workspace-local") else { return false }
        let slot = args.slot.val
        let monitor = focus.workspace.workspaceMonitor
        guard let workspace = resolveLocalWorkspace(slot: slot, monitor: monitor, io: io) else { return false }
        print("[workspace-local] monitor=\(monitor.name) point=\(monitor.rect.topLeftCorner) slot=\(slot) workspace=\(workspaceDebugIdentifier(workspace)) slots=[\(slotsDebugDescription(for: monitor))]")
        return setFocus(to: workspace.toLiveFocus(), slotOverride: slot)
    }
}
