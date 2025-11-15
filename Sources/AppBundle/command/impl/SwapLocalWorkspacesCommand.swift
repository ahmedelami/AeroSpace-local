import Common

struct SwapLocalWorkspacesCommand: Command {
    let args: SwapLocalWorkspacesCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        let focusMonitor = focus.workspace.workspaceMonitor
        guard let firstMonitor = resolveMonitor(selection: args.firstMonitor.val, baseMonitor: focusMonitor, wrapAround: args.wrapAround, io: io) else {
            return false
        }
        guard let secondMonitor = resolveMonitor(selection: args.secondMonitor.val, baseMonitor: firstMonitor, wrapAround: args.wrapAround, io: io) else {
            return false
        }
        if firstMonitor.rect.topLeftCorner == secondMonitor.rect.topLeftCorner {
            return true
        }
        let firstWorkspace = firstMonitor.activeWorkspace
        let secondWorkspace = secondMonitor.activeWorkspace
        if firstWorkspace == secondWorkspace {
            return true
        }
        if !secondMonitor.setActiveWorkspace(firstWorkspace) {
            return io.err(
                "Can't move workspace '\(firstWorkspace.name)' to monitor '\(secondMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it"
            )
        }
        if !firstMonitor.setActiveWorkspace(secondWorkspace) {
            _ = secondMonitor.setActiveWorkspace(secondWorkspace)
            _ = firstMonitor.setActiveWorkspace(firstWorkspace)
            return io.err(
                "Can't move workspace '\(secondWorkspace.name)' to monitor '\(firstMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it"
            )
        }
        return true
    }
}
