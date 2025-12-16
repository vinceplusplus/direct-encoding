import Foundation
import PointerKit

public struct DirectEncoder: ~Copyable {
  var data = Data()
  var pointerLocations: [RawLocation] = []
  var rootElementLocations: [RawLocation] = []
  var headerLocation: ElementLocation<Header> = .init(byteOffset: 0)

  var pointerLocationMap: [Pointer<Void>: Location] = [:]

  public init(minimumCapacity: Int = 0) {
    data.reserveCapacity(minimumCapacity)
    headerLocation = reserveElement(type: Header.self)
  }
}

public extension DirectEncoder {
  @discardableResult
  mutating func reserveElement<T>(type: T.Type) -> ElementLocation<T> {
    Buffer<UInt8>.zeros(MemoryLayout<T>.size) {
      .init(encodeBuffer(
        $0,
        alignment: MemoryLayout<T>.alignment
      ))
    }
  }

  @discardableResult
  mutating func encodeElement<T>(
    _ element: T,
    at overwriteLocation: Location? = nil,
    onWritten: OnWritten<T>? = nil,
  ) -> ElementLocation<T> {
    let location = withBuffer(element: element) {
      ElementLocation<T>(encodeBuffer(
        $0,
        alignment: MemoryLayout<T>.alignment,
        at: overwriteLocation,
      ))
    }

    if let onWritten {
      onWritten(&self, element, location)
    }

    return location
  }

  @discardableResult
  mutating func encodeArray<T>(
    start: Pointer<T>,
    count: Int,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    let location = encodeBuffer(
      .init(Buffer<T>(start: start, count: count)),
      alignment: MemoryLayout<T>.alignment,
      at: overwriteLocation
    )

    if let onElementWritten {
      for i in 0..<count {
        onElementWritten(
          &self,
          start[i],
          .init(byteOffset: location.byteOffset + MemoryLayout<T>.stride * i),
        )
      }
    }

    return .init(location)
  }

  @discardableResult
  mutating func encodeArray<T>(
    buffer: Buffer<T>,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    encodeArray(
      start: buffer.start,
      count: buffer.count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )
  }

  @discardableResult
  mutating func encodeArray<T>(
    array: [T],
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T> {
    withBuffer(array: array) {
      encodeArray(
        buffer: $0,
        at: overwriteLocation,
        onElementWritten: onElementWritten
      )
    }
  }

  mutating func encodeBuffer(
    _ buffer: Buffer<UInt8>,
    alignment: Int,
    at overwriteLocation: Location? = nil,
  ) -> RawLocation {
    if let overwriteLocation {
      data.replaceSubrange(
        overwriteLocation.byteOffset..<overwriteLocation.byteOffset + buffer.count,
        with: buffer.native()
      )

      return .init(overwriteLocation)
    } else {
      pad(alignment: alignment)

      let byteOffset = data.count

      data.append(contentsOf: buffer.native())

      return .init(byteOffset: byteOffset)
    }
  }

  mutating func pad(alignment: Int) {
    let padding = (alignment - (data.count % alignment)) % alignment

    data.append(contentsOf: [UInt8](repeating: 0, count: padding))
  }
}

public extension DirectEncoder {
  @discardableResult
  mutating func encodeCompositeElement<T: CompositeElement>(
    _ compositeElement: T,
    at overwriteLocation: Location? = nil,
  ) -> ElementLocation<T> {
    let location = encodeElement(compositeElement, at: overwriteLocation)

    encodeMembers(compositeElement, at: location)

    return location
  }

  mutating func encodeMembers<T: CompositeElement>(
    _ compositeElement: T,
    at compositeElementLocation: ElementLocation<T>,
  ) {
    compositeElement.encodeMembers(
      at: compositeElementLocation,
      to: &self,
    )
  }

  mutating func encodeMembers<T, V: CompositeElement>(
    _ element: T,
    at elementLocation: ElementLocation<T>,
    member memberKey: KeyPath<T, V>,
  ) {
    let member = element[keyPath: memberKey]
    let memberLocation = elementLocation.memberLocation(of: memberKey)

    return member.encodeMembers(
      at: memberLocation,
      to: &self,
    )
  }
}

public extension DirectEncoder {
  mutating func encodePointedElement<T>(
    _ elementPointer: Pointer<T>,
    at overwriteLocation: Location? = nil,
  ) -> ElementLocation<T>? {
    guard !elementPointer.isNil else { return nil }

    if let location = pointerLocationMap[.init(elementPointer)] {
      return .init(location)
    }

    let location = encodeElement(
      elementPointer.pointee,
      at: overwriteLocation,
    )

    pointerLocationMap[.init(elementPointer)] = location

    return location
  }

  @discardableResult
  mutating func encodePointedArray<T>(
    start: Pointer<T>,
    count: Int,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    guard !start.isNil else { return nil }

    if let location = pointerLocationMap[.init(start)] {
      return .init(location)
    }

    let location = encodeArray(
      start: start,
      count: count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )

    pointerLocationMap[.init(start)] = location

    return location
  }

  @discardableResult
  mutating func encodePointedArray<T>(
    buffer: Buffer<T>,
    at overwriteLocation: Location? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    guard !buffer.start.isNil else { return nil }

    return encodePointedArray(
      start: buffer.start,
      count: buffer.count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )
  }

  @discardableResult
  mutating func encodePointedCompositeElement<T: CompositeElement>(
    _ compositeElementPointer: Pointer<T>,
    at overwriteLocation: Location? = nil,
  ) -> ElementLocation<T>? {
    guard !compositeElementPointer.isNil else { return nil }

    if let location = pointerLocationMap[.init(compositeElementPointer)] {
      return .init(location)
    }

    let location = encodeElement(
      compositeElementPointer.pointee,
      at: overwriteLocation,
    )

    // NOTE: cache location first, otherwise, infinite looping will occur
    pointerLocationMap[.init(compositeElementPointer)] = location
    encodeMembers(compositeElementPointer.pointee, at: location)

    return location
  }
}

public extension DirectEncoder {
  mutating func resolve<T, V>(
    _ compositeElementLocation: ElementLocation<T>,
    member key: KeyPath<T, V>,
    with pointeeLocation: Location?,
  ) {
    guard let pointeeLocation else { return }

    let memberLocation = compositeElementLocation.memberLocation(of: key)

    encodeElement(pointeeLocation.byteOffset, at: memberLocation)
    pointerLocations.append(.init(memberLocation))
  }

  mutating func resolve(
    _ pointerLocation: Location,
    with pointeeLocation: Location,
  ) {
    resolve(
      ElementLocation<Pointer<Void>>(pointerLocation),
      member: \.self,
      with: pointeeLocation,
    )
  }
}

public extension DirectEncoder {
  mutating func appendRoot(location: Location) {
    rootElementLocations.append(.init(location))
  }

  consuming func endEncoding() -> Data {
    let pointerLocationsLocation = encodeArray(array: pointerLocations)
    let rootElementLocationsLocation = encodeArray(array: rootElementLocations)
    let header = Header(
      pointerLocationCount: pointerLocations.count,
      pointerLocationsLocation: pointerLocationsLocation,
      rootElementLocationCount: rootElementLocations.count,
      rootElementLocationsLocation: rootElementLocationsLocation,
    )

    encodeElement(header, at: headerLocation)

    return data
  }
}

