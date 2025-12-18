import PointerKit

public extension DirectEncoder {
  mutating func resolveElementPointer<T, V>(
    _ elementLocation: ElementLocation<T>,
    member key: KeyPath<T, Pointer<V>>,
    with pointeeLocation: ElementLocation<V>?,
  ) {
    resolvePointer(
      elementLocation,
      member: key,
      with: pointeeLocation,
    )
  }

  mutating func resolveElementPointer<T>(
    _ elementLocation: ElementLocation<Pointer<T>>,
    with pointeeLocation: ElementLocation<T>?,
  ) {
    resolveElementPointer(
      elementLocation,
      member: \.self,
      with: pointeeLocation,
    )
  }

  mutating func resolveArrayPointer<T, V>(
    _ elementLocation: ElementLocation<T>,
    member key: KeyPath<T, Buffer<V>>,
    with pointeeLocation: ArrayLocation<V>?,
  ) {
    resolvePointer(
      elementLocation,
      member: key,
      with: pointeeLocation,
    )
  }

  mutating func resolveArrayPointer<T>(
    _ elementLocation: ElementLocation<Buffer<T>>,
    with pointeeLocation: ArrayLocation<T>?,
  ) {
    resolveArrayPointer(
      elementLocation,
      member: \.self,
      with: pointeeLocation,
    )
  }

  mutating func resolveCompositeElementPointer<T, V: CompositeElement>(
    _ elementLocation: ElementLocation<T>,
    member key: KeyPath<T, Pointer<V>>,
    with pointeeLocation: ElementLocation<V>?,
  ) {
    resolvePointer(
      elementLocation,
      member: key,
      with: pointeeLocation,
    )
  }

  mutating func resolveCompositeElementPointer<T: CompositeElement>(
    _ elementLocation: ElementLocation<Pointer<T>>,
    with pointeeLocation: ElementLocation<T>?,
  ) {
    resolveCompositeElementPointer(
      elementLocation,
      member: \.self,
      with: pointeeLocation,
    )
  }

  mutating func resolvePointer<T, V>(
    _ elementLocation: ElementLocation<T>,
    member key: KeyPath<T, V>,
    with pointeeLocation: Location?,
  ) {
    let memberLocation = elementLocation.memberLocation(of: key)

    resolvePointer(memberLocation, with: pointeeLocation)
  }

  mutating func resolvePointer(
    _ pointerLocation: Location,
    with pointeeLocation: Location?,
  ) {
    guard let pointeeLocation else { return }

    _encodeElement(pointeeLocation.byteOffset, at: pointerLocation)
    pointerLocations.append(.init(pointerLocation))
  }
}

