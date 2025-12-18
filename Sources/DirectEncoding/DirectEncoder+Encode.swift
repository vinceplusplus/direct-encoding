import PointerKit

public extension DirectEncoder {
  @discardableResult
  mutating func encodeElement<T>(
    _ element: T,
    at overwriteLocation: Location? = nil,
    onWritten: OnWritten<T>? = nil,
  ) -> ElementLocation<T> {
    _encodeElement(element, at: overwriteLocation, onWritten: onWritten)
  }
}

public extension DirectEncoder {
  mutating func encodeElementPointer<T>(
    _ elementPointer: Pointer<T>,
    at overwriteLocation: Location? = nil,
    onWritten: OnWritten<T>? = nil,
  ) -> ElementLocation<T>? {
    guard !elementPointer.isNil else { return nil }

    if let location = pointerLocationMap[.init(elementPointer)] {
      return .init(location)
    }

    let location = _encodeElement(
      elementPointer.pointee,
      at: overwriteLocation,
    )

    // NOTE: cache location first, otherwise, infinite looping will occur
    pointerLocationMap[.init(elementPointer)] = location

    onWritten?(&self, elementPointer.pointee, location)

    return location
  }

  @discardableResult
  mutating func encodeArrayPointer<T>(
    start: Pointer<T>,
    count: Int,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    guard !start.isNil else { return nil }

    if let location = pointerLocationMap[.init(start)] {
      return .init(location)
    }

    let location = _encodeArray(
      start: start,
      count: count,
      at: overwriteLocation,
    )

    // NOTE: cache location first, otherwise, infinite looping will occur
    pointerLocationMap[.init(start)] = location
    _processWrittenArrayElements(
      start: start,
      count: count,
      onElementWritten: onElementWritten,
      location: .init(location),
    )

    return location
  }

  @discardableResult
  mutating func encodeArrayPointer<T>(
    buffer: Buffer<T>,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    guard !buffer.start.isNil else { return nil }

    return encodeArrayPointer(
      start: buffer.start,
      count: buffer.count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )
  }
}

