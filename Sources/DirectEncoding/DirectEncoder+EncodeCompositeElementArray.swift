import PointerKit

public extension DirectEncoder {
  @discardableResult
  mutating func encodeCompositeElementArrayPointer<T: CompositeElement>(
    start: Pointer<T>,
    count: Int,
    at overwriteLocation: ArrayLocation<T>? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    encodeArrayPointer(
      start: start,
      count: count,
      at: overwriteLocation,
    ) { encoder, child, childLocation in
      encoder.encodeMembers(child, at: childLocation)
      onElementWritten?(&encoder, child, childLocation)
    }
  }

  @discardableResult
  mutating func encodeCompositeElementArrayPointer<T: CompositeElement>(
    buffer: Buffer<T>,
    at overwriteLocation: ArrayLocation<T>? = nil,
    onElementWritten: OnElementWritten<T>? = nil,
  ) -> ArrayLocation<T>? {
    encodeCompositeElementArrayPointer(
      start: buffer.start,
      count: buffer.count,
      at: overwriteLocation,
      onElementWritten: onElementWritten,
    )
  }
}

