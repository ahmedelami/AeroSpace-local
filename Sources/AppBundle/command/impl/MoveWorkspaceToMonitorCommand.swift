import AppKit
import Common

struct MoveWorkspaceToMonitorCommand: Command {
    let args: MoveWorkspaceToMonitorCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool {
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let focusedWorkspace = target.workspace
        let prevMonitor = focusedWorkspace.workspaceMonitor
        let prevSlot = WorkspaceLocalIndexing.shared.index(of: focusedWorkspace, on: prevMonitor.rect.topLeftCorner).map { $0 + 1 }

        switch args.target.val.resolve(target.workspace.workspaceMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                if targetMonitor.monitorId == prevMonitor.monitorId {
                    return true
                }
                if targetMonitor.setActiveWorkspace(focusedWorkspace, slot: prevSlot) {
                    let stubWorkspace = getStubWorkspace(for: prevMonitor, preferredSlot: prevSlot)
                    check(
                        prevMonitor.setActiveWorkspace(stubWorkspace, slot: prevSlot),
                        "getStubWorkspace generated incompatible stub workspace (\(stubWorkspace)) for the monitor (\(prevMonitor)",
                    )
                    return true
                } else {
                    return io.err(
                        "Can't move workspace '\(focusedWorkspace.name)' to monitor '\(targetMonitor.name)'. workspace-to-monitor-force-assignment doesn't allow it",
                    )
                }
            case .failure(let msg):
                return io.err(msg)
        }
    }
}
