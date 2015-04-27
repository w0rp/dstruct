module dstruct.map;

import core.memory;
import core.exception;

import core.stdc.string: memcpy, memset;

import std.range : ElementType;
import std.traits : Unqual, isPointer;

import dstruct.support;

private enum EntryState {
    empty = 0,
    occupied = 1,
    deleted = 2,
}

private enum SearchFor {
    empty = 1,
    occupied = 2,
    deleted = 4,
    notDeleted = empty | occupied,
    notOccupied = empty | deleted,
    any = empty | occupied | deleted,
}

private enum is64Bit = is(size_t == ulong);

// Given a size, compute the space in bytes required for a member when
// the member is aligned to a size_t.sizeof boundary.
private size_t alignedSize(size_t size) {
    if (size % size_t.sizeof) {
        // If there's a remainder, then our boundary is a little ahead.
        return cast(size_t) (size / size_t.sizeof) + 1 * size_t.sizeof;
    }

    // If the size is cleanly divisible, it will fit right into place.
    return size;
}

private enum isHashIdentical(T) =
    is(T : uint)
    | is(T : char)
    | is(T : wchar)
    | is(T : dchar)
    | isPointer!T
    | (is64Bit && is(T : ulong));

/**
 * An item from a map.
 *
 * The keys and the values in the map are references into the map itself.
 */
struct Entry(K, V) {
private:
    K _key;
    V _value;
    EntryState _state = EntryState.empty;

    static if (!isHashIdentical!K) {
        size_t _hash;
    }
public:
    /**
     * A key from the map.
     */
    @nogc @safe pure nothrow
    @property ref inout(K) key() inout {
        return _key;
    }

    /**
     * A value from the map.
     */
    @nogc @safe pure nothrow
    @property ref inout(V) value() inout {
        return _value;
    }
}

// TODO: Test different entry sizes.

static if(__VERSION__ < 2066) {
    private alias SafeGetHashType = size_t delegate(const(void*)) pure nothrow;
} else {
    // Use mixin to hide UDA errors from old D compilers, it will never
    // execute the mixin, so it won't report an error in syntax.
    mixin("private alias SafeGetHashType = size_t delegate(const(void*)) @nogc pure nothrow;");
}

@nogc @trusted pure nothrow
private size_t computeHash(K)(ref K key) if (!isHashIdentical!K) {
    // Cast so we can keep our function qualifiers.
    return (cast(SafeGetHashType) &(typeid(K).getHash))(&key);
}

@nogc @trusted pure nothrow
private size_t castHash(K)(K key) if (isHashIdentical!K) {
    return cast(size_t) key;
}

private enum size_t minimumBucketListSize = 8;

@nogc @safe pure nothrow
private size_t newBucketListSize(size_t currentLength) {
    return currentLength * 2;
}

@trusted
private size_t bucketListSearch(SearchFor searchFor, K, V)
(ref const(Entry!(K, V)[]) bucketList, const(K) key)
if (isHashIdentical!K) {
    size_t index = castHash(key) & (bucketList.length - 1);

    foreach(j; 1 .. bucketList.length) {
        static if (searchFor == SearchFor.notOccupied) {
            if (bucketList[index]._state != EntryState.occupied) {
                return index;
            }

            if (bucketList[index]._key == key) {
                return index;
            }
        } else {
            static if (searchFor & SearchFor.empty) {
                if (bucketList[index]._state == EntryState.empty) {
                    return index;
                }
            }

            static if (searchFor & SearchFor.deleted) {
                if (bucketList[index]._state == EntryState.deleted
                && bucketList[index]._key == key) {
                    return index;
                }
            }

            static if (searchFor & SearchFor.occupied) {
                if (bucketList[index]._state == EntryState.occupied
                && bucketList[index]._key == key) {
                    return index;
                }
            }
        }

        index = (index + j) & (bucketList.length - 1);
    }

    assert(false, "Slot not found!");
}

@trusted
private size_t bucketListSearch(SearchFor searchFor, K, V)
(ref const(Entry!(K, V)[]) bucketList, size_t hash, const(K) key)
if (!isHashIdentical!K) {
    size_t index = hash & (bucketList.length - 1);

    foreach(j; 1 .. bucketList.length) {
        static if (searchFor == SearchFor.notOccupied) {
            if (bucketList[index]._state != EntryState.occupied) {
                return index;
            }

            if (bucketList[index]._hash == hash
            && bucketList[index]._key == key) {
                return index;
            }
        } else {
            static if (searchFor & SearchFor.empty) {
                if (bucketList[index]._state == EntryState.empty) {
                    return index;
                }
            }

            static if (searchFor & SearchFor.deleted) {
                if (bucketList[index]._state == EntryState.deleted
                && bucketList[index]._hash == hash
                && bucketList[index]._key == key) {
                    return index;
                }

            }

            static if (searchFor & SearchFor.occupied) {
                if (bucketList[index]._state == EntryState.occupied
                && bucketList[index]._hash == hash
                && bucketList[index]._key == key) {
                    return index;
                }
            }
        }

        index = (index + j) & (bucketList.length - 1);
    }

    assert(false, "Slot not found!");
}

// Add an entry into the bucket list.
// memcpy is used here because some types have immutable members which cannot
// be changed, so we have to force them into the array this way.
@nogc @trusted pure nothrow
private void setEntry(K, V)(ref Entry!(K, V)[] bucketList,
size_t index, auto ref K key, auto ref V value) {
    enum valueOffset = alignedSize(K.sizeof);

    // Copy the key and value into the entry.
    memcpy(cast(void*) &bucketList[index], &key, K.sizeof);
    memcpy(cast(void*) &bucketList[index] + valueOffset, &value, V.sizeof);

    bucketList[index]._state = EntryState.occupied;
}

@nogc @trusted pure nothrow
private void setEntry(K, V)(ref Entry!(K, V)[] bucketList,
size_t index, size_t hash, auto ref K key, auto ref V value) {
    enum valueOffset = alignedSize(K.sizeof);

    // Copy the key and value into the entry.
    memcpy(cast(void*) &bucketList[index], &key, K.sizeof);
    memcpy(cast(void*) &bucketList[index] + valueOffset, &value, V.sizeof);

    bucketList[index]._hash = hash;
    bucketList[index]._state = EntryState.occupied;
}

// Update just the value for an entry.
@nogc @trusted pure nothrow
private void updateEntryValue(K, V)(ref Entry!(K, V)[] bucketList,
size_t index, auto ref V value) {
    enum valueOffset = alignedSize(K.sizeof);

    memcpy(cast(void*) &bucketList[index] + valueOffset, &value, V.sizeof);
}

@nogc @trusted pure nothrow
private void zeroEntryValue(K, V)(ref Entry!(K, V)[] bucketList,
size_t index) {
    enum valueOffset = alignedSize(K.sizeof);

    memset(cast(void*) &bucketList[index] + valueOffset, 0, V.sizeof);
}

@nogc @trusted pure nothrow
private bool thresholdPassed(size_t length, size_t bucketCount) {
    return length * 2 >= bucketCount;
}

/**
 * This struct implements a hashmap type, much like the standard associative
 * array type.
 *
 * This map should be almost totally usable in @safe pure nothrow functions.
 *
 * An empty map will be a valid object, and will not result in any allocations.
 */
struct HashMap(K, V)
if(isAssignmentCopyable!(Unqual!K) && isAssignmentCopyable!(Unqual!V)) {
    alias ThisType = typeof(this);

    private Entry!(K, V)[] _bucketList;
    private size_t _length;

    /**
     * Construct a hashmap reserving a minimum of :minimumSize: space
     * for the bucket list. The actual space allocated may be some number
     * larger than the requested size, but it will be enough to fit
     * as many items as requested without another allocation.
     *
     * Params:
     * minimumSize = The minimum size for the hashmap.
     */
    @safe pure nothrow
    this(size_t minimumSize) {
        if (minimumSize == 0) {
            // 0 is a special case.
            return;
        }

        if (minimumSize <= minimumBucketListSize / 2) {
            _bucketList = new Entry!(K, V)[](minimumBucketListSize);
        } else {
            // Find the next largest power of two which will fit this size.
            size_t size = 8;

            while (thresholdPassed(minimumSize, size)) {
                size *= 2;
            }

            _bucketList = new Entry!(K, V)[](newBucketListSize(size));
        }
    }

    @trusted
    private void copyToBucketList(ref Entry!(K, V)[] newBucketList) const {
        foreach(ref entry; _bucketList) {
            if (entry._state != EntryState.occupied) {
                // Skip holes in the container.
                continue;
            }

            static if (isHashIdentical!K) {
                size_t index =
                    bucketListSearch!(SearchFor.empty, K, V)
                    (newBucketList, cast(K) entry._key);

                newBucketList.setEntry(
                    index,
                    cast(K) entry._key,
                    cast(V) entry._value
                );
            } else {
                size_t index =
                    bucketListSearch!(SearchFor.empty, K, V)
                    (newBucketList, entry._hash, cast(K) entry._key);

                newBucketList.setEntry(
                    index,
                    entry._hash,
                    cast(K) entry._key,
                    cast(V) entry._value
                );
            }
        }
    }

    @trusted
    private void resize(size_t newBucketListLength) in {
        assert(newBucketListLength > _bucketList.length);
    } body {
        auto newBucketList = new Entry!(K, V)[](newBucketListLength);

        copyToBucketList(newBucketList);

        _bucketList = newBucketList;
    }

    /**
     * Set a value in the map.
     *
     * Params:
     *     key = The key in the map.
     *     value = A value to set in the map.
     */
    void opIndexAssign(V value, K key) {
        static if (!isHashIdentical!K) {
            size_t hash = computeHash(key);
        }

        if (_bucketList.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(minimumBucketListSize);

            static if (isHashIdentical!K) {
                size_t index = castHash(key) & (_bucketList.length - 1);

                _bucketList.setEntry(index, key, value);
            } else {
                size_t index = hash & (_bucketList.length - 1);

                _bucketList.setEntry(index, hash, key, value);
            }

            return;
        }

        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, hash, key);
        }

        if (_bucketList[index]._state != EntryState.occupied) {
            // This slot is not occupied, so insert the entry here.
            static if (isHashIdentical!K) {
                _bucketList.setEntry(index, key, value);
            } else {
                _bucketList.setEntry(index, hash, key, value);
            }

            ++_length;

            if (thresholdPassed(_length, _bucketList.length)) {
                // Resize the bucketList, as it passed the threshold.
                resize(newBucketListSize(_bucketList.length));
            }
        } else {
            // We have this key already, so update the value.
            _bucketList.updateEntryValue(index, value);
        }
    }

    /**
     * Implement the 'in' operator for a map.
     *
     * The in operator on a map will return a pointer to a value, which will
     * be null when no corresponding value is set for a given key.
     *
     * Params:
     *     key = The key in the map.
     *
     * Returns:
     *     A pointer to a value, a null pointer if a value is not set.
     */
    inout(V)* opBinaryRight(string op)(K key) inout if (op == "in") {
        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, computeHash(key), key);
        }

        if (_bucketList[index]._state == EntryState.empty) {
            return null;
        }

        return &(_bucketList[index]._value);
    }

    /**
     * Retrieve a value from the map.
     *
     * If a value is not set for the given key, a RangeError will be thrown.
     *
     * Params:
     *     key = The key in the map.
     *
     * Returns:
     *     A value from the map.
     */
    ref inout(V) opIndex(K key) inout {
        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, computeHash(key), key);
        }

        assert(
            _bucketList[index]._state != EntryState.empty,
            "Key not found in HashMap!"
        );

        return _bucketList[index]._value;
    }

    /**
     * Get a value from the map, or return the given default value, which
     * is lazy-evaluated.
     *
     * Params:
     *     key = The key in the map.
     *     def = A lazy default value.
     *
     * Returns:
     *     A value from the map, or the default value.
     */
    V get(V2)(K key, lazy V2 def) const if(is(V2 : V)) {
        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, computeHash(key), key);
        }

        if (_bucketList[index]._state == EntryState.empty) {
            return def();
        }

        return _bucketList[index]._value;
    }

    /**
     * Get a value from the map, or return V.init if a value is not set for
     * a given key.
     *
     * Params:
     *     key = The key in the map.
     *
     * Returns:
     *     A value from the map, or the default value.
     */
    inout(V) get(K key) inout {
        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, computeHash(key), key);
        }


        if (_bucketList[index]._state == EntryState.empty) {
            return V.init;
        }

        return _bucketList[index]._value;
    }

    /**
     * Get or create a value from/in the map.
     *
     * Given a key, and a lazy evaluated default value,
     * attempt to retrieve a value from the map. If a value for the given
     * key is not set, set the provided default value in the map and
     * return that.
     *
     * The value will be returned by reference.
     *
     * Params:
     *     key = The key in the map.
     *     def = A lazy default value.
     *
     * Returns:
     *     A reference to the value in the map.
     */
    ref V setDefault(V2)(K key, lazy V2 value) if (is(V2 : V)) {
        static if (!isHashIdentical!K) {
            size_t hash = computeHash(key);
        }

        if (_bucketList.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(minimumBucketListSize);

            static if (isHashIdentical!K) {
                size_t index = castHash(key) & (_bucketList.length - 1);

                _bucketList.setEntry(index, key, V.init);
            } else {
                size_t index = hash & (_bucketList.length - 1);

                _bucketList.setEntry(index, hash, key, V.init);
            }

            return _bucketList[index].value;
        }

        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, hash, key);
        }

        if (_bucketList[index]._state == EntryState.empty) {
            // The entry is empty, so we can insert the value here.
            static if (isHashIdentical!K) {
                _bucketList.setEntry(index, key, value());
            } else {
                _bucketList.setEntry(index, hash, key, value());
            }

            ++_length;

            if (thresholdPassed(_length, _bucketList.length)) {
                // Resize the bucketList, as it passed the threshold.
                resize(newBucketListSize(_bucketList.length));

                // Update the index, it has now changed.
                static if (isHashIdentical!K) {
                    index = bucketListSearch!(SearchFor.notDeleted, K, V)
                        (_bucketList, key);
                } else {
                    index = bucketListSearch!(SearchFor.notDeleted, K, V)
                        (_bucketList, hash, key);
                }
            }
        }

        // Return a reference to the value.
        return _bucketList[index]._value;
    }

    /**
     * Get or create a value from/in a hashmap.
     *
     * Given a key attempt to retrieve a value from the hashmap.
     * If a value for the given key is not set, set the value in
     * the associative array to the default value for the value's type.
     *
     * The value will be returned by reference.
     *
     * Params:
     *     key = The key in the map.
     *
     * Returns:
     *     A reference to the value in the map.
     */
    ref V setDefault(K key) {
        static if (!isHashIdentical!K) {
            size_t hash = computeHash(key);
        }

        if (_bucketList.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(minimumBucketListSize);

            static if (isHashIdentical!K) {
                size_t index = castHash(key) & (_bucketList.length - 1);

                _bucketList.setEntry(index, key, V.init);
            } else {
                size_t index = hash & (_bucketList.length - 1);

                _bucketList.setEntry(index, hash, key, V.init);
            }

            return _bucketList[index].value;
        }

        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.notDeleted, K, V)
                (_bucketList, hash, key);
        }

        if (_bucketList[index]._state == EntryState.empty) {
            // The entry is empty, so we can insert the value here.
            static if (isHashIdentical!K) {
                _bucketList.setEntry(index, key, V.init);
            } else {
                _bucketList.setEntry(index, hash, key, V.init);
            }

            ++_length;

            if (thresholdPassed(_length, _bucketList.length)) {
                // Resize the bucketList, as it passed the threshold.
                resize(newBucketListSize(_bucketList.length));

                // Update the index, it has now changed.
                static if (isHashIdentical!K) {
                    index = bucketListSearch!(SearchFor.notDeleted, K, V)
                        (_bucketList, key);
                } else {
                    index = bucketListSearch!(SearchFor.notDeleted, K, V)
                        (_bucketList, hash, key);
                }
            }
        }

        // Return a reference to the value.
        return _bucketList[index]._value;
    }

    /**
     * Remove a entry from the map if it is set, given a key.
     *
     * Params:
     *     key = The key in the map.
     *
     * Returns:
     *     true if a value was removed, otherwise false.
     */
    bool remove(K key) {
        static if (isHashIdentical!K) {
            size_t index =
                bucketListSearch!(SearchFor.any, K, V)
                (_bucketList, key);
        } else {
            size_t index =
                bucketListSearch!(SearchFor.any, K, V)
                (_bucketList, computeHash(key), key);
        }

        if (_bucketList[index]._state == EntryState.occupied) {
            --_length;

            // Zero the value and mark the slot as 'deleted', which is
            // treated often the same as 'empty', only we can skip over
            // deleted values to search for more values.
            _bucketList.zeroEntryValue(index);
            _bucketList[index]._state = EntryState.deleted;

            return true;
        }

        return false;
    }

    /**
     * The length of the map.
     *
     * Returns: The number of entries in the map, in constant time.
     */
    @nogc @safe pure nothrow
    @property size_t length() const {
        return _length;
    }

    /**
     * Returns: True if this map is empty.
     */
    @nogc @safe pure nothrow
    @property bool empty() const {
        return _length == 0;
    }

    /**
     * Implement boolean conversion for a map.
     *
     * Returns: True if this set is not empty.
     */
    @nogc @safe pure nothrow
    bool opCast(T: bool)() const {
        return !empty;
    }

    static if(isDupable!K && isDupable!V) {
        /**
         * Copy an existing map into a new mutable map.
         *
         * Returns:
         *     The fresh copy of the map.
         */
        @safe pure nothrow
        HashMap!(K, V) dup() const {
            if (_length == 0) {
                // Just return nothing special for length 0.
                return HashMap!(K, V).init;
            }

            // Create a new map large enough to fit all of our values.
            auto newMap = HashMap!(K, V)(_length);
            newMap._length = _length;

            copyToBucketList(newMap._bucketList);

            return newMap;
        }
    }


    /**
     * Test if two maps are equal.
     *
     * Params:
     *     otherMap = Another map.
     *
     * Returns:
     *     true only if the maps are equal in length, keys, and values.
     */
    bool opEquals(ref const(HashMap!(K, V)) otherMap) const {
        if (_length != otherMap._length) {
            return false;
        }

        foreach(ref entry; _bucketList) {
            if (entry._state != EntryState.occupied) {
                // Skip holes in the container.
                continue;
            }

            static if (isHashIdentical!K) {
                size_t index =
                    bucketListSearch!(SearchFor.notDeleted, K, V)
                    (otherMap._bucketList, entry._key);
            } else {
                size_t index =
                    bucketListSearch!(SearchFor.notDeleted, K, V)
                    (otherMap._bucketList, entry._hash, entry._key);
            }

            if (otherMap._bucketList[index]._state == EntryState.empty) {
                return false;
            }
        }

        return true;
    }

    /// ditto
    bool opEquals(const(HashMap!(K, V)) otherMap) const {
        return opEquals(otherMap);
    }
}

template HashMapKeyType(T) {
    alias HashMapKeyType = typeof(ElementType!(typeof(T._bucketList))._key);
}

template HashMapValueType(T) {
    alias HashMapValueType = typeof(ElementType!(typeof(T._bucketList))._value);
}

// Test that is is not possible to create a map with a key or a value type
// which cannot be copy-assigned.
unittest {
    struct NonCopyable { @disable this(this); }

    assert(!__traits(compiles, HashMap!(NonCopyable, int)));
    assert(__traits(compiles, HashMap!(NonCopyable*, int)));
    assert(!__traits(compiles, HashMap!(int, NonCopyable)));
    assert(__traits(compiles, HashMap!(int, NonCopyable*)));
}

// Check setting values, retrieval, removal, and lengths.
unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    map[1] = "x";
    map[2] = "y";
    map[3] = "z";

    assert(map.length == 3);

    assert(map[1] == "x");
    assert(map[2] == "y");
    assert(map[3] == "z");

    assert(map.remove(3));
    assert(map.remove(2));
    assert(map.remove(1));

    assert(!map.remove(1));

    assert(map.length == 0);
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";
    map[4] = "d";
    map[5] = "e";
    map[6] = "f";
    map[7] = "g";
    map[8] = "h";
    map[9] = "i";

    map[1] = "x";
    map[2] = "y";
    map[3] = "z";

    assert(map.length == 9);

    assert(map[1] == "x");
    assert(map[2] == "y");
    assert(map[3] == "z");
    assert(map[4] == "d");
    assert(map[5] == "e");
    assert(map[6] == "f");
    assert(map[7] == "g");
    assert(map[8] == "h");
    assert(map[9] == "i");

    assert(map.remove(3));
    assert(map.remove(2));
    assert(map.remove(1));

    assert(!map.remove(1));

    assert(map.length == 6);
}

// Test the map with heavy collisions.
unittest {
    struct BadHashObject {
        int value;

        this(int value) {
            this.value = value;
        }

        @safe nothrow
        size_t toHash() const {
            return 0;
        }

        @nogc @safe nothrow pure
        bool opEquals(ref const BadHashObject other) const {
            return value == other.value;
        }
    }

    HashMap!(BadHashObject, string) map;
    enum size_t mapSize = 100;

    foreach(num; 0 .. mapSize) {
        map[BadHashObject(cast(int) num)] = "a";
    }

    assert(map.length == mapSize);
}

// Test preallocated maps;
unittest {
    auto map = HashMap!(int, string)(3);

    assert(map._bucketList.length == minimumBucketListSize);
}

// Test the 'in' operator.
unittest {
    // We'll test that our attributes work.
    @safe pure nothrow
    void runTest() {
        HashMap!(int, string) map;

        map[1] = "a";
        map[2] = "b";
        map[3] = "c";

        // Test that @nogc works.
        @nogc @safe pure nothrow
        void runNoGCPart(typeof(map) map) {
            assert((4 in map) is null);

            assert(*(1 in map) == "a");
            assert(*(2 in map) == "b");
            assert(*(3 in map) == "c");
        }

        runNoGCPart(map);
    }

    runTest();
}

// Test the map with a weird type which makes assignment harder.
unittest {
    struct WeirdType {
    // The alignment could cause memory issues so we'll check for that.
    align(1):
        // This immutable member means we need to use memset above to set
        // keys or values.
        immutable(byte)* foo = null;
        size_t x = 3;

        @nogc @safe pure nothrow
        this(int value) {
            x = value;
        }

        @nogc @safe pure nothrow
        size_t toHash() const {
            return x;
        }

        @nogc @safe pure nothrow
        bool opEquals(ref const(WeirdType) other) const {
            return foo == other.foo && x == other.x;
        }

        @nogc @safe pure nothrow
        bool opEquals(const(WeirdType) other) const {
            return opEquals(other);
        }
    }

    @safe pure nothrow
    void runTest() {
        HashMap!(WeirdType, string) map;

        map[WeirdType(10)] = "a";

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(map) map) {
            assert(map[WeirdType(10)] == "a");
        }

        runNoGCPart(map);
    }

    runTest();
}

// Test get with default init
unittest {
    @safe pure nothrow
    void runTest() {
        HashMap!(int, string) map;

        map[1] = "a";

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(map) map) {
            assert(map.get(1) == "a");
            assert(map.get(2) is null);
        }
        runNoGCPart(map);
    }

    runTest();

}

// Test length, empty, and cast(bool)
unittest {
    @safe pure nothrow
    void runTest() {
        HashMap!(int, string) map;

        @nogc @safe pure nothrow
        void runNoGCPart1(typeof(map) map) {
            assert(map.length == 0);
            assert(map.empty);

            if (map) {
                assert(false, "cast(bool) failed for an empty map");
            }
        }

        @nogc @safe pure nothrow
        void runNoGCPart2(typeof(map) map) {
            assert(map.length == 1);
            assert(!map.empty);

            if (!map) {
                assert(false, "cast(bool) failed for an non-empty map");
            }
        }

        @nogc @safe pure nothrow
        void runNoGCPart3(typeof(map) map) {
            assert(map.length == 0);
            assert(map.empty);

            if (map) {
                assert(false, "cast(bool) failed for an empty map");
            }
        }

        runNoGCPart1(map);
        map[1] = "a";
        runNoGCPart2(map);
        map.remove(1);
        runNoGCPart3(map);
    }

    runTest();
}

// BUG: The lazy argument here cannot be made to be nothrow, @nogc, etc.
// Test get with a given default.
unittest {
    HashMap!(int, string) map;

    map[1] = "a";

    assert(map.get(1, "b") == "a");
    assert(map.get(2, "b") == "b");
}

// Test opEquals
unittest {
    @safe pure nothrow
    void runTest() {
        HashMap!(string, string) leftMap;
        HashMap!(string, string) rightMap;

        // Give the left one a bit more, and take away from it.
        leftMap["a"] = "1";
        leftMap["b"] = "2";
        leftMap["c"] = "3";
        leftMap["d"] = "4";
        leftMap["e"] = "5";
        leftMap["f"] = "6";
        leftMap["g"] = "7";
        leftMap["h"] = "8";
        leftMap["i"] = "9";
        leftMap["j"] = "10";

        rightMap["a"] = "1";
        rightMap["b"] = "2";
        rightMap["c"] = "3";

        @nogc @safe pure nothrow
        void runNoGCPart(typeof(leftMap) leftMap, typeof(rightMap) rightMap) {
            // Remove the extra keys
            leftMap.remove("d");
            leftMap.remove("e");
            leftMap.remove("f");
            leftMap.remove("g");
            leftMap.remove("h");
            leftMap.remove("i");
            leftMap.remove("j");

            // Now the two maps should have different bucketLists, but they
            // should still be considered equal.
            assert(leftMap == rightMap);
        }

        runNoGCPart(leftMap, rightMap);
    }

    runTest();
}

// Test setDefault with default init
unittest {
    @safe pure nothrow
    void runTest() {
        HashMap!(int, string) map;

        map[1] = "a";

        // setDefault for basic types with no explicit default ought to
        // be nothrow.
        assert(map.setDefault(1) == "a");
        assert(map.setDefault(2) is null);

        assert(map.length == 2);

        assert(map[2] is null);
    }

    runTest();
}

// Test setDefault with a given value.
unittest {
    HashMap!(int, string) map;

    map[1] = "a";

    assert(map.setDefault(1, "b") == "a");
    assert(map.setDefault(2, "b") == "b");

    assert(map.length == 2);

    assert(map[2] == "b");
}

// Test setDefault with a given value which can be implicitly converted.
unittest {
    HashMap!(int, long) map;

    map[1] = 2;

    assert(map.setDefault(1, 3) == 2);

    int x = 4;

    assert(map.setDefault(2, x) == 4);

    assert(map.length == 2);

    assert(map[2] == 4);
}

/**
 * A range through a series of items in the map.
 */
struct KeyValueRange(K, V) {
private:
    Entry!(K, V)[] _bucketList = null;
public:
    @nogc @safe pure nothrow
    this(Entry!(K, V)[] bucketList) {
        foreach(index, ref entry; bucketList) {
            if (entry._state == EntryState.occupied) {
                // Use a slice of the bucketList starting here.
                _bucketList = bucketList[index .. $];

                return;
            }
        }
    }

    @nogc @trusted pure nothrow
    this(const(Entry!(K, V)[]) bucketList) {
        this(cast(Entry!(K, V)[]) bucketList);
    }

    @nogc @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    @nogc @safe pure nothrow
    @property
    bool empty() const {
        // We can check that the bucketList is empty to check if this range is
        // empty, because we will clear it after we pop the last item.
        return _bucketList.length == 0;
    }

    @nogc @safe pure nothrow
    @property
    ref inout(Entry!(K, V)) front() inout in {
        assert(!empty());
    } body {
        return _bucketList[0];
    }

    @nogc @safe pure nothrow
    void popFront() in {
        assert(!empty());
    } body {
        foreach(index; 1 .. _bucketList.length) {
            if (_bucketList[index]._state == EntryState.occupied) {
                // Use a slice of the bucketList starting here.
                _bucketList = _bucketList[index .. $];

                return;
            }
        }

        // Clear the bucketList if we hit the end.
        _bucketList = null;
    }
}

/**
 * Produce a range through the items of a map. (A key-value pair)
 *
 * Params:
 *     map = A map.
 * Returns:
 *     A range running through the items in the map.
 */
@nogc @safe pure nothrow
auto byKeyValue(K, V)(auto ref HashMap!(K, V) map) {
    if (map.length == 0) {
        // Empty ranges should not have to traverse the bucketList at all.
        return KeyValueRange!(K, V).init;
    }

    return KeyValueRange!(K, V)(map._bucketList);
}

/// ditto
@nogc @trusted pure nothrow
auto byKeyValue(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return KeyValueRange!(RealK, RealV).init;
    }

    return KeyValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byKeyValue(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return KeyValueRange!(RealK, RealV).init;
    }

    return KeyValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    int[] keyList;
    string[] valueList;

    foreach(item; map.byKeyValue()) {
        keyList ~= item.key;
        valueList ~= item.value;
    }

    // From the way the bucketLists are distributed, we know we'll get this back.
    assert(keyList == [1, 2, 3]);
    assert(valueList == ["a", "b", "c"]);
}

unittest {
    HashMap!(string, string) mmap;
    const(HashMap!(string, string)) cmap;
    immutable(HashMap!(string, string)) imap;

    auto mItems = mmap.byKeyValue();
    auto cItems = cmap.byKeyValue();
    auto iItems = imap.byKeyValue();

    assert(is(typeof(mItems.front.key) == string));
    assert(is(typeof(cItems.front.key) == const(string)));
    assert(is(typeof(iItems.front.key) == immutable(string)));
    assert(is(typeof(mItems.front.value) == string));
    assert(is(typeof(cItems.front.value) == const(string)));
    assert(is(typeof(iItems.front.value) == immutable(string)));
}

// Test that the ranges can be created from r-values.
unittest {
    auto func() {
        HashMap!(int, string) map;

        map[1] = "a";
        map[2] = "b";
        map[3] = "c";

        return map;
    }

    auto keyRange = func().byKey();
    auto valueRange = func().byValue();
    auto itemRange = func().byKeyValue();
}

/**
 * This is a range which runs through a series of keys in map.
 */
struct KeyRange(K, V) {
private:
    KeyValueRange!(K, V) _keyValueRange;
public:
    @nogc @safe pure nothrow
    private this()(auto ref Entry!(K, V)[] bucketList) {
        _keyValueRange = KeyValueRange!(K, V)(bucketList);
    }

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
    @nogc @trusted pure nothrow
    @property
    ref inout(K) front() inout {
        return _keyValueRange.front.key;
    }

    ///
    @nogc @safe pure nothrow
    void popFront() {
        _keyValueRange.popFront();
    }
}

/**
 * Produce a range through the keys of a map.
 *
 * Params:
 *     map = A map.
 * Returns:
 *     A range running through the keys in the map.
 */
@nogc @safe pure nothrow
auto byKey(K, V)(auto ref HashMap!(K, V) map) {
    if (map.length == 0) {
        return KeyRange!(K, V).init;
    }

    return KeyRange!(K, V)(map._bucketList);
}

/// ditto
@nogc @trusted pure nothrow
auto byKey(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return KeyRange!(RealK, RealV).init;
    }

    return KeyRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byKey(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return KeyRange!(RealK, RealV).init;
    }

    return KeyRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    int[] keyList;

    foreach(ref key; map.byKey()) {
        keyList ~= key;
    }

    // From the way the bucketLists are distributed, we know we'll get this back.
    assert(keyList == [1, 2, 3]);
}

unittest {
    HashMap!(string, string) mmap;
    const(HashMap!(string, string)) cmap;
    immutable(HashMap!(string, string)) imap;

    auto mKeys = mmap.byKey();
    auto cKeys = cmap.byKey();
    auto iKeys = imap.byKey();

    assert(is(typeof(mKeys.front) == string));
    assert(is(typeof(cKeys.front) == const(string)));
    assert(is(typeof(iKeys.front) == immutable(string)));
}

/**
 * This is a range which runs through a series of values in a map.
 */
struct ValueRange(K, V) {
private:
    KeyValueRange!(K, V) _keyValueRange;
public:
    @nogc @safe pure nothrow
    private this()(auto ref Entry!(K, V)[] bucketList) {
        _keyValueRange = KeyValueRange!(K, V)(bucketList);
    }

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
    @nogc @trusted pure nothrow
    @property
    ref inout(V) front() inout {
        return _keyValueRange.front.value;
    }

    ///
    @nogc @safe pure nothrow
    void popFront() {
        _keyValueRange.popFront();
    }
}

/**
 * Produce a range through the values of a map.
 *
 * Params:
 *     map = A map.
 * Returns:
 *     A range running through the values in the map.
 */
@nogc @safe pure nothrow
auto byValue(K, V)(auto ref HashMap!(K, V) map) {
    if (map.length == 0) {
        return ValueRange!(K, V).init;
    }

    return ValueRange!(K, V)(map._bucketList);
}

/// ditto
@nogc @trusted pure nothrow
auto byValue(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return ValueRange!(RealK, RealV).init;
    }

    return ValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byValue(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    if (map.length == 0) {
        return ValueRange!(RealK, RealV).init;
    }

    return ValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)[])
        map._bucketList
    );
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    string[] valueList = [];

    foreach(ref value; map.byValue()) {
        valueList ~= value;
    }

    // From the way the buckets are distributed, we know we'll get this back.
    assert(valueList == ["a", "b", "c"]);
}

unittest {
    HashMap!(string, string) mmap;
    const(HashMap!(string, string)) cmap;
    immutable(HashMap!(string, string)) imap;

    auto mValues = mmap.byValue();
    auto cValues = cmap.byValue();
    auto iValues = imap.byValue();

    assert(is(typeof(mValues.front) == string));
    assert(is(typeof(cValues.front) == const(string)));
    assert(is(typeof(iValues.front) == immutable(string)));
}

unittest {
    const(HashMap!(int, int)) createMap() {
        HashMap!(int, int) map;

        map[3] = 4;
        map[4] = 7;

        return map;
    }

    auto map = createMap();
    auto newMap = map.dup;
    // Test r-values.
    auto thirdMap = createMap().dup();

    assert(map == newMap);
}

unittest {
    HashMap!(int, void[0]) map;

    auto x = map.dup;
}
