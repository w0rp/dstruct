/**
 * This module defines an Option!T type and a related Some!T type for
 * dealing nullable data in a safe manner.
 */
module dstruct.option;

import std.traits: isPointer;

/**
 * This type represents a value which cannot be null by its contracts.
 */
struct Some(T) if (is(T == class) || isPointer!T) {
private:
    T _value;
public:
    /// Disable default construction for Some!T types.
    @disable this();

    /**
     * Construct this object by wrapping a given value.
     *
     * Params:
     *     value = The value to create the object with.
     */
    @safe pure nothrow
    this(U)(inout(U) value) inout if(is(U : T))
    in {
        assert(value !is null, "A null value was given to Some.");
    } body {
        _value = value;
    }

    /**
     * Get the value from this object.
     *
     * Returns: The value wrapped by this object.
     */
    @safe pure nothrow
    @property inout(T) get() inout
    out(value) {
        assert(value !is null, "Some returned null!");
    } body {
        return _value;
    }

    /**
     * Assign another value to this object.
     *
     * Params:
     *     value = The value to set.
     */
    @safe pure nothrow
    void opAssign(U)(U value) if(is(U : T))
    in {
        assert(value !is null, "A null value was given to Some.");
    } body {
        _value = value;
    }

    /// Implicitly convert Some!T objects to T.
    alias get this;
}

/**
 * A helper function for constructing Some!T values.
 *
 * Params:
 *     value = A value to wrap.
 *
 * Returns: The value wrapped in a non-nullable type.
 */
@safe pure nothrow
inout(Some!T) some(T)(inout(T) value) {
    return inout(Some!T)(value);
}

// Test basic usage.
unittest {
    class Klass {}
    struct Struct {}

    Some!Klass k = new Klass();
    k = new Klass();

    Klass k2 = k;

    Some!(Struct*) s = new Struct();

    Struct* s1 = s;
}

// Test immutable
unittest {
    class Klass {}

    immutable(Some!Klass) k = new immutable Klass();
}

// Test class hierarchies.
unittest {
    class Animal {}
    class Dog : Animal {}

    Some!Animal a = new Animal();
    a = new Dog();

    auto d = new Dog();

    d = cast(Dog) a;

    assert(d !is null);

    Some!Dog d2 = new Dog();

    Animal a2 = d2;
}

// Test conversion between wrapper types when wrapped types are compatible.
unittest {
    class Animal {}
    class Dog : Animal {}

    Some!Animal a = new Animal();
    Some!Dog d = new Dog();

    a = d;
}

// Test the wrapper function.
unittest {
    class Klass {}

    auto m = some(new Klass());
    auto c = some(new const Klass());
    auto i = some(new immutable Klass());

    assert(is(typeof(m) == Some!Klass));
    assert(is(typeof(c) == const(Some!Klass)));
    assert(is(typeof(i) == immutable(Some!Klass)));
}

/**
 * This type represents an optional value for T.
 *
 * This is a means of explicitly dealing with null values in every case.
 */
struct Option(T) if(is(T == class) || isPointer!T) {
private:
    T _value;
public:
    /**
     * Construct this object by wrapping a given value.
     *
     * Params:
     *     value = The value to create the object with.
     */
    @safe pure nothrow
    this(U)(inout(U) value) inout if(is(U : T)) {
        _value = value;
    }

    /**
     * Get the value from this object.
     *
     * Contracts ensure this value isn't null.
     *
     * Returns: Some value from this object.
     */
    @safe pure nothrow
    @property Some!T get()
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(_value);
    }

    /// ditto
    @trusted pure nothrow
    @property const(Some!T) get() const
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(cast(T) _value);
    }

    /// ditto
    @trusted pure nothrow
    @property immutable(Some!T) get() immutable
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(cast(T) _value);
    }

    /**
     * Returns: True if the value this option type does not hold a value.
     */
    @trusted pure nothrow
    @property bool isNull() const {
        return _value is null;
    }

    /**
     * Assign another value to this object.
     *
     * Params:
     *     value = The value to set.
     */
    @safe pure nothrow
    void opAssign(U)(U value) if(is(U : T)) {
        _value = value;
    }

    /**
     * Permit foreach over an option type.
     *
     * Example:
     * ---
     *     Option!T value = null;
     *
     *     foreach(someValue; value) {
     *         // We never enter this loop body.
     *     }
     *
     *     value = new T();
     *
     *     foreach(someValue; value) {
     *         // We enter this loop body exactly once.
     *     }
     * ---
     */
    int opApply(int delegate(Some!T) dg) {
        if (_value !is null) {
            return dg(Some!T(_value));
        }

        return 0;
    }

    /// ditto
    int opApply(int delegate(const(Some!T)) dg) const {
        if (_value !is null) {
            return dg(cast(const) Some!T(cast(T) _value));
        }

        return 0;
    }

    /// ditto
    int opApply(int delegate(immutable(Some!T)) dg) immutable {
        if (_value !is null) {
            return dg(cast(immutable) Some!T(cast(T) _value));
        }

        return 0;
    }

    /// Reverse iteration is exactly the same as forward iteration.
    alias opApplyReverse = opApply;
}

/**
 * A helper function for constructing Option!T values.
 *
 * Params:
 *     value = A value to wrap.
 *
 * Returns: The value wrapped in an option type.
 */
@safe pure nothrow
inout(Option!T) option(T)(inout(T) value) {
    return inout(Option!T)(value);
}

/// ditto
@safe pure nothrow
inout(Option!T) option(T)(inout(Some!T) value) {
    return option(value._value);
}

// Test basic usage for Option
unittest {
    class Klass {}
    struct Struct {}

    Option!Klass k = new Klass();
    k = new Klass();

    Klass k2 = k.get;

    Option!(Struct*) s = new Struct();

    Struct* s1 = s.get;
}

// Test class hierarchies for Option
unittest {
    class Animal {}
    class Dog : Animal {}

    Option!Animal a = new Animal();
    a = new Dog();

    auto d = new Dog();

    d = cast(Dog) a.get;

    assert(d !is null);

    Option!Dog d2 = new Dog();

    Animal a2 = d2.get;
}

// Test get across constness.
unittest {
    class Klass {}

    Option!Klass m = new Klass();
    const Option!Klass c = new const Klass();
    immutable Option!Klass i = new immutable Klass();

    auto someM = m.get();
    auto someC = c.get();
    auto someI = i.get();

    assert(is(typeof(someM) == Some!Klass));
    assert(is(typeof(someC) == const(Some!Klass)));
    assert(is(typeof(someI) == immutable(Some!Klass)));
}

// Test foreach on option across constness.
unittest {
    class Klass {}

    Option!Klass m = new Klass();
    const Option!Klass c = new const Klass();
    immutable Option!Klass i = new immutable Klass();

    size_t mCount = 0;
    size_t cCount = 0;
    size_t iCount = 0;

    foreach(val; m) {
        ++mCount;
    }

    foreach(val; c) {
        ++cCount;
    }

    foreach(val; i) {
        ++iCount;
    }

    assert(mCount == 1);
    assert(cCount == 1);
    assert(iCount == 1);
}

// Test empty foreach
unittest {
    class Klass {}

    Option!Klass m = null;
    const Option!Klass c = null;
    immutable Option!Klass i = null;

    size_t mCount = 0;
    size_t cCount = 0;
    size_t iCount = 0;

    foreach(val; m) {
        ++mCount;
    }

    foreach(val; c) {
        ++cCount;
    }

    foreach(val; i) {
        ++iCount;
    }

    assert(mCount == 0);
    assert(cCount == 0);
    assert(iCount == 0);
}

// Test foreach_reverse on option across constness.
unittest {
    class Klass {}

    Option!Klass m = new Klass();
    const Option!Klass c = new const Klass();
    immutable Option!Klass i = new immutable Klass();

    size_t mCount = 0;
    size_t cCount = 0;
    size_t iCount = 0;

    foreach_reverse(val; m) {
        ++mCount;
    }

    foreach_reverse(val; c) {
        ++cCount;
    }

    foreach_reverse(val; i) {
        ++iCount;
    }

    assert(mCount == 1);
    assert(cCount == 1);
    assert(iCount == 1);
}

// Test empty foreach_reverse
unittest {
    class Klass {}

    Option!Klass m = null;
    const Option!Klass c = null;
    immutable Option!Klass i = null;

    size_t mCount = 0;
    size_t cCount = 0;
    size_t iCount = 0;

    foreach_reverse(val; m) {
        ++mCount;
    }

    foreach_reverse(val; c) {
        ++cCount;
    }

    foreach_reverse(val; i) {
        ++iCount;
    }

    assert(mCount == 0);
    assert(cCount == 0);
    assert(iCount == 0);
}

// Test setting Option from Some
unittest {
    class Klass {}

    Option!Klass m = some(new Klass());
    const Option!Klass c = some(new const Klass());
    immutable Option!Klass i = some(new immutable Klass());

    Option!Klass m2 = option(some(new Klass()));
    const Option!Klass c2 = option(some(new const Klass()));
    immutable Option!Klass i2 = option(some(new immutable Klass()));


    Option!Klass m3;

    m3 = some(new Klass());
}

// Test isNull
unittest {
    class Klass {}

    Option!Klass m;

    assert(m.isNull);

    m = new Klass();

    assert(!m.isNull);
}

/**
 * This type represents a range over an optional type.
 *
 * This is a RandomAccessRange.
 */
struct OptionRange(T) if(is(T == class) || isPointer!T) {
private:
    T _value;
public:
    /**
     * Construct this range by wrapping a given value.
     *
     * Params:
     *     value = The value to create the range with.
     */
    @safe pure nothrow
    this(U)(U value) if(is(U : T)) {
        _value = value;
    }

    ///
    @trusted pure nothrow
    void popFront()
    in {
        assert(_value !is null, "Attempted to pop an empty range!");
    } body {
        static if(is(T == const) || is(T == immutable)) {
            // Force the pointer held here into being null.
            *(cast(void**) &_value) = null;
        } else {
            _value = null;
        }
    }

    ///
    alias popBack = popFront;

    ///
    @safe pure nothrow
    @property inout(T) front() inout {
        return _value;
    }

    ///
    alias back = front;

    ///
    @safe pure nothrow
    @property bool empty() const {
        return _value is null;
    }

    ///
    @safe pure nothrow
    @property typeof(this) save() {
        return this;
    }

    ///
    @safe pure nothrow
    @property size_t length() const {
        return _value !is null ? 1 : 0;
    }

    ///
    @safe pure nothrow
    inout(T) opIndex(size_t index) inout
    in {
        assert(index <= length, "Index out of bounds!");
    } body {
        return _value;
    }
}

/**
 * Create an OptionRange from an Option type.
 *
 * The range shall be empty when the option has no value,
 * and it shall have one item when the option has a value.
 *
 * Params:
 *     optionalValue = An optional value.
 *
 * Returns: A range of 0 or 1 values.
 */
@safe pure nothrow
OptionRange!T range(T)(Option!T optionalValue) {
    if (optionalValue.isNull) {
        return typeof(return).init;
    }

    return OptionRange!T(optionalValue.get);
}

/// ditto
@trusted pure nothrow
OptionRange!(const(T)) range(T)(const(Option!T) optionalValue) {
    return cast(typeof(return)) range(cast(Option!T)(optionalValue));
}

/// ditto
@trusted pure nothrow
OptionRange!(immutable(T)) range(T)(immutable(Option!T) optionalValue) {
    return cast(typeof(return)) range(cast(Option!T)(optionalValue));
}

// Test creating ranges from option types.
unittest {
    class Klass {}

    Option!Klass m = new Klass();
    const(Option!Klass) c = new const Klass();
    immutable(Option!Klass) i = new immutable Klass();

    auto mRange = m.range;
    auto cRange = c.range;
    auto iRange = i.range;

    assert(!mRange.empty);
    assert(!cRange.empty);
    assert(!iRange.empty);

    assert(mRange.length == 1);
    assert(cRange.length == 1);
    assert(iRange.length == 1);

    assert(mRange[0] is m.get);
    assert(cRange[0] is c.get);
    assert(iRange[0] is i.get);

    assert(mRange.front is mRange.back);
    assert(cRange.front is cRange.back);
    assert(iRange.front is iRange.back);

    auto mRangeSave = mRange.save;
    auto cRangeSave = cRange.save;
    auto iRangeSave = iRange.save;

    mRange.popFront();
    cRange.popFront();
    iRange.popFront();

    assert(mRange.empty);
    assert(cRange.empty);
    assert(iRange.empty);

    assert(mRange.length == 0);
    assert(cRange.length == 0);
    assert(iRange.length == 0);

    assert(!mRangeSave.empty);
    assert(!cRangeSave.empty);
    assert(!iRangeSave.empty);
}

unittest {
    import std.range;

    // Test that all of the essential properties hold for this type.
    static assert(isInputRange!(OptionRange!(void*)));
    static assert(isForwardRange!(OptionRange!(void*)));
    static assert(isBidirectionalRange!(OptionRange!(void*)));
    static assert(isRandomAccessRange!(OptionRange!(void*)));
    static assert(!isInfinite!(OptionRange!(void*)));
}


// Test std.algorithm integration
unittest {
    class Klass {
        int x = 3;
    }

    import std.algorithm;

    Option!Klass foo = new Klass();

    auto squareSum(R)(R range) {
        return reduce!((x, y) => x + y)(0, range.map!(val => val.x * val.x));
    }

    auto fooSum = squareSum(foo.range);

    import std.stdio;

    assert(fooSum == 9);

    Option!Klass bar;

    auto barSum = squareSum(bar.range);

    assert(barSum == 0);
}

