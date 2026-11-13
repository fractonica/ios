import CFractonica

/// The one place that talks to the core's text functions.
///
/// Every `frc_format_*` writes UTF-8 into a caller buffer and returns the
/// number of bytes written, or a negative `frc_status_t`. This helper owns the
/// buffer (on the stack, no heap), turns the bytes into a `String` and the
/// negative convention into a thrown ``FractonicaError``.
enum CoreText {
    /// The signature every wrapper adapts a core text function to:
    /// `(buffer, size) -> bytes written or negative status`.
    typealias Writer = (UnsafeMutablePointer<CChar>?, Int) -> Int32

    /// Buffer sizes tried in order. Every text the core writes fits the first
    /// but P with its factors (`FRC_PREFIX_FACTORS_SIZE`, 429 bytes), whose
    /// wrapper asks for that much; the second size exists so that a longer
    /// text in a later core version still comes out whole.
    private static let capacities = [256, 4096]

    /// The text a core function writes.
    /// - Throws: the ``FractonicaError`` of a negative return value.
    /// - Parameter minimumCapacity: for the one function whose output grows
    ///   with its input (`frc_to_ascii`): a buffer at least this large.
    static func make(minimumCapacity: Int = 0, _ write: Writer) throws -> String {
        for capacity in capacities.map({ max($0, minimumCapacity) }) {
            let outcome: Result<String, FractonicaError> = withUnsafeTemporaryAllocation(
                of: CChar.self, capacity: capacity
            ) { buffer in
                let written = write(buffer.baseAddress, capacity)
                if written < 0 {
                    return .failure(FractonicaError(code: written))
                }
                let bytes = UnsafeRawBufferPointer(start: buffer.baseAddress, count: Int(written))
                return .success(String(decoding: bytes, as: UTF8.self))
            }
            switch outcome {
            case .success(let text): return text
            case .failure(.bufferTooSmall): continue
            case .failure(let error): throw error
            }
        }
        throw FractonicaError.bufferTooSmall
    }

    /// The same for calls whose arguments the Swift types already make valid
    /// (a ``Unit`` is always a `frc_unit_t`, a ``Level`` is always 0...62), so
    /// the core cannot refuse them. Should it refuse anyway, that is a bug:
    /// debug builds stop, release builds show nothing rather than crash.
    static func infallible(minimumCapacity: Int = 0, _ write: Writer) -> String {
        do {
            return try make(minimumCapacity: minimumCapacity, write)
        } catch {
            assertionFailure("core text function failed on type-checked arguments: \(error)")
            return ""
        }
    }
}

/// Reads a fixed C array (imported into Swift as a homogeneous tuple) as a
/// Swift array, e.g. `frc_odometer_t.digit` or `frc_glyph_t.trit`.
func arrayOfTuple<Tuple, Element>(_ tuple: Tuple, of _: Element.Type) -> [Element] {
    withUnsafeBytes(of: tuple) { Array($0.bindMemory(to: Element.self)) }
}
