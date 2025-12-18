import Testing
@testable import DirectEncoding
import PointerKit

@Test func arrayChildren() {
  struct Node {
    var children: [Node] = []
    var value: Int64 = 0
  }

  struct DirectNode: DirectEncoder.CompositeElement {
    let children: Buffer<DirectNode>
    var value: Int64

    init(node: Node, memoryPool: MemoryPool) {
      children = memoryPool.array(node.children.map { childNode in
        DirectNode(node: childNode, memoryPool: memoryPool)
      })
      value = node.value
    }

    func encodeMembers(
      at compositeElementLocation: DirectEncoder.ElementLocation<DirectNode>,
      to encoder: inout DirectEncoder
    ) {
      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.children,
        with: encoder.encodeArrayPointer(buffer: children) { encoder, child, childLocation in
          encoder.encodeMembers(
            child,
            at: childLocation,
          )
        },
      )
    }
  }

  let memoryPool = MemoryPool()
  var root = Node()

  root.value = 1
  root.children.append(.init())
  root.children.append(.init())
  root.children[0].value = 2
  root.children[1].value = 3
  root.children[0].children.append(.init())
  root.children[0].children.append(.init())
  root.children[0].children[0].value = 4
  root.children[0].children[1].value = 5

  var directRoot = DirectNode(node: root, memoryPool: memoryPool)

  var encoder = DirectEncoder()

  encoder.appendRoot(location: encoder.encodeCompositeElement(directRoot))

  let data = encoder.endEncoding()

  // change original after encoding to make sure decoded content doesn't accidentally reuse pointers
  directRoot.value = 6
  directRoot.children[0].value = 7
  directRoot.children[1].value = 8
  directRoot.children[0].children[0].value = 9
  directRoot.children[0].children[1].value = 10

  let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

  data.copyBytes(to: dataBuffer, count: data.count)

  let directDecoder = DirectDecoder(consume: .init(start: dataBuffer, count: data.count))

  let loadedDirectRoot = directDecoder.getRootPointer(0, DirectNode.self).pointee

  #expect(loadedDirectRoot.value == 1)
  #expect(loadedDirectRoot.children[0].value == 2)
  #expect(loadedDirectRoot.children[1].value == 3)
  #expect(loadedDirectRoot.children[0].children[0].value == 4)
  #expect(loadedDirectRoot.children[0].children[1].value == 5)
}

@Test func mapLikeChildren() {
  struct Node {
    var children: [UInt32: Node] = [:]
    var value: Int64 = 0
  }

  struct DirectNode: DirectEncoder.CompositeElement {
    let children: Buffer<Child>
    let value: Int64

    struct Child {
      let key: UInt32
      let node: DirectNode
    }

    init(node: Node, memoryPool: MemoryPool) {
      children = memoryPool.array(
        node.children
          .sorted { $0.key < $1.key }
          .map { key, childNode in
              .init(
                key: key,
                node: DirectNode(node: childNode, memoryPool: memoryPool),
              )
          },
      )
      value = node.value
    }

    func encodeMembers(
      at compositeElementLocation: DirectEncoder.ElementLocation<DirectNode>,
      to encoder: inout DirectEncoder
    ) {
      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.children,
        with: encoder.encodeArrayPointer(buffer: children) { encoder, child, childLocation in
          encoder.encodeMembers(
            child,
            at: childLocation,
            member: \.node,
          )
        },
      )
    }
  }

  let memoryPool = MemoryPool()
  var root = Node()

  root.value = 1
  root.children[3] = .init()
  root.children[2] = .init()
  root.children[3]?.value = 5
  root.children[2]?.value = 4

  let directRoot = DirectNode(node: root, memoryPool: memoryPool)

  var encoder = DirectEncoder()

  encoder.appendRoot(location: encoder.encodeCompositeElement(directRoot))

  let data = encoder.endEncoding()

  // change original after encoding to make sure decoded content doesn't accidentally reuse pointers
  root.value = 4
  root.children[2]?.value = 6
  root.children[3]?.value = 7

  let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

  data.copyBytes(to: dataBuffer, count: data.count)

  let directDecoder = DirectDecoder(consume: .init(start: dataBuffer, count: data.count))

  let loadedDirectRoot = directDecoder.getRootPointer(0, DirectNode.self).pointee

  #expect(loadedDirectRoot.value == 1)
  #expect(loadedDirectRoot.children[0].key == 2)
  #expect(loadedDirectRoot.children[0].node.value == 4)
  #expect(loadedDirectRoot.children[1].key == 3)
  #expect(loadedDirectRoot.children[1].node.value == 5)
}

@Test func sharedReferences() {
  struct DirectNode: DirectEncoder.CompositeElement {
    var childA: Pointer<DirectNode> = .nil
    var childB: Pointer<DirectNode> = .nil
    var value: Int64 = 0

    func encodeMembers(
      at compositeElementLocation: DirectEncoder.ElementLocation<DirectNode>,
      to encoder: inout DirectEncoder
    ) {
      encoder.resolveCompositeElementPointer(
        compositeElementLocation,
        member: \.childA,
        with: encoder.encodeCompositeElementPointer(childA),
      )
      encoder.resolveCompositeElementPointer(
        compositeElementLocation,
        member: \.childB,
        with: encoder.encodeCompositeElementPointer(childB),
      )
    }
  }

  let memoryPool = MemoryPool()

  var root = DirectNode()

  root.value = 2
  root.childA = memoryPool.element(DirectNode())
  root.childB = memoryPool.element(DirectNode())
  root.childA.pointee.value = 3
  root.childB.pointee.value = 4
  root.childA.pointee.childA = memoryPool.element(DirectNode())
  root.childA.pointee.childB = memoryPool.element(DirectNode())
  root.childA.pointee.childA.pointee.value = 5
  root.childA.pointee.childB.pointee.value = 6
  root.childB.pointee.childA = root.childA.pointee.childA
  root.childB.pointee.childB = root.childA.pointee.childB

  var encoder = DirectEncoder()

  encoder.appendRoot(location: encoder.encodeCompositeElement(root))

  let data = encoder.endEncoding()

  // change original after encoding to make sure decoded content doesn't accidentally reuse pointers
  root.value = 7
  root.childA.pointee.value = 8
  root.childB.pointee.value = 9
  root.childA.pointee.childA.pointee.value = 10
  root.childA.pointee.childB.pointee.value = 11

  let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

  data.copyBytes(to: dataBuffer, count: data.count)

  let directDecoder = DirectDecoder(consume: .init(start: dataBuffer, count: data.count))

  let loadedDirectRoot = directDecoder.getRootPointer(0, DirectNode.self).pointee

  #expect(loadedDirectRoot.value == 2)
  #expect(loadedDirectRoot.childA.pointee.value == 3)
  #expect(loadedDirectRoot.childB.pointee.value == 4)
  #expect(loadedDirectRoot.childA.pointee.childA.pointee.value == 5)
  #expect(loadedDirectRoot.childA.pointee.childB.pointee.value == 6)
  #expect(loadedDirectRoot.childB.pointee.childA.pointee.value == 5)
  #expect(loadedDirectRoot.childB.pointee.childB.pointee.value == 6)

  loadedDirectRoot.childA.pointee.childA.pointee.value += 1
  loadedDirectRoot.childA.pointee.childB.pointee.value += 1
  #expect(loadedDirectRoot.childA.pointee.childA.pointee.value == 6)
  #expect(loadedDirectRoot.childA.pointee.childB.pointee.value == 7)
  #expect(loadedDirectRoot.childB.pointee.childA.pointee.value == 6)
  #expect(loadedDirectRoot.childB.pointee.childB.pointee.value == 7)
  loadedDirectRoot.childB.pointee.childA.pointee.value += 1
  loadedDirectRoot.childB.pointee.childB.pointee.value += 1
  #expect(loadedDirectRoot.childA.pointee.childA.pointee.value == 7)
  #expect(loadedDirectRoot.childA.pointee.childB.pointee.value == 8)
  #expect(loadedDirectRoot.childB.pointee.childA.pointee.value == 7)
  #expect(loadedDirectRoot.childB.pointee.childB.pointee.value == 8)
}

@Test func cyclicReferences() {
  struct DirectNode: DirectEncoder.CompositeElement {
    var child: Pointer<DirectNode> = .nil
    var value: Int64 = 0

    func encodeMembers(
      at compositeElementLocation: DirectEncoder.ElementLocation<DirectNode>,
      to encoder: inout DirectEncoder
    ) {
      encoder.resolveCompositeElementPointer(
        compositeElementLocation,
        member: \.child,
        with: encoder.encodeCompositeElementPointer(child),
      )
    }
  }

  let memoryPool = MemoryPool()

  var root = DirectNode()

  root.value = 2
  root.child = memoryPool.element(DirectNode())
  root.child.pointee.value = 42
  root.child.pointee.child = root.child

  var encoder = DirectEncoder()

  encoder.appendRoot(location: encoder.encodeCompositeElement(root))

  let data = encoder.endEncoding()

  // change original after encoding to make sure decoded content doesn't accidentally reuse pointers
  root.value = 3
  root.child.pointee.value = 43

  let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

  data.copyBytes(to: dataBuffer, count: data.count)

  let directDecoder = DirectDecoder(consume: .init(start: dataBuffer, count: data.count))

  let loadedDirectRoot = directDecoder.getRootPointer(0, DirectNode.self).pointee

  #expect(loadedDirectRoot.value == 2)
  #expect(loadedDirectRoot.child.pointee.value == 42)
  #expect(loadedDirectRoot.child.pointee.child.pointee.value == 42)
  #expect(loadedDirectRoot.child.pointee.child.pointee.child.pointee.value == 42)

  loadedDirectRoot.child.pointee.value += 10
  #expect(loadedDirectRoot.child.pointee.value == 52)
  #expect(loadedDirectRoot.child.pointee.child.pointee.value == 52)
  #expect(loadedDirectRoot.child.pointee.child.pointee.child.pointee.value == 52)
}

@Test func misc() {
  struct DirectNode: DirectEncoder.CompositeElement {
    var pointerToPointer1: Pointer<Pointer<DirectNode>> = .nil
    var pointerToPointer2: Pointer<Pointer<Int>> = .nil
    var pointers: Buffer<Pointer<DirectNode>> = .init(start: Pointer<UInt8>.nil, count: 0)
    var pointer1: Pointer<Int> = .nil
    var pointer2: Pointer<Int> = .nil
    var pointer3: Pointer<Int> = .nil
    var array1: Buffer<Int> = .nil
    var array2: Buffer<Int> = .nil
    var array3: Buffer<Int> = .nil
    var array4: Buffer<Int> = .nil
    var array5: Buffer<DirectNode> = .nil
    var pointerToBuffer1: Pointer<Buffer<Int>> = .nil
    var pointerToBuffer2: Pointer<Buffer<Int>> = .nil
    var value: Int64 = 0

    func encodeMembers(
      at compositeElementLocation: DirectEncoder.ElementLocation<DirectNode>,
      to encoder: inout DirectEncoder
    ) {
      if pointerToPointer1 != .nil && pointerToPointer1.pointee != .nil {
        encoder.resolveElementPointer(
          compositeElementLocation,
          member: \.pointerToPointer1,
          with: encoder.encodeElement(pointerToPointer1.pointee) { encoder, pointer, pointerLocation in
            encoder.resolveCompositeElementPointer(
              pointerLocation,
              with: encoder.encodeCompositeElementPointer(pointer),
            )
          },
        )
      }

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointerToPointer2,
        with: encoder.encodeElementPointer(pointerToPointer2) { encoder, pointer, pointerLocation in
          encoder.resolveElementPointer(
            pointerLocation,
            with: encoder.encodeElementPointer(pointer),
          )
        }
      )

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointer1,
        with: encoder.encodeElementPointer(pointer1),
      )

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointer2,
        with: encoder.encodeElementPointer(pointer2),
      )

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointer3,
        with: encoder.encodeElementPointer(pointer3),
      )

      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.array1,
        with: encoder.encodeArrayPointer(buffer: array1)
      )

      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.array2,
        with: encoder.encodeArrayPointer(buffer: array2)
      )

      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.array3,
        with: encoder.encodeArrayPointer(buffer: array3)
      )

      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.array4,
        with: encoder.encodeArrayPointer(start: array4.start, count: array4.count)
      )

      encoder.resolveArrayPointer(
        compositeElementLocation,
        member: \.array5,
        with: encoder.encodeArrayPointer(buffer: array5) { encoder, node, nodeLocation in
          encoder.encodeMembers(node, at: nodeLocation)
        },
      )

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointerToBuffer1,
        with: encoder.encodeElementPointer(pointerToBuffer1) { encoder, buffer, bufferLocation in
          encoder.resolveArrayPointer(
            bufferLocation,
            with: encoder.encodeArrayPointer(buffer: buffer),
          )
        },
      )

      encoder.resolveElementPointer(
        compositeElementLocation,
        member: \.pointerToBuffer2,
        with: encoder.encodeElementPointer(pointerToBuffer2) { encoder, buffer, bufferLocation in
          encoder.resolveArrayPointer(
            bufferLocation,
            with: encoder.encodeArrayPointer(buffer: buffer),
          )
        },
      )
    }
  }

  let memoryPool = MemoryPool()

  var root = DirectNode()

  root.value = 2
  root.pointerToPointer1 = memoryPool.element(Pointer<DirectNode>.nil)
  root.pointerToPointer1.pointee = memoryPool.element(DirectNode())
  root.pointerToPointer1.pointee.pointee.value = 3
  root.pointerToPointer2 = memoryPool.element(.nil)
  root.pointerToPointer2.pointee = memoryPool.element(11)
  root.pointer1 = memoryPool.element(0)
  root.pointer1.pointee = 4
  root.pointer2 = root.pointer1
  root.array1 = memoryPool.array([5, 6, 7])
  root.array2 = root.array1
  root.array5 = memoryPool.array([DirectNode(), DirectNode()])
  root.array5[0].value = 42
  root.array5[0].array5 = root.array5
  root.pointerToBuffer1 = memoryPool.element(.nil)
  root.pointerToBuffer1.pointee = memoryPool.array([8, 9, 10])

  var encoder = DirectEncoder()

  encoder.appendRoot(location: encoder.encodeCompositeElement(root))

  let data = encoder.endEncoding()

  // change original after encoding to make sure decoded content doesn't accidentally reuse pointers
  root.value = 11
  root.pointerToPointer1.pointee.pointee.value = 12
  root.pointerToPointer2.pointee.pointee = 17
  root.pointer1.pointee = 13
  root.array1[0] = 14
  root.array1[1] = 15
  root.array1[2] = 16

  let dataBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

  data.copyBytes(to: dataBuffer, count: data.count)

  let directDecoder = DirectDecoder(consume: .init(start: dataBuffer, count: data.count))

  let loadedDirectRoot = directDecoder.getRootPointer(0, DirectNode.self).pointee

  #expect(loadedDirectRoot.value == 2)
  #expect(loadedDirectRoot.pointerToPointer1.pointee.pointee.value == 3)
  #expect(loadedDirectRoot.pointerToPointer2.pointee.pointee == 11)
  #expect(loadedDirectRoot.pointer1.pointee == 4)
  #expect(loadedDirectRoot.pointer2.pointee == 4)
  #expect(loadedDirectRoot.pointer3 == .nil)
  #expect(loadedDirectRoot.array1[0] == 5)
  #expect(loadedDirectRoot.array1[1] == 6)
  #expect(loadedDirectRoot.array1[2] == 7)
  #expect(loadedDirectRoot.array2[0] == 5)
  #expect(loadedDirectRoot.array2[1] == 6)
  #expect(loadedDirectRoot.array2[2] == 7)
  #expect(loadedDirectRoot.array3.isNil == true)

  loadedDirectRoot.pointer1.pointee = 44
  loadedDirectRoot.array1[0] = 55
  loadedDirectRoot.array1[1] = 66
  loadedDirectRoot.array1[2] = 77

  #expect(loadedDirectRoot.pointer1.pointee == 44)
  #expect(loadedDirectRoot.pointer2.pointee == 44)
  #expect(loadedDirectRoot.array1[0] == 55)
  #expect(loadedDirectRoot.array1[1] == 66)
  #expect(loadedDirectRoot.array1[2] == 77)
  #expect(loadedDirectRoot.array2[0] == 55)
  #expect(loadedDirectRoot.array2[1] == 66)
  #expect(loadedDirectRoot.array2[2] == 77)

  #expect(loadedDirectRoot.array5.count == 2)
  #expect(loadedDirectRoot.array5[0].value == 42)
  #expect(loadedDirectRoot.array5[1].value == 0)
  #expect(loadedDirectRoot.array5[0].array5 == loadedDirectRoot.array5)
  #expect(loadedDirectRoot.array5[0].array5[0].value == 42)
  #expect(loadedDirectRoot.array5[0].array5[1].value == 0)

  loadedDirectRoot.array5[0].value += 10
  loadedDirectRoot.array5[1].value += 10

  #expect(loadedDirectRoot.array5[0].value == 52)
  #expect(loadedDirectRoot.array5[1].value == 10)
  #expect(loadedDirectRoot.array5[0].array5[0].value == 52)
  #expect(loadedDirectRoot.array5[0].array5[1].value == 10)

  #expect(loadedDirectRoot.pointerToBuffer1.isNil == false)
  #expect(loadedDirectRoot.pointerToBuffer1.pointee[0] == 8)
  #expect(loadedDirectRoot.pointerToBuffer1.pointee[1] == 9)
  #expect(loadedDirectRoot.pointerToBuffer1.pointee[2] == 10)
  #expect(loadedDirectRoot.pointerToBuffer2.isNil == true)
}

