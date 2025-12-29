@usableFromInline
struct Chain2Sequence<Base1: Sequence, Base2: Sequence>
where Base1.Element == Base2.Element {
  @usableFromInline
  let base1: Base1

  @usableFromInline
  let base2: Base2

  @inlinable
  init(base1: Base1, base2: Base2) {
    self.base1 = base1
    self.base2 = base2
  }
}

extension Chain2Sequence: Sequence {
  @usableFromInline
  struct Iterator: IteratorProtocol {
    @usableFromInline
    var iterator1: Base1.Iterator

    @usableFromInline
    var iterator2: Base2.Iterator

    @inlinable
    init(_ concatenation: Chain2Sequence) {
      iterator1 = concatenation.base1.makeIterator()
      iterator2 = concatenation.base2.makeIterator()
    }

    @inlinable
    mutating func next() -> Base1.Element? {
      iterator1.next() ?? iterator2.next()
    }
  }

  @inlinable
  func makeIterator() -> Iterator {
    Iterator(self)
  }
}

@inlinable
func chain<Base1: Sequence, Base2: Sequence>(
  _ base1: Base1,
  _ base2: Base2
) -> Chain2Sequence<Base1, Base2> {
  Chain2Sequence(base1: base1, base2: base2)
}
