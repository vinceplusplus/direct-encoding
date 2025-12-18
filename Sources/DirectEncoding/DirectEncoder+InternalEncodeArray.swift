import PointerKit

internal extension DirectEncoder {
  @discardableResult
  mutating func _encodeArray<T>(
    start: Pointer<T>,
    count: Int,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    let location = _encodeBuffer(
      .init(Buffer<T>(start: start, count: count)),
      alignment: MemoryLayout<T>.alignment,
      at: overwriteLocation
    )

    _processWrittenArrayElements(
      start: start,
      count: count,
      onElementWritten: onElementWritten,
      location: location,
    )

    return .init(location)
  }

  @discardableResult
  mutating func _encodeArray<T>(
    buffer: Buffer<T>,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    _encodeArray(
      start: buffer.start,
      count: buffer.count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )
  }

  @discardableResult
  mutating func _encodeArray<T>(
    array: [T],
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    withBuffer(array: array) {
      _encodeArray(
        buffer: $0,
        at: overwriteLocation,
        onElementWritten: onElementWritten
      )
    }
  }
}

internal extension DirectEncoder {
  mutating func _processWrittenArrayElements<T>(
    start: Pointer<T>,
    count: Int,
    onElementWritten: OnElementWritten<T>?,
    location: RawLocation,
  ) {
    guard let onElementWritten else { return }

    for i in 0..<count {
      onElementWritten(
        &self,
        start[i],
        .init(byteOffset: location.byteOffset + MemoryLayout<T>.stride * i),
      )
    }
  }
}

