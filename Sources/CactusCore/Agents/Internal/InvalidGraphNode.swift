import IssueReporting

func unableToAddGraphNode() {
  reportIssue(
    """
    Unable to add node to graph in graph builder implementation.

    Ensure that you pass a node id that exists in 'graph' to \
    'CactusAgent.build(graph:nodeId:environment:)'.
    """
  )
}
