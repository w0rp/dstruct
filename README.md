# dstruct

This library offers a variety of data structures and operations on those
data structures in D.

## Quick Start

Check out the code somewhere and you can use it as a DUB package. Everything
in the library is some form of template, so this is a source library and
doesn't need to be built itself.

## Data Structures in This Library

* [WeakReference(T)](source/dstruct/weak_reference.d) - An implementation of weak references.
* [HashSet(T)](source/dstruct/set.d) - A garbage collected hashset type.
* [Matrix(T)](source/dstruct/matrix.d) - A garbage collected dynamic matrix type.
* [Matrix(T, rowCount, columnCount)](source/dstruct/matrix.d) - A static matrix value type.

## Design Philosophy

This library is designed with the following philosophy.

* Everything should be as ```@safe``` and ```pure``` as possible, to
  make it easier to write pure functions which are safe.
* Exceptions should only be thrown when not doing so would be unsafe.
* Any function which doesn't throw should be marked ```nothrow```.
* As much as possible, you should be able to reference memory in a safe
  manner instead of having to copy it, to cut down on allocation.
* If memory is going to be allocated, it should be done as little as possible,
  and when it happens it should *probably* be allocated on
  the garbage collected heap.
