import PointerKit

// NOTE: we only work with 64-bit platforms

// TODO: AndroidAArch64StringMembersEncoder

public struct DefaultStringMembersEncoder {
  public func encodeMembers(
    string: String,
    at compositeElementLocation: DirectEncoder.ElementLocation<String>,
    to encoder: inout DirectEncoder,
  ) {
    let pureString = String(decoding: string.precomposedStringWithCanonicalMapping.utf8, as: UTF8.self)
    let isASCII = pureString.canBeConverted(to: .ascii)
    let codeUnits = Array(pureString.utf8)
    let count = codeUnits.count

    if count < 16 {
      var stringObject = StringObject(countAndFlagsBits: .init(rawValue: 0), object: .init(rawValue: 0))

      withBuffer(array: codeUnits) { buffer in
        buffer.start.copy(toValue: &stringObject, byteCount: count)
      }
      stringObject.object.insert([.immortal, .small])

      if isASCII {
        stringObject.object.insert(.smallASCII)
      }
    } else {
      var stringObject = StringObject(countAndFlagsBits: .init(rawValue: 0), object: .init(rawValue: 0))

      let codeUnitsLocation = withBuffer(array: Array(codeUnits)) {
        encoder._encodeBuffer($0, alignment: 8)
      }
      let biasedCodeUnitsLocation = DirectEncoder.RawLocation(
        byteOffset: ((codeUnitsLocation.byteOffset) &- 32) & 0x00ff_ffff_ffff_ffff,
      )

      stringObject.object = .init(rawValue: .init(bitPattern: biasedCodeUnitsLocation.byteOffset))
      stringObject.object.remove(.topByteMask)
      stringObject.object.insert(.immortal)

      stringObject.countAndFlagsBits = .init(rawValue: .init(bitPattern: count))
      stringObject.countAndFlagsBits.remove(.topByteMask)
      stringObject.countAndFlagsBits.insert([.nfc, .tailAllocated])

      if isASCII {
        stringObject.countAndFlagsBits.insert(.ascii)
      }

      let stringObjectLocation = encoder.encodeElement(
        stringObject,
        at: .init(compositeElementLocation),
      )

      encoder.resolvePointer(
        stringObjectLocation,
        member: \.object,
      )
    }
  }
}

extension DefaultStringMembersEncoder {
  struct StringObject {
    var countAndFlagsBits: CountAndFlagsBits
    var object: Object
  }
}

extension DefaultStringMembersEncoder.StringObject {
  struct CountAndFlagsBits: OptionSet {
    let rawValue: UInt

    static let topByteMask = CountAndFlagsBits(rawValue: 0xff00_0000_0000_0000)
    static let ascii = CountAndFlagsBits(rawValue: 1 << 63)
    static let nfc = CountAndFlagsBits(rawValue: 1 << 62)
    static let tailAllocated = CountAndFlagsBits(rawValue: 1 << 60)
  }
  struct Object: OptionSet {
    let rawValue: UInt

    static let topByteMask = Object(rawValue: 0xff00_0000_0000_0000)
    static let immortal = Object(rawValue: 1 << 63)
    static let smallASCII = Object(rawValue: 1 << 62)
    static let small = Object(rawValue: 1 << 61)
  }
}

extension String: DirectEncoder.CompositeElement {
  public func encodeMembers(
    at compositeElementLocation: DirectEncoder.ElementLocation<String>,
    to encoder: inout DirectEncoder,
  ) {
    DefaultStringMembersEncoder().encodeMembers(
      string: self,
      at: compositeElementLocation,
      to: &encoder,
    )
  }
}
