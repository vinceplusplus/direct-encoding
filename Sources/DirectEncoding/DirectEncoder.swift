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
    let pointerLocationsLocation = _encodeArray(array: pointerLocations)
    let rootElementLocationsLocation = _encodeArray(array: rootElementLocations)
    let header = Header(
      pointerLocationCount: pointerLocations.count,
      pointerLocationsLocation: pointerLocationsLocation,
      rootElementLocationCount: rootElementLocations.count,
      rootElementLocationsLocation: rootElementLocationsLocation,
    )

    _encodeElement(header, at: headerLocation)

    return data
  }
}

