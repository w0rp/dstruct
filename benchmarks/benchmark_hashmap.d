import std.datetime;
import std.stdio;

import dstruct.support;
import dstruct.map;

struct ScopedBenchmark {
private:
    StopWatch _watch;
    string _message;
public:
    @disable this();
    @disable this(this);

    this(string message) {
        _message = message;
        _watch.start();
    }

    ~this() {
        _watch.stop();

        writefln("%s: %d usecs", _message, _watch.peek.usecs);
    }
}

struct BadHashObject {
    int value;

    this(int value) {
        this.value = value;
    }

    @safe nothrow
    size_t toHash() const {
        return value / 10;
    }

    @nogc @safe nothrow pure
    bool opEquals(ref const BadHashObject other) const {
        return value == other.value;
    }

}

size_t runsPerTest = 50;
int testContainerSize = 10_000;

void main(string[] argv) {
    import std.typetuple;
    import core.memory;

    // Disable collections just in case they interrupt execution.
    // This could throw the benchmarks off.
    GC.disable();

    foreach(MapType; TypeTuple!(int[int], HashMap!(int, int))) {
        writeln();

        {
            auto mark = ScopedBenchmark("fill (" ~ MapType.stringof ~ ")");

            foreach(i; 0 .. runsPerTest) {
                MapType map;

                foreach(num; 0 .. testContainerSize) {
                    map[num] = num;
                }
            }
        }

        {
            auto mark = ScopedBenchmark("fill and remove (" ~ MapType.stringof ~ ")");

            foreach(i; 0 .. runsPerTest) {
                MapType map;

                foreach(num; 0 .. testContainerSize) {
                    map[num] = num;
                }

                foreach(num; 0 .. testContainerSize) {
                    map.remove(num);
                }
            }

        }

        {
            auto mark = ScopedBenchmark("fill and lookup (" ~ MapType.stringof ~ ")");

            foreach(i; 0 .. runsPerTest) {
                MapType map;

                foreach(num; 0 .. testContainerSize) {
                    map[num] = num;
                }

                foreach(num; 0 .. testContainerSize) {
                    auto ptr = num in map;
                }
            }
        }
    }

    writeln();

    {
        auto mark = ScopedBenchmark("fill, pre-allocated");

        foreach(i; 0 .. runsPerTest) {
            auto map = HashMap!(int, int)(testContainerSize);

            foreach(num; 0 .. testContainerSize) {
                map[num] = num;
            }
        }
    }

    {
        auto mark = ScopedBenchmark("fill and lookup (heavy collision)");

        foreach(i; 0 .. runsPerTest) {
            HashMap!(BadHashObject, int) map;

            foreach(num; 0 .. testContainerSize) {
                auto obj = BadHashObject(num);

                map[obj] = num;
            }

            foreach(num; 0 .. testContainerSize) {
                auto ptr = BadHashObject(num) in map;
            }
        }
    }

    writeln();
}

