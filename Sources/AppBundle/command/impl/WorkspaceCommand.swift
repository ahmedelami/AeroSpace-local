import AppKit
import Common
import Foundation

struct WorkspaceCommand: Command {
    let args: WorkspaceCmdArgs
    /*conforms*/ var shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> Bool { // todo refactor
        guard let target = args.resolveTargetOrReportError(env, io) else { return false }
        let focusedWs = target.workspace
        let workspaceName: String
        switch args.target.val {
            case .relative(let nextPrev):
                let workspace = getNextPrevWorkspace(
                    current: focusedWs,
                    isNext: nextPrev == .next,
                    wrapAround: args.wrapAround,
                    stdin: args.useStdin ? io.readStdin() : nil,
                    target: target,
                )
                guard let workspace else { return false }
                workspaceName = workspace.name
            case .direct(let name):
                workspaceName = name.raw
                if args.autoBackAndForth && focusedWs.name == workspaceName {
                    return WorkspaceBackAndForthCommand(args: WorkspaceBackAndForthCmdArgs(rawArgs: [])).run(env, io)
                }
        }
        if focusedWs.name == workspaceName {
            io.err("Workspace '\(workspaceName)' is already focused. Tip: use --fail-if-noop to exit with non-zero code")
            return !args.failIfNoop
        } else {
            return Workspace.get(byName: workspaceName).focusWorkspace()
        }
    }
}

@MainActor func getNextPrevWorkspace(current: Workspace, isNext: Bool, wrapAround: Bool, stdin: String?, target: LiveFocus) -> Workspace? {
    let stdinWorkspaces: [String] = stdin?.split(separator: "\n").map { String($0).trim() }.filter { !$0.isEmpty } ?? []
    let currentMonitor = current.workspaceMonitor
    let workspaces: [Workspace]
    if stdin != nil {
        workspaces = stdinWorkspaces.map { Workspace.get(byName: $0) }
    } else {
        let monitorPoint = currentMonitor.rect.topLeftCorner
        if config.workspaceIndexingMode == .perMonitor,
           let slots = WorkspaceLocalIndexing.shared.slots[monitorPoint],
           !slots.isEmpty
        {
            var ordered: [Workspace] = []
            var seen: Set<Workspace> = []
            for workspace in slots where workspace.workspaceMonitor.rect.topLeftCorner == monitorPoint {
                if seen.insert(workspace).inserted {
                    ordered.append(workspace)
                }
            }
            let additional = Workspace.all
                .filter { $0.workspaceMonitor.rect.topLeftCorner == monitorPoint && !seen.contains($0) }
                .sorted()
            ordered.append(contentsOf: additional)
            if seen.insert(current).inserted {
                ordered.append(current)
            }
            workspaces = ordered
        } else {
            workspaces = Workspace.all.filter { $0.workspaceMonitor.rect.topLeftCorner == monitorPoint }
                .toSet()
                .union([current])
                .sorted()
        }
    }
    let index = workspaces.firstIndex(where: { $0 == target.workspace }) ?? 0
    let workspace: Workspace? = if wrapAround {
        workspaces.get(wrappingIndex: isNext ? index + 1 : index - 1)
    } else {
        workspaces.getOrNil(atIndex: isNext ? index + 1 : index - 1)
    }
    return workspace
}
