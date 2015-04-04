module dstruct.map;

import core.memory;
import core.exception;

import std.range;

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

/**
 * An item from a map.
 *
 * The keys and the values in the map are references into the map itself.
 */
struct Entry(K, V) {
private:
    EntryState _state = EntryState.empty;
    size_t _hash;
    K _key;
    V _value;

    @nogc @safe pure nothrow
    this(size_t hash, ref K key, ref V value) {
        _state = EntryState.occupied;
        _hash = hash;
        _key = key;
        _value = value;
    }

    @nogc @safe pure nothrow
    this(size_t hash, ref K key, V value) {
        _state = EntryState.occupied;
        _hash = hash;
        _key = key;
        _value = value;
    }

    @nogc @safe pure nothrow
    this(size_t hash, K key, ref V value) {
        _state = EntryState.occupied;
        _hash = hash;
        _key = key;
        _value = value;
    }

    @nogc @safe pure nothrow
    this(size_t hash, K key, V value) {
        _state = EntryState.occupied;
        _hash = hash;
        _key = key;
        _value = value;
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

static if(__VERSION__ < 2066) {
    private alias SafeGetHashType = size_t delegate(const(void*)) pure nothrow;
} else {
    // Use mixin to hide UDA errors from old D compilers, it will never
    // execute the mixin, so it won't report an error in syntax.
    mixin("private alias SafeGetHashType = size_t delegate(const(void*)) @nogc pure nothrow;");
}

@nogc @trusted pure nothrow
private size_t computeHash(K)(ref K key) {
    // Cast so we can keep our function qualifiers.
    return (cast(SafeGetHashType) &(typeid(K).getHash))(&key);
}

@nogc @safe pure nothrow
private size_t newBucketSize(size_t currentLength) {
    return currentLength * 2;
}

// Check that computeHash is doing the right thing.
unittest {
    int x = 1;
    int y = 2;
    int z = 3;

    assert(computeHash(x) == 1);
    assert(computeHash(y) == 2);
    assert(computeHash(z) == 3);
}

@nogc @trusted pure nothrow
private size_t bucketSearch(SearchFor searchFor, K, V)(ref const(Entry!(K, V)[]) bucket, size_t hash, const(K) key) {
    size_t index = hash & (bucket.length - 1);

    foreach(j; 1 .. bucket.length) {
        static if (searchFor == SearchFor.notOccupied) {
            if (bucket[index]._state != EntryState.occupied) {
                return index;
            }

            if (bucket[index]._hash == hash && bucket[index]._key == key) {
                return index;
            }
        } else {
            static if (searchFor & SearchFor.empty) {
                if (bucket[index]._state == EntryState.empty) {
                    return index;
                }
            }

            static if (searchFor & SearchFor.deleted) {
                if (bucket[index]._state == EntryState.deleted
                && bucket[index]._hash == hash
                && bucket[index]._key == key) {
                    return index;
                }
            }

            static if (searchFor & SearchFor.occupied) {
                if (bucket[index]._state == EntryState.occupied
                && bucket[index]._hash == hash
                && bucket[index]._key == key) {
                    return index;
                }
            }
        }

        index = (index + j) & (bucket.length - 1);
    }

    assert(false, "Slot not found!");
}

@nogc @trusted pure nothrow
private bool thresholdPassed(size_t length, size_t bucketLength) {
    return length * 2 >= bucketLength;
}

/**
 * This struct implements a hashmap type, much like the standard associative
 * array type.
 *
 * This map should be almost totally usable in @safe pure nothrow functions.
 *
 * An empty map will be a valid object, and will not result in any allocations.
 */
struct HashMap(K, V) {
    alias ThisType = typeof(this);

    private Entry!(K, V)[] bucket;
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
        if (minimumSize <= 2) {
            bucket = new Entry!(K, V)[](4);
        } else {
            // Find the next largest power of two which will fit this size.
            size_t size = 8;

            while (thresholdPassed(minimumSize, size)) {
                size *= 2;
            }

            bucket = new Entry!(K, V)[](newBucketSize(size));
        }
    }

    @trusted pure nothrow
    private void copyToBucket(ref Entry!(K, V)[] newBucket) const {
        foreach(ref entry; bucket) {
            if (entry._state != EntryState.occupied) {
                // Skip holes in the container.
                continue;
            }

            size_t index =
                bucketSearch!(SearchFor.empty, K, V)
                (newBucket, entry._hash, cast(K) entry._key);

            newBucket[index] = Entry!(K, V)(
                entry._hash,
                cast(K) entry._key,
                cast(V) entry._value
            );
        }
    }

    @safe pure nothrow
    private void resize(size_t newBucketLength) in {
        assert(newBucketLength > bucket.length);
    } body {
        auto newBucket = new Entry!(K, V)[](newBucketLength);

        copyToBucket(newBucket);

        bucket = newBucket;
    }

    /**
     * Set a value in the map.
     *
     * Params:
     *     key = The key in the map.
     *     value = A value to set in the map.
     */
    @trusted pure nothrow
    void opIndexAssign(V value, K key) {
        size_t hash = computeHash(key);

        if (bucket.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(4);

            size_t index = hash & (bucket.length - 1);

            bucket[index] = Entry!(K, V)(hash, key, value);

            return;
        }

        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)(bucket, hash, key);

        if (bucket[index]._state != EntryState.occupied) {
            // This slot is not occupied, so insert the entry here.
            bucket[index] = Entry!(K, V)(hash, key, value);
            ++_length;

            if (thresholdPassed(_length, bucket.length)) {
                // Resize the bucket, as it passed the threshold.
                resize(newBucketSize(bucket.length));
            }
        } else {
            // We have this key already, so update the value.
            bucket[index]._value = value;
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
    @nogc @safe pure nothrow
    inout(V)* opBinaryRight(string op)(K key) inout if (op == "in") {
        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)
            (bucket, computeHash(key), key);

        if (bucket[index]._state == EntryState.empty) {
            return null;
        }

        return &(bucket[index]._value);
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
    @nogc @safe pure nothrow
    ref inout(V) opIndex(K key) inout {
        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)
            (bucket, computeHash(key), key);

        assert(
            bucket[index]._state != EntryState.empty,
            "Key not found in HashMap!"
        );

        return bucket[index]._value;
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
    @safe pure
    V get(V2)(K key, lazy V2 def) const if(is(V2 : V)) {
        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)
            (bucket, computeHash(key), key);

        if (bucket[index]._state == EntryState.empty) {
            return def();
        }

        return bucket[index]._value;
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
    @nogc @safe pure nothrow
    inout(V) get(K key) inout {
        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)
            (bucket, computeHash(key), key);

        if (bucket[index]._state == EntryState.empty) {
            return V.init;
        }

        return bucket[index]._value;
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
    @trusted pure
    ref V setDefault(V2)(K key, lazy V2 value) if (is(V2 : V)) {
        size_t hash = computeHash(key);

        if (bucket.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(4);

            size_t index = hash & (bucket.length - 1);

            return (bucket[index] = Entry!(K, V)(hash, key, value()))._value;
        }

        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)(bucket, hash, key);

        if (bucket[index]._state == EntryState.empty) {
            // The entry is empty, so we can insert the value here.
            bucket[index] = Entry!(K, V)(hash, key, value());

            ++_length;

            if (thresholdPassed(_length, bucket.length)) {
                // Resize the bucket, as it passed the threshold.
                resize(newBucketSize(bucket.length));

                // Update the index, it has now changed.
                index = bucketSearch!(SearchFor.notDeleted, K, V)
                    (bucket, hash, key);
            }
        }

        // Return a reference to the value.
        return bucket[index]._value;
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
    @trusted pure nothrow
    ref V setDefault(K key) {
        size_t hash = computeHash(key);

        if (bucket.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(4);

            size_t index = hash & (bucket.length - 1);

            return (bucket[index] = Entry!(K, V)(hash, key, V.init))._value;
        }

        size_t index =
            bucketSearch!(SearchFor.notDeleted, K, V)(bucket, hash, key);

        if (bucket[index]._state == EntryState.empty) {
            // The entry is empty, so we can insert the value here.
            bucket[index] = Entry!(K, V)(hash, key, V.init);

            ++_length;

            if (thresholdPassed(_length, bucket.length)) {
                // Resize the bucket, as it passed the threshold.
                resize(newBucketSize(bucket.length));

                // Update the index, it has now changed.
                index = bucketSearch!(SearchFor.notDeleted, K, V)
                    (bucket, hash, key);
            }
        }

        // Return a reference to the value.
        return bucket[index]._value;
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
    @nogc @safe pure nothrow
    bool remove(K key) {
        size_t hash = computeHash(key);

        size_t index =
            bucketSearch!(SearchFor.any, K, V)
            (bucket, hash, key);

        with(EntryState) final switch(bucket[index]._state) {
        case empty:
            return false;
        case deleted:
            return false;
        case occupied:
            --_length;
            // Clear the entry and mark it as deleted.
            // The entry is not marked empty, so we can skip over it
            // when searching, but yet fill it again when inserting.
            // We have to leave the key and hash behind so we can
            // search for deleted values.
            bucket[index]._value = V.init;
            bucket[index]._state = EntryState.deleted;

            return true;
        }
    }

    /**
     * The length of the map.
     *
     * Returns: The number of entries in the map, in constant time.
     */
    @nogc @safe pure nothrow
    @property
    size_t length() const {
        return _length;
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
            import std.math: ceil, log2;

            HashMap!(K, V) newMap;

            if (_length == 0) {
                // 0 is a special case.
                return newMap;
            } else if (_length <= 4) {
                newMap.bucket = new Entry!(K, V)[](4);
            } else {
                // Allocate a power of two bucket size large enough to fit this.
                newMap.bucket = new Entry!(K, V)[](
                    cast(size_t) 2 ^^ ceil(log2(_length))
                );
            }

            newMap._length = _length;

            copyToBucket(newMap.bucket);

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
    @nogc @safe pure nothrow
    bool opEquals(ref const(HashMap!(K, V)) otherMap) const {
        if (_length != otherMap._length) {
            return false;
        }

        originalBucketLoop: foreach(ref entry; bucket) {
            if (entry._state != EntryState.occupied) {
                // Skip holes in the container.
                continue;
            }

            size_t index =
                bucketSearch!(SearchFor.notDeleted, K, V)
                (otherMap.bucket, entry._hash, entry._key);

            if (otherMap.bucket[index]._state == EntryState.empty) {
                return false;
            }
        }

        return true;
    }

    /// ditto
    @nogc @safe pure nothrow
    bool opEquals(const(HashMap!(K, V)) otherMap) const {
        return opEquals(otherMap);
    }
}

template HashMapKeyType(T) {
    alias HashMapKeyType = typeof(ElementType!(typeof(T.bucket))._key);
}

template HashMapValueType(T) {
    alias HashMapValueType = typeof(ElementType!(typeof(T.bucket))._value);
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

    assert(map.bucket.length == 16);
}

// Test the 'in' operator.
unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    assert((4 in map) is null);

    assert(*(1 in map) == "a");
    assert(*(2 in map) == "b");
    assert(*(3 in map) == "c");
}

// Test get with default init
unittest {
    HashMap!(int, string) map;

    map[1] = "a";

    assert(map.get(1) == "a");
    assert(map.get(2) is null);
}

// Test get with a given default.
unittest {
    HashMap!(int, string) map;

    map[1] = "a";

    assert(map.get(1, "b") == "a");
    assert(map.get(2, "b") == "b");
}

// Test opEquals
unittest {
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

    // Remove the extra keys
    leftMap.remove("d");
    leftMap.remove("e");
    leftMap.remove("f");
    leftMap.remove("g");

    rightMap["a"] = "1";
    rightMap["b"] = "2";
    rightMap["c"] = "3";

    // Now the two maps should have different buckets, but they
    // should still be considered equal.
    assert(leftMap == rightMap);
}

// Test setDefault with default init
unittest {
    HashMap!(int, string) map;

    map[1] = "a";

    assert(map.setDefault(1) == "a");
    assert(map.setDefault(2) is null);

    assert(map.length == 2);

    assert(map[2] is null);
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
    Entry!(K, V)[] _bucket = null;
public:
    @nogc @safe pure nothrow
    this(Entry!(K, V)[] bucket) {
        foreach(index, ref entry; bucket) {
            if (entry._state == EntryState.occupied) {
                // Use a slice of the bucket starting here.
                _bucket = bucket[index .. $];

                return;
            }
        }
    }

    @nogc @trusted pure nothrow
    this(const(Entry!(K, V)[]) bucket) {
        this(cast(Entry!(K, V)[]) bucket);
    }

    @nogc @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    @nogc @safe pure nothrow
    @property
    bool empty() const {
        // We can check that the bucket is empty to check if this range is
        // empty, because we will clear it after we pop the last item.
        return _bucket.length == 0;
    }

    @nogc @safe pure nothrow
    @property
    ref inout(Entry!(K, V)) front() inout in {
        assert(!empty());
    } body {
        return _bucket[0];
    }

    @nogc @safe pure nothrow
    void popFront() in {
        assert(!empty());
    } body {
        foreach(index; 1 .. _bucket.length) {
            if (_bucket[index]._state == EntryState.occupied) {
                // Use a slice of the bucket starting here.
                _bucket = _bucket[index .. $];

                return;
            }
        }

        // Clear the bucket if we hit the end.
        _bucket = null;
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
        // Empty ranges should not have to traverse the bucket at all.
        return KeyValueRange!(K, V).init;
    }

    return KeyValueRange!(K, V)(map.bucket);
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
        map.bucket
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
        map.bucket
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

    // From the way the buckets are distributed, we know we'll get this back.
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
    private this()(auto ref Entry!(K, V)[] bucket) {
        _keyValueRange = KeyValueRange!(K, V)(bucket);
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

    return KeyRange!(K, V)(map.bucket);
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
        map.bucket
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
        map.bucket
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

    // From the way the buckets are distributed, we know we'll get this back.
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
    private this()(auto ref Entry!(K, V)[] bucket) {
        _keyValueRange = KeyValueRange!(K, V)(bucket);
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

    return ValueRange!(K, V)(map.bucket);
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
        map.bucket
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
        map.bucket
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
