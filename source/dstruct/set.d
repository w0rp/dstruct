/**
 * This module defines a hash set data structure and various operations
 * on it.
 */
module dstruct.set;

/**
 * A garbage collected implementation of a hash set.
 *
 * Because this type is a struct, it can never be null.
 */
struct HashSet(T) {
private:
    void[0][T] _map;
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
    @safe pure nothrow
    bool remove(ref T value) {
        return _map.remove(value);
    }

    /// ditto
    @safe pure nothrow
    bool remove(T value) {
        return remove(value);
    }

    // BUG: This is not @safe because AA .length isn't at least @trusted.
    /**
     * Returns: The number of elements in this set.
     */
    @trusted pure nothrow
    @property size_t length() const {
        return _map.length;
    }

    /**
     * Returns: True if this set is empty.
     */
    @safe pure nothrow
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
    @safe pure nothrow
    bool opBinaryRight(string op, T)(ref T value) const if(op == "in") {
        return cast(bool)(value in _map);
    }

    /// ditto
    @safe pure nothrow
    bool opBinaryRight(string op, T)(T value) const if(op == "in") {
        return opBinaryRight!("in", T)(value);
    }

    // BUG: This is not nothrow because AA foreach isn't.
    /**
     * Returns: A mutable copy of this set.
     */
    @safe pure
    HashSet!T dup() const {
        HashSet!T newSet;

        foreach(value, _; _map) {
            newSet.add(value);
        }

        return newSet;
    }

    /**
     * Returns: A immutable copy of this set.
     */
    @safe pure
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
    @safe pure nothrow
    ref immutable(HashSet!T) idup() immutable {
        return this;
    }

    /**
     * Provide foreach for sets.
     */
    int opApply(int delegate(ref T) dg) {
        int result = 0;

        foreach(value, _; _map) {
            result = dg(value);

            if (result) {
                break;
            }
        }

        return result;
    }

    /**
     * Returns: True if two sets contain all equal values.
     */
    @trusted pure
    bool opEquals(U)(const(HashSet!U) otherSet) const
    if (is(U : T) || is(T : U)) {
        static if (is(U : T)) {
            if (this.length != otherSet.length) {
                return false;
            }

            foreach(value, _; otherSet._map) {
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

// Test foreach
unittest {
    HashSet!int set;

    set.add(3);

    int[] list;

    foreach(value; set) {
        list ~= value;
    }

    assert(list.length == 1);
    assert(list[0] == 3);
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
