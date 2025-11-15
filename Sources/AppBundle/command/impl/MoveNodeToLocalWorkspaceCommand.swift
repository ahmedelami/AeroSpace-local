import Common

struct MoveNodeToLocalWorkspaceCommand: Command {
    let args: MoveNodeToLocalWorkspaceCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache: Bool = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard requirePerMonitorMode(io, commandName: "move-node-to-local-workspace") else { return false }
        guard let target = args.resolveTargetOrReportError(env, io), let window = target.windowOrNil else {
            return false
        }
        guard let monitor = window.nodeMonitor else {
            return io.err(windowIsntPartOfTree(window))
        }
        let originWorkspace = window.nodeWorkspace
        let originSlot = slotIndex(of: originWorkspace, on: monitor)
        guard let workspace = resolveLocalWorkspace(slot: args.slot.val, monitor: monitor, io: io) else {
            return false
        }
        print("[move-node-to-local-workspace] fromMonitor=\(monitor.name) fromSlot=\(originSlot?.description ?? "nil") toSlot=\(args.slot.val) targetWorkspace=\(workspaceDebugIdentifier(workspace)) slotsBefore=[\(slotsDebugDescription(for: monitor))]")
        let result = moveWindowToWorkspace(
            window,
            workspace,
            io,
            focusFollowsWindow: args.focusFollowsWindow,
            failIfNoop: args.failIfNoop,
            slotOverride: args.slot.val
        )
        print("[move-node-to-local-workspace] slotsAfter=\(slotsDebugDescription(for: monitor))")
        return result
    }
}
