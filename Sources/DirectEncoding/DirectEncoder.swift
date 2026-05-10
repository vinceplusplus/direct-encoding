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
    headerLocation = _reserveElement(type: Header.self)
  }
}

public extension DirectEncoder {
  mutating func appendRoot(location: Location) {
    rootElementLocations.append(.init(location))
  }

  consuming func endEncoding() -> Data {
    let memoryPool = MemoryPool()
    var header = Header(
      version: Self.currentVersion,
      rootElementLocations: memoryPool.array(rootElementLocations),
      pointerLocationCount: 0,
      pointerLocationsLocation: .init(byteOffset: 0),
    )
    encodeCompositeElement(header, at: headerLocation)

    // NOTE: these must be encoded last
    header.pointerLocationsLocation = _encodeArray(array: pointerLocations)
    header.pointerLocationCount = pointerLocations.count

    encodeElement(header, at: headerLocation, member: \.pointerLocationCount)
    encodeElement(header, at: headerLocation, member: \.pointerLocationsLocation)

    return data
  }
}

