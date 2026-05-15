# direct-encoding

Dangerously fast zero-copy binary encoding for Swift structs. Encode by `memcpy`-ing your struct's native memory layout, decode with a single pointer-fixup pass — every field access is a raw pointer dereference. No parsing, no copying, no ceremony.

<p>
  <a href="https://github.com/vinceplusplus/direct-encoding/actions?query=workflow%3Atest-macos+event%3Apush">
    <img src="https://github.com/vinceplusplus/direct-encoding/workflows/test-macos/badge.svg">
  </a>
  <a href="https://github.com/vinceplusplus/direct-encoding/actions?query=workflow%3Atest-ios+event%3Apush">
    <img src="https://github.com/vinceplusplus/direct-encoding/workflows/test-ios/badge.svg">
  </a>
  <a href="https://codecov.io/gh/vinceplusplus/direct-encoding">
    <img src="https://codecov.io/gh/vinceplusplus/direct-encoding/branch/main/graph/badge.svg" />
  </a>
</p>

## Installation

```swift
// Package.swift
.package(url: "https://github.com/vinceplusplus/direct-encoding.git", from: "1.4.0")
```

Then add `"DirectEncoding"` to your target's dependencies.

## Usage

```swift
import DirectEncoding

// 1. Define your model — String fields are natively supported
struct DirectNode: DirectEncoder.CompositeElement {
    var name: String
    var value: Int64

    init(name: String, value: Int64) {
        self.name = name
        self.value = value
    }

    func encodeMembers(
        at location: DirectEncoder.ElementLocation<DirectNode>,
        to encoder: inout DirectEncoder
    ) {
        encoder.encodeMembers(self, at: location, member: \.name)
    }
}

// 2. Encode
var encoder = DirectEncoder()
encoder.appendRoot(
    location: encoder.encodeCompositeElement(DirectNode(name: "hello", value: 42))
)
let data = encoder.endEncoding()

// 3. Decode — the fixup pass mutates the buffer in-place
let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
data.copyBytes(to: UnsafeMutableRawPointer(buf), count: data.count)
let decoder = DirectDecoder(consume: Buffer(start: buf, count: data.count))
let root = decoder.getRootPointer(0, DirectNode.self)
print(root.pointee.name)  // "hello"
print(root.pointee.value) // 42
```

## Dangerously fast

| Phase | What happens |
|-------|-------------|
| **Encode** | Entire struct is `memcpy`'d into the buffer using its native memory layout — no per-field serialization overhead. |
| **Decode init** | Single O(n) pass over a list of pointer locations to fix up absolute addresses; no parsing of the wire format. |
| **Field access** | `pointer.pointee.value` — a raw pointer dereference, identical cost to accessing a field on any Swift struct. |

- **Zero copy** — data never leaves the buffer; no intermediate allocations or deserialization into Swift types.
- **Shared references** — deduplicated automatically; each object is encoded exactly once.
- **Cycles** — fully supported; pointers are cached before children are resolved.
- **Strings** — natively supported via Swift's internal `StringObject` layout; small strings (< 16 bytes) are encoded inline. *(Not yet supported on Android due to memory tagging.)*

## Supported types

```swift
struct MyStruct: DirectEncoder.CompositeElement {
    // Plain — encoded implicitly, nothing needed
    var value: Int64

    // String — uses native StringObject layout
    var name: String

    // Pointer to a composite element (shared refs & cycles ok)
    var child: Pointer<MyStruct>

    // Pointer to a plain value
    var ptr: Pointer<Int>

    // Array of plain values
    var numbers: Buffer<Int>

    // Array of composite elements
    var items: Buffer<MyStruct>

    func encodeMembers(
        at compositeElementLocation: DirectEncoder.ElementLocation<MyStruct>,
        to encoder: inout DirectEncoder
    ) {
        encoder.encodeMembers(self, at: compositeElementLocation, member: \.name)

        encoder.resolveCompositeElementPointer(
            compositeElementLocation, member: \.child,
            with: encoder.encodeCompositeElementPointer(child),
        )

        encoder.resolveElementPointer(
            compositeElementLocation, member: \.ptr,
            with: encoder.encodeElementPointer(ptr),
        )

        encoder.resolveArrayPointer(
            compositeElementLocation, member: \.numbers,
            with: encoder.encodeArrayPointer(buffer: numbers),
        )

        encoder.resolveArrayPointer(
            compositeElementLocation, member: \.items,
            with: encoder.encodeArrayPointer(buffer: items) { encoder, item, itemLocation in
                encoder.encodeMembers(item, at: itemLocation)
            },
        )
    }
}
```

## Requirements

- Swift 6.2+
- macOS 11+ / iOS 14+
