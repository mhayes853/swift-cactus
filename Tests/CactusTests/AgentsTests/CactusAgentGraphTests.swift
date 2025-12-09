import Cactus
import CustomDump
import Testing

@Suite
struct `CactusAgentGraph tests` {
  @Test
  func `Can Find Root Node By Tag`() throws {
    let graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
    )
    expectNoDifference(graph[tag: "blob"]?.id, graph.root.id)
  }

  @Test
  func `Can Find Root Node By Id`() throws {
    let graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    expectNoDifference(graph[id: graph.root.id]?.id, graph.root.id)
  }

  @Test
  func `Root Node Children Is Empty When No Children Present`() throws {
    let graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    expectNoDifference(graph.children(for: graph.root.id)?.isEmpty, true)
  }

  @Test
  func `Append Child`() throws {
    var graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let _node = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let node = try #require(_node)

    expectNoDifference(graph[id: node.id]?.id, node.id)
    expectNoDifference(graph.children(for: graph.root.id)?[id: node.id]?.id, node.id)
    expectNoDifference(graph.children(for: graph.root.id)?.isEmpty, false)
  }

  @Test
  func `Append Child With Tag`() throws {
    var graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    expectNoDifference(graph[tag: "blob"]?.id, nil)
    expectNoDifference(graph.children(for: graph.root.id)?[tag: "blob"]?.id, nil)

    let _node = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
    )
    let node = try #require(_node)

    expectNoDifference(graph[tag: "blob"]?.id, node.id)
    expectNoDifference(graph.children(for: graph.root.id)?[tag: "blob"]?.id, node.id)
  }

  @Test
  func `Scopes Children Node Lookups`() throws {
    let graph = try TestGraphWithChildren()

    expectNoDifference(graph.agentGraph[tag: graph.node1.tag!]?.id, graph.node1.id)
    expectNoDifference(graph.agentGraph[id: graph.node1.id]?.id, graph.node1.id)
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?[tag: graph.node1.tag!]?.id,
      graph.node1.id
    )
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?[id: graph.node1.id]?.id,
      graph.node1.id
    )

    expectNoDifference(graph.agentGraph[tag: graph.node2.tag!]?.id, graph.node2.id)
    expectNoDifference(graph.agentGraph[id: graph.node2.id]?.id, graph.node2.id)
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?[tag: graph.node2.tag!]?.id,
      graph.node2.id
    )
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?[id: graph.node2.id]?.id,
      graph.node2.id
    )

    expectNoDifference(graph.agentGraph[tag: graph.node3.tag!]?.id, graph.node3.id)
    expectNoDifference(graph.agentGraph[id: graph.node3.id]?.id, graph.node3.id)
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?[tag: graph.node3.tag!]?.id,
      nil
    )
    expectNoDifference(graph.agentGraph.children(for: graph.root.id)?[id: graph.node3.id]?.id, nil)
    expectNoDifference(
      graph.agentGraph.children(for: graph.node1.id)?[tag: graph.node3.tag!]?.id,
      nil
    )
    expectNoDifference(graph.agentGraph.children(for: graph.node1.id)?[id: graph.node3.id]?.id, nil)
    expectNoDifference(
      graph.agentGraph.children(for: graph.node2.id)?[tag: graph.node3.tag!]?.id,
      graph.node3.id
    )
    expectNoDifference(
      graph.agentGraph.children(for: graph.node2.id)?[id: graph.node3.id]?.id,
      graph.node3.id
    )
  }

  @Test
  func `Node Not Found In Its Children`() throws {
    let graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )

    expectNoDifference(graph.children(for: graph.root.id)?[id: graph.root.id]?.id, nil)
    expectNoDifference(graph.children(for: graph.root.id)?[tag: "blob"]?.id, nil)
  }

  #if DEBUG
    @Test
    func `Reports Issue When Node With Duplicate Tag Added`() throws {
      var graph = CactusAgentGraph(
        root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
      )

      withKnownIssue {
        _ = graph.appendChild(
          to: graph.root.id,
          fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
        )
      } matching: { issue in
        issue.comments.contains(Comment(rawValue: _agentGraphDuplicateTag("blob")))
      }
    }
  #endif

  @Test
  func `Children Iterates Shallowly Through Nodes`() throws {
    let graph = try TestGraphWithChildren()

    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?.map(\.id),
      [graph.node1.id, graph.node2.id]
    )
    expectNoDifference(
      graph.agentGraph.children(for: graph.root.id)?.map(\.id).contains(graph.node3.id),
      false
    )
  }

  @Test
  func `Graph Iterates Depth-First Through Nodes`() throws {
    let graph = try TestGraphWithChildren()

    expectNoDifference(
      graph.agentGraph.map(\.id),
      [graph.root.id, graph.node1.id, graph.node2.id, graph.node3.id]
    )
  }

  @Test
  func `Graph Iterates Depth-First Through Flat Nodes`() throws {
    var graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )

    let _node1 = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
    )
    let node1 = try #require(_node1)
    let _node2 = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob2")
    )
    let node2 = try #require(_node2)
    let _node3 = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob3")
    )
    let node3 = try #require(_node3)

    expectNoDifference(
      graph.map(\.id),
      [graph.root.id, node1.id, node2.id, node3.id]
    )
  }

  @Test
  func `Fails To Append Node For Non-Existent Node ID`() throws {
    var graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let _child = graph.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let child = try #require(_child)

    var graph2 = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let child2 = graph2.appendChild(
      to: graph.root.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    let child3 = graph2.appendChild(
      to: child.id,
      fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    expectNoDifference(child2?.id, nil)
    expectNoDifference(child3?.id, nil)

    expectNoDifference(graph2[id: child.id]?.id, nil)
  }

  @Test
  func `Graph Node Count`() throws {
    let graph = try TestGraphWithChildren()

    expectNoDifference(graph.agentGraph.count, 4)
  }

  @Test
  func `Graph Node Children Count`() throws {
    let graph = try TestGraphWithChildren()

    expectNoDifference(graph.agentGraph.children(for: graph.root.id)?.count, 2)
    expectNoDifference(graph.agentGraph.children(for: graph.node1.id)?.count, 0)
    expectNoDifference(graph.agentGraph.children(for: graph.node2.id)?.count, 1)
    expectNoDifference(graph.agentGraph.children(for: graph.node3.id)?.count, 0)
  }

  @Test
  func `No Children For Non-Existent Node`() throws {
    let graph = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )

    let graph2 = CactusAgentGraph(
      root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
    )
    expectNoDifference(graph2.children(for: graph.root.id) == nil, true)
  }

  private struct TestGraphWithChildren {
    var agentGraph: CactusAgentGraph
    var root: CactusAgentGraph.Node
    var node1: CactusAgentGraph.Node
    var node2: CactusAgentGraph.Node
    var node3: CactusAgentGraph.Node

    init() throws {
      var graph = CactusAgentGraph(
        root: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>())
      )
      self.root = graph.root

      let node1 = graph.appendChild(
        to: self.root.id,
        fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob")
      )
      self.node1 = try #require(node1)
      let node2 = graph.appendChild(
        to: self.root.id,
        fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob2")
      )
      self.node2 = try #require(node2)
      let node3 = graph.appendChild(
        to: self.node2.id,
        fields: CactusAgentGraph.Node.Fields(agent: EmptyAgent<String, String>(), tag: "blob3")
      )
      self.node3 = try #require(node3)
      self.agentGraph = graph
    }
  }
}
