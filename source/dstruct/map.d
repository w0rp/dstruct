module dstruct.map;

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

unittest {
    int[string] map = ["foo": 3];

    auto val1 = map["foo"];
    auto val2 = map.setDefault("bar", 4);

    assert(val1 == 3);
    assert(val2 == 4);
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
