import PointerKit

public struct DirectDecoder: ~Copyable {
  let dataBuffer: Buffer<UInt8>
  let header: DirectEncoder.Header
  let pointerLocations: Buffer<DirectEncoder.RawLocation>
  let rootElementLocations: Buffer<DirectEncoder.RawLocation>

  // NOTE: will consume the data buffer
  public init(consume dataBuffer: Buffer<UInt8>) {
    assert(dataBuffer.count >= MemoryLayout<DirectEncoder.Header>.size)

    self.dataBuffer = dataBuffer
    self.header = Pointer<DirectEncoder.Header>(dataBuffer.start).pointee

    assert(self.header.version == DirectEncoder.currentVersion)

    self.pointerLocations = .init(
      start: dataBuffer.start + header.pointerLocationsLocation.byteOffset,
      count: header.pointerLocationCount,
    )
    self.rootElementLocations = .init(
      start: dataBuffer.start + header.rootElementLocationsLocation.byteOffset,
      count: header.rootElementLocationCount,
    )

    Self.translatePointers(pointerLocations, dataBuffer.start)
  }

  deinit {
    dataBuffer.native().deallocate()
  }

  public func getRootPointer<T>(_ index: Int, _ type: T.Type) -> Pointer<T> {
    .init(dataBuffer.start + rootElementLocations[index].byteOffset)
  }
}

private extension DirectDecoder {
  static func translatePointers(
    _ pointerLocations: Buffer<DirectEncoder.RawLocation>,
    _ startPointer: Pointer<UInt8>,
  ) {
    let startAddress = startPointer.address

    for location in pointerLocations {
      let pointerPointer: Pointer<Pointer<Void>> = .init(startPointer + location.byteOffset)

      pointerPointer.pointee.address += startAddress
    }
  }
}

