import PointerKit

public extension DirectEncoder {
  static let currentVersion: Int = 3

  protocol Location {
    var byteOffset: Int { get }
  }

  struct RawLocation: Location {
    public let byteOffset: Int
  }

  struct ElementLocation<T>: Location {
    public let byteOffset: Int
  }

  struct ArrayLocation<T>: Location {
    public let byteOffset: Int
  }

  protocol CompositeElement {
    func encodeMembers(
      at compositeElementLocation: ElementLocation<Self>,
      to encoder: inout DirectEncoder,
    )
  }

  struct Header: CompositeElement {
    let version: Int = DirectEncoder.currentVersion
    var rootElementLocations: Buffer<RawLocation>

    // NOTE: these must be encoded last and are the only ones to be taken care of in a special way
    var pointerLocationCount: Int
    var pointerLocationsLocation: ArrayLocation<RawLocation>

    public func encodeMembers(
      at compositeElementLocation: ElementLocation<Header>,
      to encoder: inout DirectEncoder,
    ) {
      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.rootElementLocations,
        with: encoder.encodeArrayPointer(buffer: rootElementLocations),
      )
    }
  }

  // NOTE: the inout DirectEncoder to work around weird escaping closure error or overlapping accesses error
  typealias OnWritten<T> = (inout DirectEncoder, T, ElementLocation<T>) -> Void

  // NOTE: the inout DirectEncoder to work around weird escaping closure error or overlapping accesses error
  typealias OnElementWritten<T> = (inout DirectEncoder, T, ElementLocation<T>) -> Void
}

public extension DirectEncoder.RawLocation {
  init(_ location: some DirectEncoder.Location) {
    byteOffset = location.byteOffset
  }
}

public extension DirectEncoder.ElementLocation {
  init(_ location: some DirectEncoder.Location) {
    byteOffset = location.byteOffset
  }

  func memberLocation<V>(of key: KeyPath<T, V>) -> DirectEncoder.ElementLocation<V> {
    .init(byteOffset: byteOffset + MemoryLayout<T>.offset(of: key)!)
  }
}

public extension DirectEncoder.ArrayLocation {
  init(_ location: some DirectEncoder.Location) {
    byteOffset = location.byteOffset
  }
}

