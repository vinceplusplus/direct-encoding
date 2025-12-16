import PointerKit

public class MemoryPool {
  var cleanups: [() -> Void] = []

  public init() {}

  deinit {
    for cleanup in cleanups {
      cleanup()
    }
  }
}

public extension MemoryPool {
  func element<T>(_ value: T) -> Pointer<T> {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)

    pointer.initialize(to: value)

    cleanups.append {
      pointer.deinitialize(count: 1)
      pointer.deallocate()
    }

    return .init(pointer)
  }

  func array<T>(_ array: [T]) -> Buffer<T> {
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: array.count)

    pointer.initialize(from: array, count: array.count)

    let count = array.count

    cleanups.append {
      pointer.deinitialize(count: count)
      pointer.deallocate()
    }

    return .init(start: pointer, count: count)
  }
}

