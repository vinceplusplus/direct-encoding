import PointerKit

internal extension DirectEncoder {
  mutating func _encodeBuffer(
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
      _pad(alignment: alignment)

      let byteOffset = data.count

      data.append(contentsOf: buffer.native())

      return .init(byteOffset: byteOffset)
    }
  }

  mutating func _pad(alignment: Int) {
    let padding = (alignment - (data.count % alignment)) % alignment

    data.append(contentsOf: [UInt8](repeating: 0, count: padding))
  }
}

