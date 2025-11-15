import Common

struct MoveNodeToMonitorLocalWorkspaceCommand: Command {
    let args: MoveNodeToMonitorLocalWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard requirePerMonitorMode(io, commandName: "move-node-to-monitor-local-workspace") else { return false }
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else {
            return false
        }
        guard let currentMonitor = window.nodeMonitor else {
            return io.err(windowIsntPartOfTree(window))
        }
        guard let monitor = resolveMonitor(selection: args.monitor.val, baseMonitor: currentMonitor, wrapAround: args.wrapAround, io: io) else {
            return false
        }
        let slot = args.slot.val
        guard let workspace = resolveLocalWorkspace(slot: slot, monitor: monitor, io: io) else { return false }
        print("[move-node-to-monitor-local-workspace] fromMonitor=\(currentMonitor.name) toMonitor=\(monitor.name) toSlot=\(slot) workspace=\(workspaceDebugIdentifier(workspace)) targetSlotsBefore=[\(slotsDebugDescription(for: monitor))]")
        let result = moveWindowToWorkspace(
            window,
            workspace,
            io,
            focusFollowsWindow: args.focusFollowsWindow,
            failIfNoop: args.failIfNoop,
            slotOverride: slot
        )
        print("[move-node-to-monitor-local-workspace] targetSlotsAfter=\(slotsDebugDescription(for: monitor))")
        return result
    }
}
