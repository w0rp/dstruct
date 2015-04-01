module dstruct.map;

import core.memory;
import core.exception;

import std.range;

import dstruct.support;

private struct Entry(K, V) {
    Entry* next;
    size_t hash;
    K key;
    V value;

    @nogc @safe pure nothrow
    this(size_t _hash, ref K _key, ref V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }

    @nogc @safe pure nothrow
    this(size_t _hash, ref K _key, V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }

    @nogc @safe pure nothrow
    this(size_t _hash, K _key, ref V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }

    @nogc @safe pure nothrow
    this(size_t _hash, K _key, V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }
}

@nogc @safe pure nothrow
private size_t hashIndex(size_t hash, size_t length) in {
    assert(length > 0);
} body {
    return hash & (length - 1);
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

// Check that computeHash is doing the right thing.
unittest {
    int x = 1;
    int y = 2;
    int z = 3;

    assert(computeHash(x) == 1);
    assert(computeHash(y) == 2);
    assert(computeHash(z) == 3);
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

    private Entry!(K, V)*[] bucket;
    private size_t _length;

    @nogc @trusted pure nothrow
    private Entry!(K, V)* topEntry(ref K key) const {
        return cast(typeof(return))
            bucket[hashIndex(computeHash(key), bucket.length)];
    }

    @safe pure nothrow
    private void resize(size_t newBucketLength) in {
        assert(newBucketLength > bucket.length);
    } body {
        auto newBucket = new Entry!(K, V)*[newBucketLength];

        foreach(entry; bucket) {
            while (entry !is null) {
                auto oldNext = entry.next;
                entry.next = null;

                size_t index = hashIndex(entry.hash, newBucket.length);

                if (newBucket[index] is null) {
                    newBucket[index] = entry;
                } else {
                    auto newPrev = newBucket[index];

                    while (newPrev.next !is null) {
                        newPrev = newPrev.next;
                    }

                    newPrev.next = entry;
                }

                entry = oldNext;
            }
        }

        bucket = newBucket;
    }

    @safe pure nothrow
    private auto addNewEntry(size_t bucketIndex, Entry!(K, V)* newEntry) {
        if (++_length > bucket.length) {
            // The new length exceeds a threshold, so resize the bucket.
            resize(bucket.length * 2);

            // Compute the index again, as it has changed.
            bucketIndex = hashIndex(newEntry.hash, bucket.length);
        }

        if (bucket[bucketIndex] is null) {
            return bucket[bucketIndex] = newEntry;
        } else {
            auto entry = bucket[bucketIndex];

            while (entry.next !is null) {
                entry = entry.next;
            }

            return entry.next = newEntry;
        }
    }

    /**
     * Set a value in the map.
     *
     * Params:
     *     key = The key in the map.
     *     value = A value to set in the map.
     */
    @safe pure nothrow
    void opIndexAssign(V value, K key) {
        size_t hash = computeHash(key);

        if (bucket.length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(4);

            // Add in the first value.
            bucket[hashIndex(hash, bucket.length)] =
                new Entry!(K, V)(hash, key, value);
            return;
        }

        size_t bucketIndex = hashIndex(hash, bucket.length);

        if (auto entry = bucket[bucketIndex]) {
            do {
                if (entry.key == key) {
                    // We found a key match, so update the value and return.
                    entry.value = value;
                    return;
                }
            } while (entry.next !is null);

            if (++_length <= bucket.length) {
                // We can add on another without needing a resize.
                entry.next = new Entry!(K, V)(hash, key, value);
                return;
            }
        } else if (++_length <= bucket.length) {
            // We can slot this in right here without needing a resize.
            bucket[bucketIndex] = new Entry!(K, V)(hash, key, value);
            return;
        }

        // The new length exceeds a threshold, so resize the bucket.
        resize(bucket.length * 2);

        // Compute the index again, as it has changed.
        bucketIndex = hashIndex(hash, bucket.length);

        if (auto entry = bucket[bucketIndex]) {
            while (entry.next !is null) {
                entry = entry.next;
            }

            entry.next = new Entry!(K, V)(hash, key, value);
        } else {
            bucket[bucketIndex] = new Entry!(K, V)(hash, key, value);
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
    V* opBinaryRight(string op)(K key) const if (op == "in") {
        for (auto entry = topEntry(key); entry; entry = entry.next) {
            if (entry.key == key) {
                // We found it, so return a pointer to it.
                return &(entry.value);
            }
        }

        return null;
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
    ref V opIndex(K key) const {
        for (auto entry = topEntry(key); entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        assert(false, "Key not found in HashMap!");
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
        for (auto entry = topEntry(key); entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        return def;
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
    V get(K key) const {
        for (auto entry = topEntry(key); entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        return V.init;
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

            // Add in the first value.
            return (bucket[hashIndex(hash, bucket.length)] =
                new Entry!(K, V)(hash, key, value)).value;
        }

        size_t bucketIndex = hashIndex(hash, bucket.length);

        for (auto entry = bucket[bucketIndex]; entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        return addNewEntry(
            bucketIndex,
            new Entry!(K, V)(hash, key, value)
        ).value;
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

            // Add in the first value.
            return (bucket[hashIndex(hash, bucket.length)] =
                new Entry!(K, V)(hash, key, V.init)).value;
        }

        size_t bucketIndex = hashIndex(hash, bucket.length);

        for (auto entry = bucket[bucketIndex]; entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        return addNewEntry(
            bucketIndex,
            new Entry!(K, V)(hash, key, V.init)
        ).value;
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
        size_t bucketIndex = hashIndex(computeHash(key), bucket.length);
        auto arr = bucket[bucketIndex];

        Entry!(K, V)* lastEntry = null;
        Entry!(K, V)* entry = bucket[bucketIndex];

        while (entry !is null) {
            if (entry.key == key) {
                // We found a match, so remove the entry.
                if (lastEntry is null) {
                    bucket[bucketIndex] = entry.next;
                } else {
                    lastEntry.next = entry.next;
                }

                --_length;
                return true;
            }

            lastEntry = entry;
            entry = entry.next;
        }

        return false;
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
            import std.math;

            HashMap!(K, V) newMap;

            if (_length == 0) {
                // 0 is a special case.
                return newMap;
            } else if (_length <= 4) {
                newMap.bucket = new Entry!(K, V)*[4];
            } else {
                // Allocate a power of two bucket size large enough to fit this.
                newMap.bucket = new Entry!(K, V)*[
                    cast(size_t) 2 ^^ ceil(log2(_length))
                ];
            }

            newMap._length = _length;

            foreach(const(Entry!(K, V))* entry; bucket) {
                leftLoop: for(; entry; entry = entry.next) {
                    size_t newIndex = hashIndex(entry.hash, newMap.bucket.length);
                    auto otherEntry = newMap.bucket[newIndex];

                    if (otherEntry is null) {
                        newMap.bucket[newIndex] = new Entry!(K, V)(
                            entry.hash, entry.key, entry.value
                        );
                    } else {
                        // Skip ahead till we hit the last entry.
                        while (otherEntry.next !is null) {
                            otherEntry = otherEntry.next;
                        }

                        otherEntry.next = new Entry!(K, V)(
                            entry.hash, entry.key, entry.value
                        );
                    }
                }
            }

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

        foreach(const(Entry!(K, V))* entry; bucket) {
            leftLoop: for(; entry; entry = entry.next) {
                const(Entry!(K, V))* otherEntry = otherMap.bucket[
                    hashIndex(entry.hash, otherMap.bucket.length)
                ];

                for(; otherEntry; otherEntry = otherEntry.next) {
                    if (entry.hash == otherEntry.hash
                    && entry.key == otherEntry.key
                    && entry.value == otherEntry.value) {
                        // We found this entry in the other map,
                        // So search with the next entry.
                        continue leftLoop;
                    }
                }

                // No match found for this entry.
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
    alias HashMapKeyType = typeof(ElementType!(typeof(T.bucket)).key);
}

template HashMapValueType(T) {
    alias HashMapValueType = typeof(ElementType!(typeof(T.bucket)).value);
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

unittest {
    int[string] map = ["foo": 3];

    auto val1 = map["foo"];
    auto val2 = map.setDefault("bar", 4);

    assert(val1 == 3);
    assert(val2 == 4);
}

private struct EntryRange(K, V) {
private:
    Entry!(K, V)*[] _bucket;
    Entry!(K, V)* _entry;
public:
    @nogc @safe pure nothrow
    this(Entry!(K, V)*[] bucket) {
        _bucket = bucket;

        while(_bucket.length > 0) {
            _entry = _bucket[0];

            if (_entry !is null) {
                return;
            }

            _bucket = _bucket[1 .. $];
        }
    }

    @nogc @trusted pure nothrow
    this(const(Entry!(K, V)*[]) bucket) {
        this(cast(Entry!(K, V)*[]) bucket);
    }

    @nogc @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    @nogc @safe pure nothrow
    @property
    bool empty() const {
        return _entry is null;
    }

    @nogc @safe pure nothrow
    @property
    inout(Entry!(K, V)*) front() inout in {
        assert(!empty());
    } body {
        return _entry;
    }

    @nogc @safe pure nothrow
    void popFront() in {
        assert(!empty());
    } body {
        if (_entry.next !is null) {
            // We have a another entry in the linked list, so skip to that.
            _entry = _entry.next;
            return;
        }

        _bucket = _bucket[1 .. $];

        // Keep advancing until we find the start of another linked list,
        // or we run off the end.
        while (_bucket.length > 0) {
            _entry = _bucket[0];

            if (_entry !is null) {
                return;
            }

            _bucket = _bucket[1 .. $];
        }

        // Clear the entry if we hit the end.
        _entry = null;
    }
}

/**
 * This is a range which runs through a series of keys in map.
 */
struct KeyRange(K, V) {
private:
    EntryRange!(K, V) _entryRange;
public:
    @nogc @safe pure nothrow
    private this()(auto ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
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
        return _entryRange.empty;
    }

    ///
    @nogc @trusted pure nothrow
    @property
    ref inout(K) front() inout {
        return _entryRange.front.key;
    }

    ///
    @nogc @safe pure nothrow
    void popFront() {
        _entryRange.popFront();
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
    return KeyRange!(K, V)(map.bucket);
}

/// ditto
@nogc @trusted pure nothrow
auto byKey(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return KeyRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
        map.bucket
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byKey(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return KeyRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
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
    EntryRange!(K, V) _entryRange;
public:
    @nogc @safe pure nothrow
    private this()(auto ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
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
        return _entryRange.empty;
    }

    ///
    @nogc @trusted pure nothrow
    @property
    ref inout(V) front() inout {
        return _entryRange.front.value;
    }

    ///

    @nogc @safe pure nothrow
    void popFront() {
        _entryRange.popFront();
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
    return ValueRange!(K, V)(map.bucket);
}

/// ditto
@nogc @trusted pure nothrow
auto byValue(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return ValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
        map.bucket
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byValue(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return ValueRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
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

/**
 * An item from a map.
 *
 * The keys and the values in the map are references into the map itself.
 */
struct Item(K, V) {
private:
    Entry!(K, V)* _entry;

    @nogc @safe pure nothrow
    this(inout(Entry!(K, V)*) entry) inout in {
        assert(entry !is null);
    } body {
        _entry = entry;
    }
public:
    ///
    @disable this();

    /**
     * A key from the map.
     */
    @nogc @safe pure nothrow
    @property ref inout(K) key() inout {
        return _entry.key;
    }

    /**
     * A value from the map.
     */
    @nogc @safe pure
    @property ref inout(V) value() inout {
        return _entry.value;
    }
}

/**
 * A range through a series of items in the map.
 */
struct ItemRange(K, V) {
private:
    EntryRange!(K, V) _entryRange;
public:
    @nogc @safe pure nothrow
    private this()(auto ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
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
        return _entryRange.empty;
    }

    ///
    @nogc @safe pure nothrow
    @property
    inout(Item!(K, V)) front() inout {
        return typeof(return)(_entryRange.front);
    }

    ///
    @nogc @safe pure nothrow
    void popFront() {
        _entryRange.popFront();
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
    return ItemRange!(K, V)(map.bucket);
}

/// ditto
@nogc @trusted pure nothrow
auto byKeyValue(K, V)(auto ref const(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return ItemRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
        map.bucket
    );
}

/// ditto
@nogc @trusted pure nothrow
auto byKeyValue(K, V)(auto ref immutable(HashMap!(K, V)) map) {
    alias RealK = HashMapKeyType!(typeof(map));
    alias RealV = HashMapValueType!(typeof(map));

    return ItemRange!(RealK, RealV)(
        cast(Entry!(RealK, RealV)*[])
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
 * Get or create a value from/in an associative array.
 *
 * Given an associative array to modify, a key, and a
 * lazy evaluated default value, attempt to retrieve a value from
 * an associative array. If a value for the given key is not set,
 * set the provided default value in the associative array and
 * return that.
 *
 * The value will be returned by reference.
 *
 * Params:
 *     map = The associative array to modify.
 *     key = The key in the associative array.
 *     def = A lazy default value.
 *
 * Returns:
 *     A reference to the value in the associative array.
 */
@safe pure
ref V1 setDefault(K, V1, V2)(ref V1[K] map, K key, lazy V2 def)
if (is(V2 : V1)) {
    V1* valPtr = key in map;

    if (valPtr != null) {
        return *valPtr;
    }

    map[key] = def();

    return map[key];
}

/**
 * Get or create a value from/in an associative array.
 *
 * Given an associative array to modify and a key,
 * attempt to retrieve a value from the associative array.
 * If a value for the given key is not set, set the value in
 * the associative array to the default value for the value's type.
 *
 * The value will be returned by reference.
 *
 * Params:
 *     map = The associative array to modify.
 *     key = The key in the associative array.
 *
 * Returns:
 *     A reference to the value in the associative array.
 */
@safe pure nothrow
ref V setDefault(K, V)(ref V[K] map, K key) {
    V* valPtr = key in map;

    if (valPtr != null) {
        return *valPtr;
    }

    map[key] = V.init;

    return map[key];
}

unittest {
    int[string] map = ["foo": 3];

    auto val1 = map["foo"];
    auto val2 = map.setDefault("bar");

    assert(val1 == 3);
    assert(val2 == 0);
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

