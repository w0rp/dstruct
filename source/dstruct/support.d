module dstruct.support;

// Define a do-nothing nogc attribute so @nogc can be used,
// but functions tagged with it will still compile in
// older D compiler versions.
static if(__VERSION__ < 2066) { enum nogc = 1; }
