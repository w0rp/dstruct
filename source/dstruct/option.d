/**
 * This module defines an Option!T type and a related Some!T type for
 * dealing nullable data in a safe manner.
 */
module dstruct.option;

import dstruct.support;

import std.traits;
import std.typecons;

private struct SomeTypeMarker {}

private enum isSomeType(T) = is(typeof(T.marker) == SomeTypeMarker);

/**
 * This type represents a value which cannot be null by its contracts.
 */
struct Some(T) if (is(T == class) || isPointer!T) {
private:
    enum marker = SomeTypeMarker.init;
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
    @nogc @safe pure nothrow
    this(U)(inout(U) value) inout if(is(U : T))
    in {
        assert(value !is null, "A null value was given to Some.");
    } body {
        static assert(
            !is(U == typeof(null)),
            "Some!(" ~ T.stringof ~ ") cannot be constructed with null."
        );

        _value = value;
    }

    /**
     * Get the value from this object.
     *
     * Returns: The value wrapped by this object.
     */
    @nogc @safe pure nothrow
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
    @nogc @safe pure nothrow
    void opAssign(U)(U value) if(is(U : T))
    in {
        assert(value !is null, "A null value was given to Some.");
    } body {
        static assert(
            !is(U == typeof(null)),
            "Some!(" ~ T.stringof ~ ") cannot be assigned to with null."
        );

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
@nogc @safe pure nothrow
inout(Some!T) some(T)(inout(T) value) if (is(T == class) || isPointer!T) {
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
    @nogc @safe pure nothrow
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
    @nogc @safe pure nothrow
    @property Some!T get()
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(_value);
    }

    /// ditto
    @nogc @trusted pure nothrow
    @property const(Some!T) get() const
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(cast(T) _value);
    }

    /// ditto
    @nogc @trusted pure nothrow
    @property immutable(Some!T) get() immutable
    in {
        assert(_value !is null, "get called for a null Option type!");
    } body {
        return Some!T(cast(T) _value);
    }

    static if(is(T == class)) {
        /**
         * Given some type U, perform a dynamic cast on the class reference
         * held within this optional value, and return a new optional value
         * which may be null if the cast fails.
         *
         * Returns: A casted optional value.
         */
        @nogc pure nothrow
        inout(Option!U) dynamicCast(U)() inout {
            return Option!U(cast(U) _value);
        }
    }

    /**
     * Return some value from this reference, or a default value
     * by calling a callable argument. (function pointer, delegate, etc.)
     *
     * The delegate can return a nullable type, but if the type is null
     * an assertion error will be triggered, supposing the program is
     * running in debug mode. The delegate may also return a Some type.
     *
     * Params:
     *     dg = Some delegate returning a value.
     *
     * Returns: This value, if the delegate's value if it is null.
     */
    Some!T or(DG)(DG dg)
    if (
        isCallable!DG
        && (ParameterTypeTuple!DG).length == 0
        && is(ReturnType!DG : T)
    ) {
        if (_value is null) {
            static if(isSomeType!(ReturnType!DG)) {
                return cast(Some!T) dg();
            } else {
                return Some!T(dg());
            }
        }

        return some(_value);
    }

    /// ditto
    const(Some!T) or(DG)(DG dg) const
    if (
        isCallable!DG
        && (ParameterTypeTuple!DG).length == 0
        && is(Unqual!(ReturnType!DG) : Unqual!T)
    ) {
        if (_value is null) {
            static if(isSomeType!(ReturnType!DG)) {
                return cast(const(Some!T)) dg();
            } else {
                return const(Some!T)(dg());
            }
        }

        return some(_value);
    }

    /// ditto
    immutable(Some!T) or(DG)(DG dg) immutable
    if (
        isCallable!DG
        && (ParameterTypeTuple!DG).length == 0
        && is(Unqual!(ReturnType!DG) : Unqual!T)
    ) {
        if (_value is null) {
            static if(isSomeType!(ReturnType!DG)) {
                return cast(immutable(Some!T)) dg();
            } else {
                return immutable(Some!T)(dg());
            }
        }

        return some(_value);
    }

    /**
     * Returns: True if the value this option type does not hold a value.
     */
    @nogc @safe pure nothrow
    @property bool isNull() const {
        return _value is null;
    }

    /**
     * Assign another value to this object.
     *
     * Params:
     *     value = The value to set.
     */
    @nogc @safe pure nothrow
    void opAssign(U)(U value) if(is(U : T)) {
        _value = value;
    }
}

/**
 * A helper function for constructing Option!T values.
 *
 * Params:
 *     value = A value to wrap.
 *
 * Returns: The value wrapped in an option type.
 */
@nogc @safe pure nothrow
inout(Option!T) option(T)(inout(T) value) if (is(T == class) || isPointer!T) {
    return inout(Option!T)(value);
}

/// ditto
@nogc @safe pure nothrow
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

// Test dynamicCast across constness.
unittest {
    class Klass {}
    class SubKlass {}

    Option!Klass m = new Klass();
    const Option!Klass c = new const Klass();
    immutable Option!Klass i = new immutable Klass();

    auto subM = m.dynamicCast!SubKlass;
    auto subC = c.dynamicCast!SubKlass;
    auto subI = i.dynamicCast!SubKlass;

    assert(is(typeof(subM) == Option!SubKlass));
    assert(is(typeof(subC) == const(Option!SubKlass)));
    assert(is(typeof(subI) == immutable(Option!SubKlass)));
}

// Test .or, with the nice type qualifiers.
unittest {
    class Klass {}

    @safe pure nothrow
    void runTest() {
        Option!Klass m;
        const Option!Klass c;
        immutable Option!Klass i;

        auto someM = m.or(()=> some(new Klass()));
        auto someC = c.or(()=> some(new const(Klass)()));
        auto someI = i.or(()=> some(new immutable(Klass)()));

        assert(is(typeof(someM) == Some!Klass));
        assert(is(typeof(someC) == const(Some!Klass)));
        assert(is(typeof(someI) == immutable(Some!Klass)));

        auto someOtherM = m.or(()=> new Klass());
        auto someOtherC = c.or(()=> new const(Klass)());
        auto someOtherI = i.or(()=> new immutable(Klass)());

        assert(is(typeof(someOtherM) == Some!Klass));
        assert(is(typeof(someOtherC) == const(Some!Klass)));
        assert(is(typeof(someOtherI) == immutable(Some!Klass)));
    }

    runTest();
}

// Test .or with subclasses
unittest {
    class Klass {}
    class SubKlass : Klass {}

    @safe pure nothrow
    void runTest() {
        Option!Klass m;
        const Option!Klass c;
        immutable Option!Klass i;

        auto someM = m.or(()=> some(new SubKlass()));
        auto someC = c.or(()=> some(new const(SubKlass)()));
        auto someI = i.or(()=> some(new immutable(SubKlass)()));

        assert(is(typeof(someM) == Some!Klass));
        assert(is(typeof(someC) == const(Some!Klass)));
        assert(is(typeof(someI) == immutable(Some!Klass)));

        auto someOtherM = m.or(()=> new SubKlass());
        auto someOtherC = c.or(()=> new const(SubKlass)());
        auto someOtherI = i.or(()=> new immutable(SubKlass)());

        assert(is(typeof(someOtherM) == Some!Klass));
        assert(is(typeof(someOtherC) == const(Some!Klass)));
        assert(is(typeof(someOtherI) == immutable(Some!Klass)));
    }

    runTest();
}

// Test .or with bad functions
unittest {
    class Klass {}

    @system
    Klass mutFunc() {
        if (1 == 2) {
            throw new Exception("");
        }

        return new Klass();
    }

    @system
    const(Klass) constFunc() {
        if (1 == 2) {
            throw new Exception("");
        }

        return new const(Klass)();
    }

    @system
    immutable(Klass) immutableFunc() {
        if (1 == 2) {
            throw new Exception("");
        }

        return new immutable(Klass)();
    }

    Option!Klass m;
    const Option!Klass c;
    immutable Option!Klass i;

    auto someM = m.or(&mutFunc);
    auto someC = c.or(&constFunc);
    auto someI = i.or(&immutableFunc);

    assert(is(typeof(someM) == Some!Klass));
    assert(is(typeof(someC) == const(Some!Klass)));
    assert(is(typeof(someI) == immutable(Some!Klass)));
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
    @nogc @safe pure nothrow
    this(U)(U value) if(is(U : T)) {
        _value = value;
    }

    ///
    @nogc @trusted pure nothrow
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
    @nogc @safe pure nothrow
    @property inout(T) front() inout {
        return _value;
    }

    ///
    alias back = front;

    ///
    @nogc @safe pure nothrow
    @property bool empty() const {
        return _value is null;
    }

    ///
    @nogc @safe pure nothrow
    @property typeof(this) save() {
        return this;
    }

    ///
    @nogc @safe pure nothrow
    @property size_t length() const {
        return _value !is null ? 1 : 0;
    }

    ///
    @nogc @safe pure nothrow
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
@nogc @safe pure nothrow
OptionRange!T range(T)(Option!T optionalValue) {
    if (optionalValue.isNull) {
        return typeof(return).init;
    }

    return OptionRange!T(optionalValue.get);
}

/// ditto
@nogc @trusted pure nothrow
OptionRange!(const(T)) range(T)(const(Option!T) optionalValue) {
    return cast(typeof(return)) range(cast(Option!T)(optionalValue));
}

/// ditto
@nogc @trusted pure nothrow
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

unittest {
    class Klass {}
    class SubKlass : Klass {}
    class SubSubKlass : SubKlass {}

    Some!Klass nonNullValue = some(new Klass());

    Option!Klass optionalValue;

    // You can check if the value is null.
    assert(optionalValue.isNull);

    // You can assign Some!T values to it.
    optionalValue = nonNullValue;

    assert(!optionalValue.isNull);

    // You can assign regular values, including derived types.
    // Dervied Some!T values will work too.
    optionalValue = new SubKlass();

    assert(!optionalValue.isNull);

    // You can get the value out as a type Some!T from it and cast it
    // to the class type. The dynamic cast will be used.
    assert(cast(SubKlass) optionalValue.get() !is null);

    // Using the right dynamic cast means that the value from that can be null,
    // when the dynamic cast fails.
    assert(cast(SubSubKlass) optionalValue.get() is null);

    // Or create a new optional value with a cast, which will also work
    // when the optional value is null.
    //
    // This method will not exist for optional pointers.
    Option!SubSubKlass subValue = optionalValue.dynamicCast!SubSubKlass;

    assert(subValue.isNull);

    // We can assign back to a regular class reference.
    Klass regularReference;

    // When the optional value is null, the range will by empty.
    optionalValue = null;

    foreach(value; optionalValue.range) {
        regularReference = value;
    }

    assert(regularReference is null);

    // We there's a value, the range will have length 1.
    optionalValue = new Klass();

    foreach(value; optionalValue.range) {
        regularReference = value;
    }

    assert(regularReference !is null);

    optionalValue = null;

    // Finally, we can use a method to use a default value.
    // If the default is null, an assertion error will be thrown
    // in debug mode. Any callable will work with .or, and the callable
    // can also return a Some!T type.
    Some!Klass someOtherValue = optionalValue.or(() => new SubKlass());
}
