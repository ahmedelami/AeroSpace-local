public struct MoveNodeToMonitorLocalWorkspaceCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToMonitorLocalWorkspace,
        allowInConfig: true,
        help: move_node_to_monitor_local_workspace_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
            "--wrap-around": trueBoolFlag(\.wrapAround),
        ],
        posArgs: [
            newArgParser(\.monitor, parseMonitorSelection, mandatoryArgPlaceholder: monitorSelectionPlaceholder),
            newArgParser(\.slot, parseWorkspaceSlot, mandatoryArgPlaceholder: "<slot-index>"),
        ]
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var focusFollowsWindow: Bool = false
    public var failIfNoop: Bool = false
    public var wrapAround: Bool = false
    public var monitor: Lateinit<MonitorSelection> = .uninitialized
    public var slot: Lateinit<Int> = .uninitialized
}
