/*
Copyright (c) 2013, w0rp <devw0rp@gmail.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import core.stdc.stdlib : malloc, free;
import core.exception;

import std.typecons;
import std.traits;
import std.conv;
import std.functional;


/**
 * A matrix type. This is a 2D array of a guaranteed uniform size.
 */
final class Matrix(Number) if(isNumeric!Number) {
private:
    Number[] _data;
    size_t _rowCount;
    size_t _columnCount;

    // Given a row index, calculate the position in the 1D array where that
    // row begins.
    @safe pure nothrow
    size_t offset(size_t row) const {
        return row * _columnCount;
    }

    // The empty constructor is used for making a copy with dup.
    @safe pure nothrow
    this() {}
public:
    /**
     * Create an matrix from an array of data.
     *
     * Params:
     *     rowCount = The number of rows for the matrix.
     *     columnCount = The number of columns for the matrix.
     *     data = The array of data for the matrix.
     */
    @safe pure nothrow
    this(size_t rowCount, size_t columnCount, immutable(Number[]) data) immutable {
        _data = data;
        _rowCount = rowCount;
        _columnCount = columnCount;
    }

    // Copy-paste the constructors, because inout doesn't work with literals.

    /// ditto
    @safe pure nothrow
    this(size_t rowCount, size_t columnCount, const(Number[]) data) const {
        _data = data;
        _rowCount = rowCount;
        _columnCount = columnCount;
    }

    /// ditto
    @safe pure nothrow
    this(size_t rowCount, size_t columnCount, Number[] data) {
        _data = data;
        _rowCount = rowCount;
        _columnCount = columnCount;
    }

    /**
     * Create a matrix of a given size.
     *
     * Params:
     *     rowCount = The number of rows for the matrix.
     *     columnCount = The number of columns for the matrix.
     */
    @safe pure nothrow
    this(size_t rowCount, size_t columnCount) {
        if (rowCount == 0 || columnCount == 0) {
            return;
        }

        _data = new Number[](rowCount * columnCount);

        _rowCount = rowCount;
        _columnCount = columnCount;
    }

    /**
     * Create a matrix of a given size.
     *
     * Params:
     *     rowCount = The number of rows for the matrix.
     *     columnCount = The number of columns for the matrix.
     *     initial = An initial value for each cell in the matrix.
     */
    @safe pure nothrow
    this(size_t rowCount, size_t columnCount, Number initial) {
        this(rowCount, columnCount);

        foreach(i; 0 .. rowCount) {
            size_t off = offset(i);

            foreach(j; 0 .. columnCount) {
                _data[off + j] = initial;
            }
        }
    }

    @safe pure nothrow
    Matrix!Number dup() const {
        auto mat = new Matrix!Number();

        // We can't .dup in a nothrow function, but we can do this...
        mat._data = new Number[](_rowCount * _columnCount);
        mat._data[] = _data[];

        mat._rowCount = _rowCount;
        mat._columnCount = _columnCount;

        return mat;
    }

    @safe pure nothrow
    immutable(Matrix!Number) idup() const {
        return dup;
    }

    /// Returns: True if the matrix is empty.
    @safe pure nothrow
    @property bool empty() const {
        return _data.length == 0;
    }

    /// Returns: The number of rows in this matrix.
    @safe pure nothrow
    @property size_t rowCount() const {
        return _rowCount;
    }

    /// Returns: The number of columns in this matrix.
    @safe pure nothrow
    @property size_t columnCount() const {
        return _columnCount;
    }

    @trusted pure nothrow
    const(Number[]) opIndex(size_t row) const
    in {
        assert(row <= rowCount, "row out of bounds!");
    } body {
        size_t off = offset(row);

        return _data[off..off + _columnCount];
    }

    /**
     * Returns: A value from the matrix.
     */
    @safe pure nothrow
    Number opIndex(size_t row, size_t column) const
    in {
        assert(column <= columnCount, "column out of bounds!");
    } body {
        return _data[offset(row) + column];
    }

    /**
     * Returns: Set a value in the matrix.
     */
    @safe pure nothrow
    void opIndexAssign(Number value, size_t row, size_t column)
    in {
        assert(row <= rowCount, "row out of bounds!");
        assert(column <= columnCount, "column out of bounds!");
    } body {
        _data[offset(row) + column] = value;
    }

    /**
     * Overload for foreach(rowIndex, columnIndex, value; matrix) {}
     */
    @trusted
    int opApply(int delegate(ref size_t, ref size_t, ref Number) dg) {
        int result = 0;

        matrixLoop: foreach(row; 0 .. rowCount) {
            size_t off = offset(row);

            foreach(column; 0 .. columnCount) {
                result = dg(row, column, _data[off + column]);

                if (result) {
                    break matrixLoop;
                }
            }
        }

        return result;
    }

    /// Returns: true if two matrices are equal.
    @safe pure nothrow
    bool opEquals(OtherNumber)(const Matrix!OtherNumber other) const
    if (isNumeric!OtherNumber) {
        return _data == other._data;
    }

    /**
     * Modify this matrix, adding/subtracting values from another matrix.
     *
     * Example:
     * ---
     *     matrix += other_matrix;
     *     matrix -= yet_another_matrix;
     * ---
     *
     * Params:
     *     other = The other matrix.
     */
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)
    (const Matrix!OtherNumber other)
    if((op == "+" || op == "-") && is(OtherNumber : Number))
    in {
        assert(this.rowCount == other.rowCount);
        assert(this.columnCount == other.columnCount);
    } body {
        foreach(i; 0..rowCount) {
            size_t off = offset(i);

            foreach(j; 0..columnCount) {
                mixin(`_data[off + j]` ~ op ~ `= other._data[off + j];`);
            }
        }
    }

    /**
     * Add or subtract two matrices, yielding a new matrix.
     *
     * Params:
     *     other = The other matrix.
     *
     * Returns: A new matrix.
     */
    @safe pure nothrow
    Matrix!Number opBinary(string op, OtherNumber)
    (const Matrix!OtherNumber other) const
    if((op == "+" || op == "-") && is(OtherNumber : Number)) in {
        assert(this.rowCount == other.rowCount);
        assert(this.columnCount == other.columnCount);
    } out(val) {
        assert(this.rowCount == val.rowCount);
        assert(this.rowCount == val.rowCount);
    } body {
        // Copy this matrix.
        auto result = this.dup;

        mixin(`result ` ~ op ~ `= other;`);

        return result;
    }

    /**
     * Modify this matrix with a scalar value.
     */
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)(OtherNumber other)
    if(op != "in" && op != "~" && is(OtherNumber : Number)) {
        foreach(i; 0..rowCount) {
            size_t off = offset(i);

            foreach(j; 0..columnCount) {
                mixin(`_data[off + j] ` ~ op ~ `= other;`);
            }
        }
    }

    /**
     * Returns: A new matrix produce by combining a matrix and a scalar value.
     */
    @safe pure nothrow
    Matrix!Number opBinary(string op, OtherNumber)(OtherNumber other) const
    if(op != "in" && op != "~" && is(OtherNumber : Number)) {
        // Copy this matrix.
        auto result = this.dup;

        mixin(`result ` ~ op ~ `= other;`);

        return result;
    }
}


// Test basic matrix initialisation and foreach.
unittest {
    size_t rowCount = 4;
    size_t columnCount = 3;
    size_t expectedValue = 42;

    auto mat = new Matrix!int(rowCount, columnCount, expectedValue);

    size_t expectedRow = 0;
    size_t expectedColumn = 0;

    foreach(row, column, value; mat) {
        assert(row == expectedRow);
        assert(column == expectedColumn);
        assert(value == expectedValue);

        if (++expectedColumn == columnCount) {
            expectedColumn = 0;
            ++expectedRow;
        }
    }
}

// Test matrix referencing and copying
unittest {
    auto mat = new Matrix!int(3, 3);

    mat[0, 0] = 42;

    auto normalCopy = mat.dup;

    normalCopy[0, 0] = 27;

    assert(mat[0, 0] == 42, "Matrix .dup created a data reference!");

    immutable immutCopy = mat.idup;
}

// Test immutable initialisation for a matrix
unittest {
    immutable mat = new immutable Matrix!int(3, 3, [
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    ]);
}

// Test matrix addition/subtraction.
unittest {
    void runtest(string op)() {
        import std.stdio;

        size_t rowCount = 4;
        size_t columnCount = 4;

        int leftValue = 8;
        byte rightValue = 10;

        auto left = new Matrix!int(rowCount, columnCount, leftValue);
        auto right = new Matrix!byte(rowCount, columnCount, rightValue);

        auto result = mixin(`left` ~ op ~ `right`);
        auto expectedScalar = mixin(`leftValue` ~ op ~ `rightValue`);

        foreach(row, column, value; result) {
            assert(value == expectedScalar, `Matrix op failed: ` ~ op);
        }
    }

    runtest!"+";
    runtest!"-";
}

// Text matrix-scalar operations.
unittest {
    import std.stdio;

    void runtest(string op)() {
        size_t rowCount = 2;
        size_t columnCount = 3;

        // The results for these two values are always nonzero.
        long matrixValue = 1_234_567;
        int scalar = 11;

        auto matrix = new Matrix!long(rowCount, columnCount, matrixValue);

        auto result = mixin(`matrix` ~ op ~ `scalar`);

        auto expectedScalar = mixin(`matrixValue` ~ op ~ `scalar`);

        foreach(row, column, value; result) {
            assert(value == expectedScalar, `Matirix scalar op failed: ` ~ op);
        }
    }

    runtest!"+";
    runtest!"-";
    runtest!"*";
    runtest!"/";
    runtest!"%";
    runtest!"^^";
    runtest!"&";
    runtest!"|";
    runtest!"^";
    runtest!"<<";
    runtest!">>";
    runtest!">>>";
}

final class Rows(Number) if(isNumeric!Number) {
private:
    Matrix!Number _matrix;
    size_t _currentRow;
public:
    /**
     * Create a new rows range for a given matrix.
     */
    @safe pure nothrow
    this(Matrix!Number matrix) {
        _matrix = matrix;
    }

    /// Returns: true if the range is empty.
    @safe pure nothrow
    @property bool empty() const {
        return _currentRow >= _matrix.rowCount;
    }

    /// Advance to the next row.
    @safe pure nothrow
    void popFront() {
        assert(!empty, "Attempted popFront on an empty Rows range!");

        ++_currentRow;
    }

    /// Returns: The current row.
    @safe pure nothrow
    @property const(Number[]) front() const {
        assert(!empty, "Cannot get the front of an empty Rows range!");

        return _matrix[_currentRow];
    }
}

/**
 * Returns: A range through the matrix's rows.
 */
@safe pure nothrow
Rows!Number rows(Number)(Matrix!Number matrix) {
    return new typeof(return)(matrix);
}

unittest {
    auto mat = new Matrix!int(3, 3, [
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    ]);

    auto expected = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ];

    size_t rowIndex = 0;

    for (auto range = mat.rows; !range.empty; range.popFront) {
        assert(range.front == expected[rowIndex++]);
    }
}
