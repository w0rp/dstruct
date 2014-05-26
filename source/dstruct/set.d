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
     * Returns: A mutable copy of this set.
     */
    @safe pure nothrow
    HashSet!T dup() const {
        HashSet!T newSet;

        foreach(value; _map.keys()) {
            newSet.add(value);
        }

        return newSet;
    }

    /**
     * Returns: A immutable copy of this set.
     */
    @safe pure nothrow
    immutable(HashSet!T) idup() const {
        return dup;
    }

    /**
     * Calling .idup on an immutable set returns a reference, not
     * a copy. This is because immutable data can be shared without
     * any additional copying.
     *
     * Returns: An immutable reference to this immutable set.
     */
    @nogc @safe pure nothrow
    ref immutable(HashSet!T) idup() immutable {
        return this;
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

// Test .idup and reference .idup
unittest {
    HashSet!int set;

    set.add(3);

    immutable(HashSet!int) copy = set.idup;

    assert(copy.length == set.length);
    assert(3 in copy);

    // Check that the pointers are the same, so we know it's a reference.
    assert(&copy == &copy.idup());
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
