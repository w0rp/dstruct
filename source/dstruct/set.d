/**
 * This module defines a hash set data structure and various operations
 * on it.
 */
module dstruct.set;

import dstruct.support;
import dstruct.map;

/**
 * A garbage collected implementation of a hash set.
 *
 * Because this type is a struct, it can never be null.
 */
struct HashSet(T) {
private:
    HashMap!(T, void[0]) _map;
public:
    /**
     * Add an element to this set if needed.
     *
     * Params:
     *     value = The value to add to the set.
     */
    @safe pure nothrow
    void add(ref T value) {
        _map[value] = (void[0]).init;
    }


    /// ditto
    @safe pure nothrow
    void add(T value) {
        add(value);
    }

    /**
     * Remove an element from this set if present.
     *
     * Params:
     *     value = The value to remove from the set.
     *
     * Returns: true if a value was removed.
     */
    @nogc @safe pure nothrow
    bool remove(ref T value) {
        return _map.remove(value);
    }

    /// ditto
    @nogc @safe pure nothrow
    bool remove(T value) {
        return remove(value);
    }

    /**
     * Returns: The number of elements in this set.
     */
    @nogc @safe pure nothrow
    @property size_t length() const {
        return _map.length;
    }

    /**
     * Returns: True if this set is empty.
     */
    @nogc @safe pure nothrow
    @property bool empty() const {
        return length == 0;
    }

    /**
     * Provide the 'in' operator for sets.
     *
     * Test if the given value is present in the set.
     *
     * Params:
     *    value = The value to test with.
     *
     *
     * Returns: true if the value is in the set.
     */
    @nogc @safe pure nothrow
    bool opBinaryRight(string op, T)(ref T value) const if(op == "in") {
        return cast(bool)(value in _map);
    }

    /// ditto
    @nogc @safe pure nothrow
    bool opBinaryRight(string op, T)(T value) const if(op == "in") {
        return opBinaryRight!("in", T)(value);
    }

    /**
     * Returns: True if two sets contain all equal values.
     */
    @nogc @safe pure nothrow
    bool opEquals(U)(const(HashSet!U) otherSet) const
    if (is(U : T) || is(T : U)) {
        static if (is(U : T)) {
            if (this.length != otherSet.length) {
                return false;
            }

            foreach(value; otherSet._map.keys()) {
                if (value !in this) {
                    return false;
                }
            }

            return true;
        } else {
            // Implement equality the other way by flipping things around.
            return otherSet == this;
        }
    }
}

// Test add and in.
unittest {
    HashSet!int set;

    set.add(3);

    assert(3 in set);
}

// Test !in
unittest {
    HashSet!int set;

    set.add(3);

    assert(4 !in set);
}

// Test remove
unittest {
    HashSet!int set;

    set.add(4);

    assert(set.remove(4));
    assert(!set.remove(3));
}

// Test set length
unittest {
    HashSet!int set;

    set.add(1);
    set.add(2);
    set.add(3);

    assert(set.length == 3);
}

// Test empty length
unittest {
    HashSet!int set;

    assert(set.length == 0);
}

// Test basic equality.
unittest {
    HashSet!int leftSet;
    leftSet.add(2);
    leftSet.add(3);

    HashSet!int rightSet;
    rightSet.add(2);
    rightSet.add(3);

    assert(leftSet == rightSet);
}

// Test implicit conversion equality left to right.
unittest {
    HashSet!int leftSet;
    leftSet.add(2);
    leftSet.add(3);

    HashSet!float rightSet;
    rightSet.add(2.0);
    rightSet.add(3.0);

    assert(leftSet == rightSet);
}

// Test implicit conversion equality right to left.
unittest {
    HashSet!float leftSet;
    leftSet.add(2.0);
    leftSet.add(3.0);

    HashSet!int rightSet;
    rightSet.add(2);
    rightSet.add(3);

    assert(leftSet == rightSet);
}

/**
 * Produce a range through all the entries of a set.
 *
 * Params:
 *     set = A set.
 *
 * Returns:
 *     A ForwardRange over all the entries in the set.
 */
@nogc @safe pure nothrow
auto entries(U)(auto ref inout(HashSet!U) set) {
    return set._map.keys();
}

/**
 * Returns: A mutable copy of this set.
 */
@safe pure nothrow
HashSet!T dup(T)(ref const(HashSet!T) originalSet)
if(isDupable!T) {
    HashSet!T newSet;

    foreach(value; originalSet.entries) {
        newSet.add(value);
    }

    return newSet;
}

/// ditto
@safe pure nothrow
HashSet!T dup(T)(const(HashSet!T) originalSet)
if(isDupable!T) {
    return originalSet.dup();
}

unittest {
    const(HashSet!int) createSet() {
        HashSet!int set;

        set.add(1);
        set.add(2);

        return set;
    }

    auto set = createSet();
    auto newSet = set.dup;
    // Test r-values.
    auto thirdSet = createSet().dup();

    assert(set == newSet);
}
