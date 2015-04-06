module dstruct.graph;

import core.stdc.string: memmove;

import dstruct.support;
import dstruct.map;

/// The directionality of a graph.
enum EdgeDirection : bool {
    /// Undirected, meaning edges face either direction.
    undirected,
    /// Directed, meaning edges face one direction.
    directed,
}

@trusted
private bool findAndRemove(T)(ref T[] arr, ref T needle) {
    foreach(index; 0 .. arr.length) {
        if (cast() arr[index] == cast() needle) {
            // When the index we find is right at the end, we shouldn't
            // move anything, just reduce the slice on the right by one.
            if (index != arr.length - 1) {
                // Shift all of the array elements back.
                memmove(
                    cast(void*) &arr[index],
                    cast(void*) &arr[index + 1],
                    T.sizeof * (arr.length - index)
                );
            }

            // Now shrink the slice by one element.
            arr = arr[0 .. $ - 1];

            return true;
        }
    }

    return false;
}

private void addIfMissing(T)(ref T[] arr, ref T value) {
    bool found = false;

    foreach(ref otherValue; arr) {
        if (cast() value == cast() otherValue) {
            found = true;
            break;
        }
    }

    if (!found) {
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
    void addVertex(ref Vertex vertex) {
        adjacencyMap.setDefault(vertex);
    }

    /// ditto
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
    bool removeVertex(ref Vertex vertex) {
        // Try to remove the vertex's adjacency mapping first.
        if (!adjacencyMap.remove(vertex)) {
            return false;
        }

        foreach(ref list; adjacencyMap.byValue) {
            findAndRemove(list, vertex);
        }

        return true;
    }

    /// ditto
    bool removeVertex(Vertex vertex) {
        return removeVertex(vertex);
    }

    /**
     * Returns: true if the vertex is in the graph.
     */
    bool hasVertex(ref Vertex vertex) const {
        return (vertex in adjacencyMap) !is null;
    }

    /// ditto
    bool hasVertex(Vertex vertex) const {
        return hasVertex(vertex);
    }

    /**
     * Add an edge to the graph.
     *
     * New vertices will be added to the graph automatically.
     */
    void addEdge(ref Vertex left, ref Vertex right) {
        adjacencyMap.setDefault(left).addIfMissing(right);

        static if (!isDirected) {
            adjacencyMap.setDefault(right).addIfMissing(left);
        } else {
            addVertex(right);
        }
    }

    /// ditto
    void addEdge(ref Vertex left, Vertex right) {
        addEdge(left, right);
    }

    /// ditto
    void addEdge(Vertex left, ref Vertex right) {
        addEdge(left, right);
    }

    /// ditto
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
    bool removeEdge(ref Vertex left, Vertex right) {
        return removeEdge(left, right);
    }

    /// ditto
    bool removeEdge(Vertex left, ref Vertex right) {
        return removeEdge(left, right);
    }

    /// ditto
    bool removeEdge(Vertex left, Vertex right) {
        return removeEdge(left, right);
    }

    /**
     * Check if an edge exists in the graph.
     *
     * Returns: true if the edge exists in the graph.
     */
    bool hasEdge(ref Vertex left, ref Vertex right) const {
        if (auto listPtr = left in adjacencyMap) {
            foreach(ref outgoingVertex; *listPtr) {
                if (cast() right == cast() outgoingVertex) {
                    return true;
                }
            }

            return false;
        }

        return false;
    }

    /// ditto
    bool hasEdge(ref Vertex left, Vertex right) const {
        return hasEdge(left, right);
    }

    /// ditto
    bool hasEdge(Vertex left, ref Vertex right) const {
        return hasEdge(left, right);
    }

    /// ditto
    bool hasEdge(Vertex left, Vertex right) const {
        return hasEdge(left, right);
    }

    /**
     * Return the number of vertices in this graph
     * in constant time.
     *
     * Returns: The number of vertices in this graph.
     */
    @property
    size_t vertexCount() const {
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
    size_t directedEdgeCount() const {
        size_t count = 0;

        foreach(ref list; adjacencyMap.byValue()) {
            count += list.length;
        }

        return count;
    }

    /**
     * Return the number of edges in this graph
     * in linear time.
     *
     * Returns: The number of edges in this graph.
     */
    size_t edgeCount() const {
        static if (!isDirected) {
            return directedEdgeCount() / 2;
        } else {
            return directedEdgeCount();
        }
    }
}

/**
 * An edge in a graph.
 */
struct Edge(V) {
    V from;
    V to;
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
    @safe pure nothrow
    void runTest() {
        Graph!string graph;

        foreach(symbol; ["a", "b", "c", "d", "a"]) {
            graph.addVertex(symbol);
        }

        assert(graph.vertexCount == 4);
    }

    runTest();
}

unittest {
    @safe pure nothrow
    void runTest() {
        Digraph!string digraph;

        foreach(symbol; ["a", "b", "c", "d", "a"]) {
            digraph.addVertex(symbol);
        }

        // Test that @nogc works.
        @nogc @safe pure nothrow
        void runNoGCPart(typeof(digraph) digraph) {
            assert(digraph.vertexCount == 4);
        }

        runNoGCPart(digraph);
    }

    runTest();
}

// Test adding edges and the edge count.
unittest {
    static assert(isUndirectedGraph!(Graph!byte, byte));

    @safe pure nothrow
    void runTest() {
        Graph!byte graph;

        byte[2][] edgeList = [[1, 2], [2, 1], [3, 4], [5, 6]];

        foreach(edge; edgeList) {
            graph.addEdge(edge[0], edge[1]);
        }

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.directedEdgeCount == 6);
            assert(graph.edgeCount == 3);
            assert(graph.hasVertex(1));
        }

        runNoGCPart(graph);
    }

    runTest();
}

// Test adding edges and the edge count.
unittest {
    @safe pure nothrow
    void runTest() {
        Digraph!byte graph;

        byte[2][] edgeList = [[1, 2], [2, 1], [3, 4], [5, 6]];

        foreach(edge; edgeList) {
            graph.addEdge(edge[0], edge[1]);
        }

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.directedEdgeCount == 4);
            assert(graph.edgeCount == 4);
            assert(graph.hasVertex(1));
        }

        runNoGCPart(graph);
    }

    runTest();
}

// Test adding one undirected graph edge implies the reverse.
unittest {
    @safe pure nothrow
    void runTest() {
        Graph!byte graph;

        byte[2][] edgeList = [[1, 2], [3, 4]];

        foreach(edge; edgeList) {
            graph.addEdge(edge[0], edge[1]);
        }

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.edgeCount == 2);
            assert(graph.hasEdge(2, 1));
            assert(graph.hasEdge(4, 3));
        }

        runNoGCPart(graph);
    }

    runTest();
}

// Test that removing a vertex also removes the edges.
unittest {
    @safe pure nothrow
    void runTest() {
        Digraph!byte graph;

        byte[2][] edgeList = [[1, 2], [3, 1], [2, 3]];

        foreach(edge; edgeList) {
            graph.addEdge(edge[0], edge[1]);
        }

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.removeVertex(1));
            assert(graph.edgeCount == 1);
            assert(graph.hasEdge(2, 3));
        }

        runNoGCPart(graph);
    }

    runTest();
}

// Test adding and removing vertices for immutable objects
unittest {
    struct SomeType {
        int x;
    }

    @safe pure nothrow
    void runTest() {
        Digraph!(immutable(SomeType)) graph;

        graph.addVertex(immutable(SomeType)(3));
        graph.addVertex(immutable(SomeType)(4));

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.removeVertex(immutable(SomeType)(3)));
            assert(graph.removeVertex(immutable(SomeType)(4)));
        }

        runNoGCPart(graph);
    }

    runTest();
}

unittest {
    @safe pure nothrow
    void runTest() {
        Graph!byte graph;

        byte[2][] edgeList = [[1, 2], [3, 1], [2, 3]];

        foreach(edge; edgeList) {
            graph.addEdge(edge[0], edge[1]);
        }

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            assert(graph.removeVertex(1));
            assert(graph.edgeCount == 1);
            assert(graph.hasEdge(2, 3));
        }

        runNoGCPart(graph);
    }

    runTest();
}

/**
 * Given any type of graph, produce a range through the vertices of the graph.
 *
 * Params:
 *     graph = A graph.
 *
 * Returns:
 *     A ForwardRange through the vertices of the graph.
 */
@nogc @safe pure nothrow
auto vertices(V, EdgeDirection edgeDirection)
(auto ref BasicGraph!(V, edgeDirection) graph) {
    return graph.adjacencyMap.byKey;
}

/// ditto
@nogc @safe pure nothrow
auto vertices(V, EdgeDirection edgeDirection)
(auto ref const(BasicGraph!(V, edgeDirection)) graph) {
    return graph.adjacencyMap.byKey;
}

/// ditto
@nogc @safe pure nothrow
auto vertices(V, EdgeDirection edgeDirection)
(auto ref immutable(BasicGraph!(V, edgeDirection)) graph) {
    return graph.adjacencyMap.byKey;
}

unittest {
    @safe pure nothrow
    void runTest() {
        Digraph!string graph;

        graph.addEdge("a", "b");
        graph.addEdge("a", "c");
        graph.addEdge("a", "d");
        graph.addEdge("b", "e");
        graph.addEdge("b", "f");
        graph.addEdge("b", "g");

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            foreach(vertex; graph.vertices) {}
        }

        runNoGCPart(graph);

        string[] vertexList;

        foreach(vertex; graph.vertices) {
            vertexList ~= vertex;
        }

        // We know we will get this order from how the hashing works.
        assert(vertexList == ["a", "b", "c", "d", "e", "f", "g"]);
    }

    runTest();
}

unittest {
    Graph!string mGraph;
    const(Graph!string) cGraph;
    immutable(Graph!string) iGraph;

    auto mVertices = mGraph.vertices();
    auto cVertices = cGraph.vertices();
    auto iVertices = iGraph.vertices();

    assert(is(typeof(mVertices.front) == string));
    assert(is(typeof(cVertices.front) == const(string)));
    assert(is(typeof(iVertices.front) == immutable(string)));
}

/**
 * A range through the edges of a graph.
 */
struct EdgeRange(V, VArr) {
private:
    KeyValueRange!(V, VArr) _keyValueRange;
    size_t _outgoingIndex;

    @nogc @safe pure nothrow
    this (typeof(_keyValueRange) keyValueRange) {
        _keyValueRange = keyValueRange;

        // Advance until we find an edge.
        while (!_keyValueRange.empty
        && _keyValueRange.front.value.length == 0) {
            _keyValueRange.popFront;
        }
    }
public:
    ///
    @nogc @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    ///
    @nogc @safe pure nothrow
    @property
    bool empty() const {
        return _keyValueRange.empty;
    }

    ///
    @nogc @safe pure nothrow
    @property
    Edge!V front() const {
        auto item = _keyValueRange.front;

        return Edge!V(item.key, item.value[_outgoingIndex]);
    }

    ///
    @nogc @safe pure nothrow
    void popFront() {
        if (++_outgoingIndex < _keyValueRange.front.value.length) {
            // There's another outgoing edge in the list, so move to that.
            return;
        }

        // We have to find the next vertex with a non-empty adjacency list.
        _outgoingIndex = 0;

        do {
            _keyValueRange.popFront;
        } while (!_keyValueRange.empty
        && _keyValueRange.front.value.length == 0);
    }
}

/**
 * Given any type of graph, produce a range through the edges of the graph.
 *
 * Params:
 *     graph = A graph.
 *
 * Returns:
 *     A ForwardRange through the edges of the graph.
 */
@nogc @safe pure nothrow
auto edges(V, EdgeDirection edgeDirection)
(auto ref BasicGraph!(V, edgeDirection) graph) {
    return EdgeRange!(V, V[])(graph.adjacencyMap.byKeyValue);
}

/// ditto
@nogc @trusted pure nothrow
auto edges(V, EdgeDirection edgeDirection)
(auto ref const(BasicGraph!(V, edgeDirection)) graph) {
    return EdgeRange!(const(V), const(V[]))(
        cast(KeyValueRange!(const(V), const(V[])))
        graph.adjacencyMap.byKeyValue
    );
}

/// ditto
@nogc @trusted pure nothrow
auto edges(V, EdgeDirection edgeDirection)
(auto ref immutable(BasicGraph!(V, edgeDirection)) graph) {
    return EdgeRange!(immutable(V), immutable(V[]))(
        cast(KeyValueRange!(immutable(V), immutable(V[])))
        graph.adjacencyMap.byKeyValue
    );
}

unittest {
    @safe pure nothrow
    void runTest() {
        Digraph!string graph;

        graph.addEdge("a", "b");
        graph.addEdge("a", "c");
        graph.addEdge("a", "d");
        graph.addEdge("b", "e");
        graph.addEdge("b", "f");
        graph.addEdge("b", "g");

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(graph) graph) {
            foreach(vertex; graph.edges) {}
        }

        runNoGCPart(graph);

        Edge!string[] edgeList;

        foreach(edge; graph.edges) {
            edgeList ~= edge;
        }

        // We know we will get this order from how the hashing works.
        assert(edgeList.length);
        assert(edgeList[0].from == "a");
        assert(edgeList[0].to == "b");
        assert(edgeList[1].from == "a");
        assert(edgeList[1].to == "c");
        assert(edgeList[2].from == "a");
        assert(edgeList[2].to == "d");
        assert(edgeList[3].from == "b");
        assert(edgeList[3].to == "e");
        assert(edgeList[4].from == "b");
        assert(edgeList[4].to == "f");
        assert(edgeList[5].from == "b");
        assert(edgeList[5].to == "g");
    }

    runTest();
}

unittest {
    Graph!string mGraph;
    const(Graph!string) cGraph;
    immutable(Graph!string) iGraph;

    auto mVertices = mGraph.edges();
    auto cVertices = cGraph.edges();
    auto iVertices = iGraph.edges();

    assert(is(typeof(mVertices.front) == Edge!string));
    assert(is(typeof(cVertices.front) == Edge!(const(string))));
    assert(is(typeof(iVertices.front) == Edge!(immutable(string))));
}
