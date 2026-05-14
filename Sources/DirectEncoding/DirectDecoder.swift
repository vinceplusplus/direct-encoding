import PointerKit
import System

public struct DirectDecoder: ~Copyable {
  let dataBuffer: Buffer<UInt8>
  let headerPointer: Pointer<DirectEncoder.Header>
  let pointerLocations: Buffer<DirectEncoder.RawLocation>

  // NOTE: will consume the data buffer
  public init(consume dataBuffer: Buffer<UInt8>) {
    assert(dataBuffer.count >= MemoryLayout<DirectEncoder.Header>.size)

    self.dataBuffer = dataBuffer
    self.headerPointer = Pointer<DirectEncoder.Header>(dataBuffer.start)

    assert(self.headerPointer.pointee.version == DirectEncoder.currentVersion)

    self.pointerLocations = .init(
      start: dataBuffer.start + headerPointer.pointee.pointerLocationsLocation.byteOffset,
      count: headerPointer.pointee.pointerLocationCount,
    )

    Self.translatePointers(pointerLocations, dataBuffer.start)
  }

  public init(contentsOfFile filePath: String) throws {
    let fd = try FileDescriptor.open(FilePath(filePath), .readOnly)

    defer {
      try? fd.close()
    }

    let fileSize = Int(try fd.seek(offset: 0, from: .end))
    let nativeBufferPointer = UnsafeMutableRawBufferPointer.allocate(byteCount: fileSize, alignment: 128)

    try fd.seek(offset: 0, from: .start)
    _ = try fd.read(into: nativeBufferPointer)

    let buffer = Buffer<UInt8>(nativeBufferPointer)

    self.init(consume: buffer)
  }

  deinit {
    dataBuffer.native().deallocate()
  }

  public func getRootPointer<T>(_ index: Int, _ type: T.Type) -> Pointer<T> {
    .init(dataBuffer.start + headerPointer.pointee.rootElementLocations[index].byteOffset)
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

