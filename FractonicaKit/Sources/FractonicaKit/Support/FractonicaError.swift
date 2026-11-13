import CFractonica

/// Why a core call did not answer. Mirrors `frc_status_t` one to one
/// (`FRC_OK` is "no error" and never becomes a value of this type).
///
/// The one the app meets in normal use is ``outOfRange``: the clock is defined
/// on the catalogue only and never extrapolates (SPEC §2.2). Catch it and show
/// the out-of-catalogue state (design/README.md, ruling 7).
public enum FractonicaError: Error, Hashable, Sendable, CustomStringConvertible {
    /// `FRC_ERR_RANGE`: the instant, cycle, sync or date is outside the catalogue.
    case outOfRange
    /// `FRC_ERR_ARG`: an argument the core refuses (a level above the clock's
    /// deepest, a stroke count outside 1...5, a date field outside its range).
    case invalidArgument
    /// `FRC_ERR_OVERFLOW`: the exact result does not fit the return type.
    case overflow
    /// `FRC_ERR_BUFFER`: a text buffer was too small. The kit sizes its own
    /// buffers, so this reaching a caller is a bug in the kit.
    case bufferTooSmall
    /// `FRC_ERR_PARSE`: the text is not a date or stamp.
    case unparsable
    /// `FRC_ERR_REFUSED`: a device cannot make this rung (SPEC §16.4).
    case refused
    /// A status this version of the kit does not know (a newer core).
    case unknown(Int32)

    /// The error of a negative `frc_status_t` or of a negative text length.
    init(code: Int32) {
        switch code {
        case FRC_ERR_RANGE.rawValue: self = .outOfRange
        case FRC_ERR_ARG.rawValue: self = .invalidArgument
        case FRC_ERR_OVERFLOW.rawValue: self = .overflow
        case FRC_ERR_BUFFER.rawValue: self = .bufferTooSmall
        case FRC_ERR_PARSE.rawValue: self = .unparsable
        case FRC_ERR_REFUSED.rawValue: self = .refused
        default: self = .unknown(code)
        }
    }

    /// The `frc_status_t` value this error stands for.
    public var statusCode: Int32 {
        switch self {
        case .outOfRange: return FRC_ERR_RANGE.rawValue
        case .invalidArgument: return FRC_ERR_ARG.rawValue
        case .overflow: return FRC_ERR_OVERFLOW.rawValue
        case .bufferTooSmall: return FRC_ERR_BUFFER.rawValue
        case .unparsable: return FRC_ERR_PARSE.rawValue
        case .refused: return FRC_ERR_REFUSED.rawValue
        case .unknown(let code): return code
        }
    }

    /// A developer-facing name (for logs; never shown to a user).
    public var description: String {
        switch self {
        case .outOfRange: return "FractonicaError.outOfRange (FRC_ERR_RANGE)"
        case .invalidArgument: return "FractonicaError.invalidArgument (FRC_ERR_ARG)"
        case .overflow: return "FractonicaError.overflow (FRC_ERR_OVERFLOW)"
        case .bufferTooSmall: return "FractonicaError.bufferTooSmall (FRC_ERR_BUFFER)"
        case .unparsable: return "FractonicaError.unparsable (FRC_ERR_PARSE)"
        case .refused: return "FractonicaError.refused (FRC_ERR_REFUSED)"
        case .unknown(let code): return "FractonicaError.unknown(\(code))"
        }
    }
}

/// Throws the ``FractonicaError`` of a status that is not `FRC_OK`.
/// Every wrapper of a `frc_status_t` function goes through here.
@inline(__always)
func check(_ status: frc_status_t) throws {
    if status != FRC_OK {
        throw FractonicaError(code: status.rawValue)
    }
}
