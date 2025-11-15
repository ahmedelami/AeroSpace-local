public struct MoveNodeToLocalWorkspaceCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .moveNodeToLocalWorkspace,
        allowInConfig: true,
        help: move_node_to_local_workspace_help_generated,
        flags: [
            "--window-id": optionalWindowIdFlag(),
            "--focus-follows-window": trueBoolFlag(\.focusFollowsWindow),
            "--fail-if-noop": trueBoolFlag(\.failIfNoop),
        ],
        posArgs: [newArgParser(\.slot, parseWorkspaceSlot, mandatoryArgPlaceholder: "<slot-index>")]
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var focusFollowsWindow: Bool = false
    public var failIfNoop: Bool = false
    public var slot: Lateinit<Int> = .uninitialized
}
