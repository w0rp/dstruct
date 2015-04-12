module dstruct.support;

import std.traits;

// Define a do-nothing nogc attribute so @nogc can be used,
// but functions tagged with it will still compile in
// older D compiler versions.
static if(__VERSION__ < 2066) { enum nogc = 1; }

/**
 * true if a type T can be duplicated through some means.
 */
template isDupable(T) {
    enum isDupable =
        // Implicit conversion from const to non-const is allowed.
        is(const(Unqual!T) : Unqual!T);
}

enum isAssignmentCopyable(T) = is(typeof(
    (inout int _ = 0) {
        T value = T.init;

        T value2 = value;
    }
));

