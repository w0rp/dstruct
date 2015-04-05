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

    foreach(MapType; TypeTuple!(string[string], HashMap!(string, string))) {
        writeln();

        {
            auto mark = ScopedBenchmark("fill (small) (" ~ MapType.stringof ~ ")");

            foreach(i; 0 .. runsPerTest) {
                MapType map;

                map["abcdefghijkl"] = "abc";
                map["wgenwegwgewg"] = "abc";
                map["36in33l3n643"] = "abc";
                // Item 4: This should cause another alloc in the new map.
                map["36inwzv3n643"] = "abc";
                map["fxnrgegxigww"] = "abc";
                map["nwlt4n43b643"] = "abc";
                map["wzve35496f4d"] = "abc";
                // Item 8: This should cause another alloc in the new map.
                map["333n35353335"] = "abc";
                map["t36443643643"] = "abc";
                map["454464n43323"] = "abc";
                map["352352262362"] = "abc";
                map["n33539353353"] = "abc";
                map["f52352523523"] = "abc";
                map["235232235232"] = "abc";
                map["343353534n44"] = "abc";
                // Item 16: This should cause another alloc in the new map.
                map["353353535353"] = "abc";
                map["w3535353n353"] = "abc";
                map["32363i239233"] = "abc";
                map["bw4363b44334"] = "abc";
                map["34b433463643"] = "abc";
                map["nwk353445544"] = "abc";
                map["n436k34n6436"] = "abc";
                map["36n43n43n434"] = "abc";
                map["354346434444"] = "abc";
                map["n43k43544353"] = "abc";
                map["435636433463"] = "abc";
                map["463n43kn4363"] = "abc";
                map["4643n4636432"] = "abc";
                map["845b4c9u54kd"] = "abc";
                map["353463464364"] = "abc";
                map["44n63kln3363"] = "abc";
                // Item 32: This should cause the last allocation.
                map["464364363363"] = "abc";
            }
        }

        {
            auto mark = ScopedBenchmark("fill (small) and remove (" ~ MapType.stringof ~ ")");

            foreach(i; 0 .. runsPerTest) {
                MapType map;

                map["abcdefghijkl"] = "abc";
                map["wgenwegwgewg"] = "abc";
                map["36in33l3n643"] = "abc";
                // Item 4: This should cause another alloc in the new map.
                map["36inwzv3n643"] = "abc";
                map["fxnrgegxigww"] = "abc";
                map["nwlt4n43b643"] = "abc";
                map["wzve35496f4d"] = "abc";
                // Item 8: This should cause another alloc in the new map.
                map["333n35353335"] = "abc";
                map["t36443643643"] = "abc";
                map["454464n43323"] = "abc";
                map["352352262362"] = "abc";
                map["n33539353353"] = "abc";
                map["f52352523523"] = "abc";
                map["235232235232"] = "abc";
                map["343353534n44"] = "abc";
                // Item 16: This should cause another alloc in the new map.
                map["353353535353"] = "abc";
                map["w3535353n353"] = "abc";
                map["32363i239233"] = "abc";
                map["bw4363b44334"] = "abc";
                map["34b433463643"] = "abc";
                map["nwk353445544"] = "abc";
                map["n436k34n6436"] = "abc";
                map["36n43n43n434"] = "abc";
                map["354346434444"] = "abc";
                map["n43k43544353"] = "abc";
                map["435636433463"] = "abc";
                map["463n43kn4363"] = "abc";
                map["4643n4636432"] = "abc";
                map["845b4c9u54kd"] = "abc";
                map["353463464364"] = "abc";
                map["44n63kln3363"] = "abc";
                // Item 32: This should cause the last allocation.
                map["464364363363"] = "abc";

                map.remove("abcdefghijkl");
                map.remove("wgenwegwgewg");
                map.remove("36in33l3n643");
                map.remove("36inwzv3n643");
                map.remove("fxnrgegxigww");
                map.remove("nwlt4n43b643");
                map.remove("wzve35496f4d");
                map.remove("333n35353335");
                map.remove("t36443643643");
                map.remove("454464n43323");
                map.remove("352352262362");
                map.remove("n33539353353");
                map.remove("f52352523523");
                map.remove("235232235232");
                map.remove("343353534n44");
                map.remove("353353535353");
                map.remove("w3535353n353");
                map.remove("32363i239233");
                map.remove("bw4363b44334");
                map.remove("34b433463643");
                map.remove("nwk353445544");
                map.remove("n436k34n6436");
                map.remove("36n43n43n434");
                map.remove("354346434444");
                map.remove("n43k43544353");
                map.remove("435636433463");
                map.remove("463n43kn4363");
                map.remove("4643n4636432");
                map.remove("845b4c9u54kd");
                map.remove("353463464364");
                map.remove("44n63kln3363");
                map.remove("464364363363");
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

