public struct WorkspaceLocalCmdArgs: CmdArgs {
    public let rawArgsForStrRepr: EquatableNoop<StrArrSlice>
    public init(rawArgs: StrArrSlice) { self.rawArgsForStrRepr = .init(rawArgs) }
    public static let parser: CmdParser<Self> = cmdParser(
        kind: .workspaceLocal,
        allowInConfig: true,
        help: workspace_local_help_generated,
        flags: [:],
        posArgs: [newArgParser(\.slot, parseWorkspaceSlot, mandatoryArgPlaceholder: "<slot-index>")]
    )

    /*conforms*/ public var windowId: UInt32?
    /*conforms*/ public var workspaceName: WorkspaceName?
    public var slot: Lateinit<Int> = .uninitialized
}
