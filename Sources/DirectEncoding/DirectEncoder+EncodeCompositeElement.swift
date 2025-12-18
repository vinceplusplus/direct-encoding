import PointerKit

public extension DirectEncoder {
  @discardableResult
  mutating func encodeCompositeElement<T: CompositeElement>(
    _ compositeElement: T,
    at overwriteLocation: Location? = nil,
  ) -> ElementLocation<T> {
    let location = _encodeElement(compositeElement, at: overwriteLocation)

    encodeMembers(compositeElement, at: location)

    return location
  }

  @discardableResult
  mutating func encodeCompositeElementPointer<T: CompositeElement>(
    _ compositeElementPointer: Pointer<T>,
    at overwriteLocation: Location? = nil,
  ) -> ElementLocation<T>? {
    guard !compositeElementPointer.isNil else { return nil }

    if let location = pointerLocationMap[.init(compositeElementPointer)] {
      return .init(location)
    }

    let location = _encodeElement(
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

