import PointerKit

internal extension DirectEncoder {
  @discardableResult
  mutating func _reserveElement<T>(type: T.Type) -> ElementLocation<T> {
    Buffer<UInt8>.zeros(MemoryLayout<T>.size) {
      .init(_encodeBuffer(
        $0,
        alignment: MemoryLayout<T>.alignment
      ))
    }
  }

  @discardableResult
  mutating func _encodeElement<T>(
    _ element: T,
    at overwriteLocation: Location? = nil,
    onWritten: OnWritten<T>? = nil,
  ) -> ElementLocation<T> {
    let location = withBuffer(element: element) {
      ElementLocation<T>(_encodeBuffer(
        $0,
        alignment: MemoryLayout<T>.alignment,
        at: overwriteLocation,
      ))
    }

    onWritten?(&self, element, location)

    return location
  }
}

