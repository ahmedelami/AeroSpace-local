public struct SwapLocalWorkspacesCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .swapLocalWorkspaces,
        allowInConfig: true,
        help: swap_local_workspaces_help_generated,
        flags: [
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        posArgs: [
            newArgParser(\.firstMonitor, parseMonitorSelection, mandatoryArgPlaceholder: monitorSelectionPlaceholder),
            newArgParser(\.secondMonitor, parseMonitorSelection, mandatoryArgPlaceholder: monitorSelectionPlaceholder),
        ]
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var firstMonitor: Lateinit<MonitorSelection> = .uninitialized
    public var secondMonitor: Lateinit<MonitorSelection> = .uninitialized
    public var wrapAround: Bool = false
}
