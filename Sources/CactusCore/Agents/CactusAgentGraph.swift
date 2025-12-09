import Foundation
import IssueReporting
import OrderedCollections

// MARK: - CactusAgentGraph

public struct CactusAgentGraph {
  fileprivate struct Entry {
    var node: Node
    var children: OrderedSet<Node.ID>
  }

  private var matrix = [Node.ID: Entry]()

  private let rootId: Node.ID

  public var root: Node {
    self.matrix[self.rootId]!.node
  }

  public var count: Int {
    self.matrix.keys.count
  }

  public init(root fields: Node.Fields) {
    let node = Node(fields: fields)
    self.rootId = node.id
    self.matrix = [node.id: Entry(node: node, children: [])]
  }

  public subscript(id id: Node.ID) -> Node? {
    self.matrix[id]?.node
  }

  public subscript(tag tag: AnyHashable) -> Node? {
    self.matrix.first { $0.value.node.tag == tag }?.value.node
  }
}

// MARK: - Node

extension CactusAgentGraph {
  @dynamicMemberLookup
  public struct Node: Identifiable {
    public struct ID: Hashable, Sendable {
      private let inner = UUID()
    }

    public let id: ID
    public let fields: Fields

    public subscript<Value>(dynamicMember member: KeyPath<Fields, Value>) -> Value {
      self.fields[keyPath: member]
    }

    fileprivate init(id: ID = ID(), fields: Node.Fields) {
      self.id = id
      self.fields = fields
    }
  }
}

extension CactusAgentGraph.Node {
  public struct Fields {
    public var agent: any CactusAgent
    public var tag: AnyHashable?

    public init(agent: any CactusAgent, tag: AnyHashable? = nil) {
      self.agent = agent
      self.tag = tag
    }
  }
}

// MARK: - Children

extension CactusAgentGraph {
  public func children(for nodeId: Node.ID) -> Node.Children? {
    guard let entry = self.matrix[nodeId] else { return nil }
    var nodes = OrderedDictionary<Node.ID, Node>()
    for nodeId in entry.children {
      guard let node = self[id: nodeId] else { continue }
      nodes[nodeId] = node
    }
    return Node.Children(nodes: nodes)
  }
}

extension CactusAgentGraph.Node {
  public struct Children {
    let nodes: OrderedDictionary<CactusAgentGraph.Node.ID, CactusAgentGraph.Node>

    public var isEmpty: Bool {
      self.nodes.isEmpty
    }

    public var count: Int {
      self.nodes.count
    }

    public subscript(id id: CactusAgentGraph.Node.ID) -> CactusAgentGraph.Node? {
      self.nodes[id]
    }

    public subscript(tag tag: AnyHashable) -> CactusAgentGraph.Node? {
      self.nodes.first { $0.value.tag == tag }?.value
    }
  }
}

extension CactusAgentGraph.Node.Children: Sequence {
  public struct Iterator: IteratorProtocol {
    var base: OrderedDictionary<CactusAgentGraph.Node.ID, CactusAgentGraph.Node>.Iterator

    public mutating func next() -> CactusAgentGraph.Node? {
      self.base.next()?.value
    }
  }

  public func makeIterator() -> Iterator {
    Iterator(base: self.nodes.makeIterator())
  }
}

extension CactusAgentGraph {
  @discardableResult
  public mutating func appendChild(
    to nodeId: CactusAgentGraph.Node.ID,
    fields: CactusAgentGraph.Node.Fields
  ) -> CactusAgentGraph.Node? {
    guard self[id: nodeId] != nil else { return nil }
    self.warnIfDuplicateTag(fields.tag)

    let node = Node(fields: fields)
    self.matrix[node.id, default: Entry(node: node, children: [])].node = node
    self.matrix[nodeId]?.children.append(node.id)
    return node
  }
}

// MARK: - Sequence

extension CactusAgentGraph: Sequence {
  public struct Iterator: IteratorProtocol {
    private var nodeId: CactusAgentGraph.Node.ID?
    private let matrix: [CactusAgentGraph.Node.ID: Entry]
    private var positionStack = [(nodeId: CactusAgentGraph.Node.ID, childIndex: Int)]()

    fileprivate init(rootId: CactusAgentGraph.Node.ID, matrix: [CactusAgentGraph.Node.ID: Entry]) {
      self.nodeId = rootId
      self.matrix = matrix
    }

    public mutating func next() -> CactusAgentGraph.Node? {
      guard let nodeId, let entry = self.matrix[nodeId] else { return nil }

      guard entry.children.isEmpty else {
        self.positionStack.append((nodeId: nodeId, childIndex: 0))
        self.nodeId = entry.children[0]
        return entry.node
      }

      while let lastPosition = self.positionStack.popLast() {
        guard
          let prevEntry = self.matrix[lastPosition.nodeId],
          lastPosition.childIndex < prevEntry.children.count - 1
        else { continue }

        self.positionStack.append(
          (nodeId: lastPosition.nodeId, childIndex: lastPosition.childIndex + 1)
        )
        self.nodeId = prevEntry.children[lastPosition.childIndex + 1]
        return entry.node
      }
      self.nodeId = nil

      return entry.node
    }
  }

  public func makeIterator() -> Iterator {
    Iterator(rootId: self.rootId, matrix: self.matrix)
  }
}

// MARK: - Duplicate Tag Warning

extension CactusAgentGraph {
  @_transparent
  private func warnIfDuplicateTag(_ tag: AnyHashable?) {
    #if DEBUG
      if let tag, self[tag: tag] != nil {
        reportIssue(_agentGraphDuplicateTag(tag))
      }
    #endif
  }
}

#if DEBUG
  package func _agentGraphDuplicateTag(_ tag: AnyHashable) -> String {
    """
    A duplicate tag was found in the agent graph.

        Tag: \(tag)

    This is generally considered an application programming error, and is undefined behavior. \
    Ensure that a tag passed to the `tag` agent modifier is unique across the entire agent graph.

        struct MyAgent: CactusAgent {
          func body(request: CactusAgentRequest<Input>) -> some CactusAgent<Input, Output> {
            CactusModelAgent(.fromDirectory(slug: "qwen3-0.6")) {
              "You are an assistant..."
            }
            .tag("my-agent") // Make sure "my-agent" is unique across the entire agent graph.
          }
        }
    """
  }
#endif
