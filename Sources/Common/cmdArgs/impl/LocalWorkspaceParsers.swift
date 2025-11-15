public enum MonitorSelection: Equatable, Sendable {
    case id(MonitorId)
    case target(MonitorTarget)
}

func parseWorkspaceSlot(_ i: ArgParserInput) -> ParsedCliArgs<Int> {
    guard let int = Int(i.arg) else {
        return .fail("Can't parse slot index '\(i.arg)'", advanceBy: 1)
    }
    if int <= 0 {
        return .fail("Slot index must be greater than zero", advanceBy: 1)
    }
    return .succ(int, advanceBy: 1)
}

func parseSingleMonitorId(_ i: ArgParserInput) -> ParsedCliArgs<MonitorId> {
    switch i.arg {
        case "focused":
            return .succ(.focused, advanceBy: 1)
        case "mouse":
            return .succ(.mouse, advanceBy: 1)
        default:
            guard let int = Int(i.arg) else {
                return .fail("Can't parse monitor ID '\(i.arg)'. Possible values: (<monitor-id>|focused|mouse)", advanceBy: 1)
            }
            if int <= 0 {
                return .fail("Monitor IDs start at 1", advanceBy: 1)
            }
            return .succ(.index(int - 1), advanceBy: 1)
    }
}

let monitorSelectionPlaceholder = "(<monitor-id>|focused|mouse|next|prev|left|right|up|down)"

func parseMonitorSelection(_ i: ArgParserInput) -> ParsedCliArgs<MonitorSelection> {
    if let target = parseMonitorTargetToken(i.arg) {
        return .succ(.target(target), advanceBy: 1)
    } else {
        return parseSingleMonitorId(i).map { MonitorSelection.id($0) }
    }
}

private func parseMonitorTargetToken(_ token: String) -> MonitorTarget? {
    switch token {
        case "next": .relative(.next)
        case "prev": .relative(.prev)
        case "left": .direction(.left)
        case "right": .direction(.right)
        case "up": .direction(.up)
        case "down": .direction(.down)
        default: nil
    }
}
