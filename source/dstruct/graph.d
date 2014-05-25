module dstruct.graph;

import std.algorithm;
import std.range;
import std.array;
import std.typecons;

import dstruct.map;

/// The directionality of a graph.
enum EdgeDirection : bool {
    /// Undirected, meaning edges face either direction.
    undirected,
    /// Directed, meaning edges face one direction.
    directed,
}

@safe pure nothrow
private bool findAndRemove(T)(ref T[] arr, ref T needle) {
    foreach(index; 0 .. arr.length) {
        if (arr[index] == needle) {
            foreach(newIndex; index .. arr.length - 1) {
                arr[newIndex] = arr[newIndex + 1];
            }

            arr.length = arr.length - 1;
            return true;
        }
    }

    return false;
}

@safe pure nothrow
private void addIfMissing(T)(ref T[] arr, ref T value) {
    if (arr.countUntil(value) < 0) {
        arr ~= value;
    }
}

/**
 * This struct represents a graph type as a reference type.
 *
 * Graphs types have a type of vertex and a direction.
 *
 * The graphs are represented by adjacency lists, which have good
 * all-around performance characteristics for sparse graphs.
 */
struct BasicGraph(Vertex, EdgeDirection edgeDirection) {
private:
    HashMap!(Vertex, Vertex[]) adjacencyMap;
public:
    /// true if this graph is a directed graph.
    enum bool isDirected = edgeDirection == EdgeDirection.directed;

    /**
     * Add a vertex to the graph.
     */
    @safe pure nothrow
    void addVertex(ref Vertex vertex) {
        adjacencyMap.setDefault(vertex);
    }

    /// ditto
    @safe pure nothrow
    void addVertex(Vertex vertex) {
        addVertex(vertex);
    }

    /**
     * Remove the given vertex from this graph.
     *
     * Any edges to the given vertex will be removed.
     *
     * Returns: true if a vertex was removed.
     */
    @safe pure nothrow
    bool removeVertex(ref Vertex vertex) {
        // Try to remove the vertex's adjacency mapping first.
        if (!adjacencyMap.remove(vertex)) {
            return false;
        }

        foreach(ref list; adjacencyMap.values) {
            findAndRemove(list, vertex);
        }

        return true;
    }

    /// ditto
    @safe pure nothrow
    bool removeVertex(Vertex vertex) {
        return removeVertex(vertex);
    }

    /**
     * Returns: true if the vertex is in the graph.
     */
    @safe pure nothrow
    bool hasVertex(ref Vertex vertex) const {
        return (vertex in adjacencyMap) !is null;
    }

    /// ditto
    @safe pure nothrow
    bool hasVertex(Vertex vertex) const {
        return hasVertex(vertex);
    }

    /**
     * Add an edge to the graph.
     *
     * New vertices will be added to the graph automatically.
     */
    @safe pure nothrow
    void addEdge(ref Vertex left, ref Vertex right) {
        adjacencyMap.setDefault(left).addIfMissing(right);

        static if (!isDirected) {
            adjacencyMap.setDefault(right).addIfMissing(left);
        } else {
            addVertex(right);
        }
    }

    /// ditto
    @safe pure nothrow
    void addEdge(ref Vertex left, Vertex right) {
        addEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    void addEdge(Vertex left, ref Vertex right) {
        addEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    void addEdge(Vertex left, Vertex right) {
        addEdge(left, right);
    }

    /**
     * Remove an edge from the graph.
     *
     * Vertices in the edge will not be removed.
     *
     * Returns: true if an edge was removed.
     */
    @safe pure nothrow
    bool removeEdge(ref Vertex left, ref Vertex right) {
        auto listPtr = left in adjacencyMap;

        if (listPtr is null) {
            return false;
        }

        if (!findAndRemove(*listPtr, right)) {
            return false;
        }

        static if (!isDirected) {
            findAndRemove(adjacencyMap[right], left);
        }

        return true;
    }

    /// ditto
    @safe pure nothrow
    bool removeEdge(ref Vertex left, Vertex right) {
        return removeEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    bool removeEdge(Vertex left, ref Vertex right) {
        return removeEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    bool removeEdge(Vertex left, Vertex right) {
        return removeEdge(left, right);
    }

    /**
     * Check if an edge exists in the graph.
     *
     * Returns: true if the edge exists in the graph.
     */
    @safe pure nothrow
    bool hasEdge(ref Vertex left, ref Vertex right) const {
        if (auto listPtr = left in adjacencyMap) {
            return countUntil(*listPtr, right) > -1;
        }

        return false;
    }

    /// ditto
    @safe pure nothrow
    bool hasEdge(ref Vertex left, Vertex right) const {
        return hasEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    bool hasEdge(Vertex left, ref Vertex right) const {
        return hasEdge(left, right);
    }

    /// ditto
    @safe pure nothrow
    bool hasEdge(Vertex left, Vertex right) const {
        return hasEdge(left, right);
    }

    /**
     * Return the number of vertices in this graph
     * in constant time.
     *
     * Returns: The number of vertices in this graph.
     */
    @trusted pure nothrow
    @property
    size_t vertexCount() const {
        // BUG: .length is not @safe
        return adjacencyMap.length;
    }

    /**
     * Return the number of directed edges in this graph
     * in linear time. If this graph is a graph with undirected
     * edges, this will always be double the undirected
     * edge count.
     *
     * Returns: The number of directed edges in this graph.
     */
    @safe pure nothrow
    size_t directedEdgeCount() const {
        size_t count = 0;

        // BUG: We have to catch the exception which never happens
        // to make this nothrow, because the foreach isn't nothrow.
        try {
            foreach(ref list; adjacencyMap.values()) {
                count += list.length;
            }
        } catch (Exception e) {}

        return count;
    }

    /**
     * Return the number of edges in this graph
     * in linear time.
     *
     * Returns: The number of edges in this graph.
     */
    @safe pure nothrow
    size_t edgeCount() const {
        static if (!isDirected) {
            return directedEdgeCount() / 2;
        } else {
            return directedEdgeCount();
        }
    }
}

/// A shorthand for an undirected graph.
alias Graph(Vertex) = BasicGraph!(Vertex, EdgeDirection.undirected);

/// A shorthand for a directed graph.
alias Digraph(Vertex) = BasicGraph!(Vertex, EdgeDirection.directed);

/// Test if a type T is an undirected graph type with a particular vertex type.
enum isUndirectedGraph(T, Vertex) = is(T == BasicGraph!(Vertex, EdgeDirection.undirected));

/// Test if a type T is a directed graph type with a particular vertex type.
enum isDirectedGraph(T, Vertex) = is(T == BasicGraph!(Vertex, EdgeDirection.directed));

/// Test if a type T is any graph type with a particular vertex type.
enum isGraph(T, Vertex) = isUndirectedGraph!(T, Vertex) || isDirectedGraph!(T, Vertex);

// Test the templates.
unittest {
    Graph!int graph;

    assert(isUndirectedGraph!(typeof(graph), int));
    assert(isGraph!(typeof(graph), int));
    assert(!isGraph!(typeof(graph), short));

    Digraph!int digraph;

    assert(isDirectedGraph!(typeof(digraph), int));
    assert(isGraph!(typeof(digraph), int));
    assert(!isGraph!(typeof(digraph), short));
}

// Test adding vertices and the vertex count on graphs
unittest {
    Graph!string graph;

    foreach(symbol; ["a", "b", "c", "d", "a"]) {
        graph.addVertex(symbol);
    }

    assert(graph.vertexCount == 4);
}

unittest {
    Digraph!string digraph;

    foreach(symbol; ["a", "b", "c", "d", "a"]) {
        digraph.addVertex(symbol);
    }

    assert(digraph.vertexCount == 4);
}

// Test adding edges and the edge count.
unittest {
    Graph!byte graph;

    byte[2][] edgeList = [[1, 2], [2, 1], [3, 4], [5, 6]];

    foreach(edge; edgeList) {
        graph.addEdge(edge[0], edge[1]);
    }

    assert(graph.directedEdgeCount == 6);
    assert(graph.edgeCount == 3);
    assert(graph.hasVertex(1));
}

// Test adding edges and the edge count.
unittest {
    Digraph!byte graph;

    byte[2][] edgeList = [[1, 2], [2, 1], [3, 4], [5, 6]];

    foreach(edge; edgeList) {
        graph.addEdge(edge[0], edge[1]);
    }

    assert(graph.directedEdgeCount == 4);
    assert(graph.edgeCount == 4);
    assert(graph.hasVertex(1));
}

// Test adding one undirected graph edge implies the reverse.
unittest {
    Graph!byte graph;

    byte[2][] edgeList = [[1, 2], [3, 4]];

    foreach(edge; edgeList) {
        graph.addEdge(edge[0], edge[1]);
    }

    assert(graph.edgeCount == 2);
    assert(graph.hasEdge(2, 1));
    assert(graph.hasEdge(4, 3));
}

// Test that removing a vertex also removes the edges.
unittest {
    Digraph!byte graph;

    byte[2][] edgeList = [[1, 2], [3, 1], [2, 3]];

    foreach(edge; edgeList) {
        graph.addEdge(edge[0], edge[1]);
    }

    assert(graph.removeVertex(1));
    assert(graph.edgeCount == 1);
    assert(graph.hasEdge(2, 3));
}

unittest {
    Graph!byte graph;

    byte[2][] edgeList = [[1, 2], [3, 1], [2, 3]];

    foreach(edge; edgeList) {
        graph.addEdge(edge[0], edge[1]);
    }

    assert(graph.removeVertex(1));
    assert(graph.edgeCount == 1);
    assert(graph.hasEdge(2, 3));
}
