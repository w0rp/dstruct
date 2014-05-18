module dstruct.map;

import core.memory;
import core.exception;

private struct Entry(K, V) {
    Entry* next;
    size_t hash;
    K key;
    V value;

    @safe pure nothrow
    this(size_t _hash, ref K _key, ref V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }

    @safe pure nothrow
    this(size_t _hash, ref K _key, V _value) {
        hash = _hash;
        key = _key;
        value = _value;
    }
}

@safe pure nothrow
private size_t hashIndex(size_t hash, size_t length) {
    return hash % length;
}

private alias SafeGetHashType = size_t delegate(const(void*)) pure nothrow;

@trusted pure nothrow
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

private enum thresholdMultiplier = 0.75;

/**
 * This struct implements a hashmap type, much like the standard associative
 * array type.
 *
 * This map should be almost totally usable in @safe pure nothrow functions.
 *
 * An empty map will be a valid object, and will not result in any allocations.
 */
struct HashMap(K, V) {
    private Entry!(K, V)*[] bucket;
    private size_t _length;

    @trusted pure nothrow
    private Entry!(K, V)* topEntry(ref K key) const {
        return cast(Entry!(K, V)*)
            bucket[hashIndex(computeHash(key), bucket.length)];
    }

    @safe pure nothrow
    private void resize(size_t newBucketLength) in {
        assert(newBucketLength > bucket.length);
    } body {
        auto newBucket = new Entry!(K, V)*[newBucketLength];

        foreach(Entry!(K, V)* entry; bucket) {
            while (entry !is null) {
                Entry!(K, V)* oldNext = entry.next;
                entry.next = null;

                size_t index = hashIndex(entry.hash, newBucket.length);

                if (newBucket[index] is null) {
                    newBucket[index] = entry;
                } else {
                    Entry!(K, V)* newPrev = newBucket[index];

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
    private Entry!(K, V)* addNewEntry(
    size_t bucketIndex, size_t hash, ref K key, ref V value) {
        if (++_length > bucket.length * thresholdMultiplier) {
            // The new length exceeds a threshold, so resize the bucket.
            resize(bucket.length * 2);

            // Compute the index again, as it has changed.
            bucketIndex = hashIndex(hash, bucket.length);
        }

        if (bucket[bucketIndex] is null) {
            return bucket[bucketIndex] = new Entry!(K, V)(hash, key, value);
        } else {
            Entry!(K, V)* entry = bucket[bucketIndex];

            while (entry.next !is null) {
                entry = entry.next;
            }

            return entry.next = new Entry!(K, V)(hash, key, value);
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

        if (_length == 0) {
            // 0 length is a special case.
            _length = 1;
            resize(4);

            // Add in the first value.
            bucket[hashIndex(hash, bucket.length)] =
                new Entry!(K, V)(hash, key, value);
            return;
        }

        size_t bucketIndex = hashIndex(hash, bucket.length);

        for (auto entry = bucket[bucketIndex]; entry; entry = entry.next) {
            if (entry.key == key) {
                // We found a key match, so update the value and return.
                entry.value = value;
                return;
            }
        }

        // By this point we know there is no key match, so add a new entry.
        addNewEntry(bucketIndex, hash, key, value);
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
    @safe pure nothrow
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
    @safe pure nothrow
    ref V opIndex(K key) const {
        for (auto entry = topEntry(key); entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        onRangeError();
        assert(false);
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
    @safe pure nothrow
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
        size_t bucketIndex = hashIndex(hash, bucket.length);

        for (auto entry = bucket[bucketIndex]; entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        V tempValue = value;
        return addNewEntry(bucketIndex, hash, key, tempValue).value;
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
        size_t bucketIndex = hashIndex(hash, bucket.length);

        for (auto entry = bucket[bucketIndex]; entry; entry = entry.next) {
            if (entry.key == key) {
                return entry.value;
            }
        }

        V value;
        return addNewEntry(bucketIndex, hash, key, value).value;
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
    @safe pure nothrow
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
    @safe pure nothrow
    @property
    size_t length() {
        return _length;
    }
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
    size_t _index;
public:
    @safe pure nothrow
    this(ref Entry!(K, V)*[] bucket) {
        do {
            _entry = bucket[_index];

            if (_entry !is null) {
                // Only hold a reference to the bucket in the range if
                // we find an entry to start the range with.
                _bucket = bucket;
                return;
            }
        } while (++_index < bucket.length);
    }

    @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    @safe pure nothrow
    @property
    bool empty() const {
        return _entry is null;
    }

    @safe pure nothrow
    @property
    inout(Entry!(K, V)*) front() inout {
        if (empty()) {
            onRangeError();
        }

        return _entry;
    }

    @safe pure nothrow
    void popFront() {
        if (empty()) {
            onRangeError();
        }

        if (_entry.next !is null) {
            // We have a another entry in the linked list, so skip to that.
            _entry = _entry.next;
            return;
        }

        if (++_index >= _bucket.length) {
            // Advancing takes us out of the bucket, so clear all references
            // from the range now, which means the bucket can be collected
            // if it is no longer referenced elsewhere.
            _entry = null;
            _bucket = null;
            return;
        }

        // Keep advancing until we find the start of another linked list,
        // or we run off the end.
        do {
            _entry = _bucket[_index];

            if (_entry !is null) {
                return;
            }
        } while (++_index < _bucket.length);
    }
}

/**
 * This is a range which runs through a series of keys in map.
 */
struct KeyRange(K, V) {
private:
    EntryRange!(K, V) _entryRange;
public:
    private this(ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
    }

    ///
    @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    ///
    @safe pure nothrow
    @property
    bool empty() const {
        return _entryRange.empty;
    }

    ///
    @safe pure nothrow
    @property
    ref inout(K) front() inout {
        return _entryRange.front.key;
    }

    ///
    @safe pure nothrow
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
@safe pure nothrow
KeyRange!(K, V) keys(K, V)(ref HashMap!(K, V) map) {
    return KeyRange!(K, V)(map.bucket);
}

/// ditto
@safe pure nothrow
KeyRange!(K, V) keys(K, V)(HashMap!(K, V) map) {
    return keys(map);
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    int[] keyList;

    foreach(ref key; map.keys()) {
        keyList ~= key;
    }

    // From the way the buckets are distributed, we know we'll get this back.
    assert(keyList == [1, 2, 3]);
}

/**
 * This is a range which runs through a series of values in a map.
 */
struct ValueRange(K, V) {
private:
    EntryRange!(K, V) _entryRange;
public:
    @safe pure nothrow
    private this(ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
    }

    ///
    @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    ///
    @safe pure nothrow
    @property
    bool empty() const {
        return _entryRange.empty;
    }

    ///
    @safe pure nothrow
    @property
    ref inout(V) front() inout {
        return _entryRange.front.value;
    }

    ///
    @safe pure nothrow
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
@safe pure nothrow
ValueRange!(K, V) values(K, V)(ref HashMap!(K, V) map) {
    return ValueRange!(K, V)(map.bucket);
}

/// ditto
@safe pure nothrow
ValueRange!(K, V) values(K, V)(HashMap!(K, V) map) {
    return values(map);
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    string[] valueList = [];

    foreach(ref value; map.values()) {
        valueList ~= value;
    }

    // From the way the buckets are distributed, we know we'll get this back.
    assert(valueList == ["a", "b", "c"]);
}

/**
 * An item from a map.
 *
 * The keys and the values in the map are references into the map itself.
 */
struct Item(K, V) {
private:
    Entry!(K, V)* _entry;

    @safe pure nothrow
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
    @safe pure nothrow
    @property ref inout(K) key() inout {
        return _entry.key;
    }

    /**
     * A value from the map.
     */
    @safe pure nothrow
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
    this (ref Entry!(K, V)*[] bucket) {
        _entryRange = EntryRange!(K, V)(bucket);
    }

    ///
    @safe pure nothrow
    inout(typeof(this)) save() inout {
        return this;
    }

    ///
    @safe pure nothrow
    @property
    bool empty() const {
        return _entryRange.empty;
    }

    ///
    @safe pure nothrow
    @property
    inout(Item!(K, V)) front() inout {
        return typeof(return)(_entryRange.front);
    }

    ///
    @safe pure nothrow
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
@safe pure nothrow
ItemRange!(K, V) items(K, V)(ref HashMap!(K, V) map) {
    return ItemRange!(K, V)(map.bucket);
}

/// ditto
@safe pure nothrow
ItemRange!(K, V) items(K, V)(HashMap!(K, V) map) {
    return items(map);
}

unittest {
    HashMap!(int, string) map;

    map[1] = "a";
    map[2] = "b";
    map[3] = "c";

    int[] keyList;
    string[] valueList;

    foreach(item; map.items()) {
        keyList ~= item.key;
        valueList ~= item.value;
    }

    // From the way the buckets are distributed, we know we'll get this back.
    assert(keyList == [1, 2, 3]);
    assert(valueList == ["a", "b", "c"]);
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

    auto keyRange = func().keys();
    auto valueRange = func().values();
    auto itemRange = func().items();
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
@safe pure nothrow
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
