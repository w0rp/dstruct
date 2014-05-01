/**
 * This module defines a matrix data structure and various operations
 * on this data structure. All operations are @safe pure nothrow,
 * so they can be used in any such function, and the results of any
 * operation can be implicitly converted to an immutable type.
 */
module dstruct.matrix;

import std.traits;

// A private implementation of matrix multiplication for use in types.
private auto matrixMultiply(ResultType, T, U)
(ref ResultType result, ref const(T) left, ref const(U) right) {
    foreach(row; 0 .. result.rowCount) {
        foreach(column; 0 .. result.columnCount) {
            Unqual!(typeof(result[0, 0])) value = left[row, 0] * right[0, column];

            foreach(pivot; 1 .. left.columnCount) {
                value += left[row, pivot] * right[pivot, column];
            }

            result[row, column] = value;
        }
    }

    return result;
}

/**
 * A matrix type. This is a 2D array of a guaranteed uniform size.
 */
struct Matrix(Number) if(isNumeric!Number) {
private:
    Number[] _data;
    size_t _rowCount;
    size_t _columnCount;
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
     * Returns: A new duplicate of this matrix.
     */
    @safe pure nothrow
    Matrix!Number dup() const {
        Matrix!Number mat;

        // We can't .dup in a nothrow function, but we can do this...
        mat._data = new Number[](_rowCount * _columnCount);
        mat._data[] = _data[];

        mat._rowCount = _rowCount;
        mat._columnCount = _columnCount;

        return mat;
    }

    /**
     * Returns: A new immutable duplicate of this matrix.
     */
    @safe pure nothrow
    immutable(Matrix!Number) idup() const {
        return dup();
    }

    /**
     * When calling .idup on an already immutable matrix, the reference
     * to the same immutable matrix is returned. It should be safe to
     * share the immutable memory in this manner.
     *
     * Returns: A reference to this immutable matrix.
     */
    @safe pure nothrow
    immutable(Matrix!Number) idup() immutable {
        // There's no need to copy immutable to immutable, share it!
        return this;
    }

    unittest {
        immutable m = immutable Matrix!int(1, 1);

        // Make sure this doesn't actually duplicate.
        assert(m._data is m._data);

        auto o = Matrix!int(1, 1);

        // Make sure this still does.
        assert(o.idup._data !is o._data);
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

    /// Returns: true if the matrix is a square matrix.
    @safe pure nothrow
    @property bool isSquare() const {
        return _rowCount == _columnCount;
    }

    /**
     * Slice out a row from the matrix. Modifying this
     * slice will modify the matrix, unless it is copied.
     *
     * Params:
     *    row = A row index.
     *
     * Returns: A slice of the row of the matrix.
     */
    @trusted pure nothrow
    inout(Number[]) opIndex(size_t row) inout
    in {
        assert(row <= rowCount, "row out of bounds!");
    } body {
        size_t offset = row * _columnCount;

        return _data[offset .. offset + _columnCount];
    }

    /**
     * Params:
     *    row = A row index.
     *    column = A column index.
     *
     * Returns: A value from the matrix
     */
    @safe pure nothrow
    ref inout(Number) opIndex(size_t row, size_t column) inout
    in {
        assert(column <= columnCount, "column out of bounds!");
    } body {
        return _data[row * _columnCount + column];
    }

    /**
     * Overload for foreach(rowIndex, columnIndex, value; matrix) {}
     */
    @trusted
    int opApply(int delegate(ref size_t, ref size_t, ref Number) dg) {
        int result = 0;

        matrixLoop: foreach(row; 0 .. rowCount) {
            size_t offset = row * columnCount;

            foreach(column; 0 .. columnCount) {
                result = dg(row, column, _data[offset + column]);

                if (result) {
                    break matrixLoop;
                }
            }
        }

        return result;
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
     *     other = Another matrix with an implicitly convertible numeric type.
     */
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)
    (const Matrix!OtherNumber other)
    if((op == "+" || op == "-") && is(OtherNumber : Number))
    in {
        assert(this.rowCount == other.rowCount);
        assert(this.columnCount == other.columnCount);
    } body {
        foreach(i; 0.._data.length) {
            mixin(`_data[i]` ~ op ~ `= other._data[i];`);
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
    (ref const Matrix!OtherNumber other) const
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
    
    /// ditto
    @safe pure nothrow
    Matrix!Number opBinary(string op, OtherNumber)
    (const Matrix!OtherNumber other) const
    if((op == "+" || op == "-") && is(OtherNumber : Number)) {
        opBinary!(op, OtherNumber)(other);
    }

    /**
     * Multiply two matrices.
     *
     * Given a matrix of size (m, n) and a matrix of size (o, p).
     * This operation can only work if n == o.
     * The resulting matrix will be size (m, p).
     *
     * Params:
     *     other = Another matrix
     *
     * Returns: The product of two matrices.
     */
    @safe pure nothrow
    Matrix!Number opBinary(string op, OtherNumber)
    (ref const Matrix!OtherNumber other) const
    if((op == "*") && is(OtherNumber : Number)) in {
        assert(this.columnCount == other.rowCount);
    } out(val) {
        assert(val.rowCount == this.rowCount);
        assert(val.columnCount == other.columnCount);
    } body {
        auto result = Matrix!Number(this.rowCount, other.columnCount);

        matrixMultiply(result, this, other);

        return result;
    }
    
    /// ditto
    @safe pure nothrow
    Matrix!Number opBinary(string op, OtherNumber)
    (const Matrix!OtherNumber other) const
    if((op == "*") && is(OtherNumber : Number)) in {
        opBinary!(op, OtherNumber)(other);
    }

    /// ditto
    @safe pure nothrow
    Matrix!OtherNumber opBinary(string op, OtherNumber)
    (ref const Matrix!OtherNumber other) const
    if((op == "*") && !is(Number == OtherNumber) && is(Number : OtherNumber)) in {
        assert(this.columnCount == other.rowCount);
    } out(val) {
        assert(val.rowCount == this.rowCount);
        assert(val.columnCount == other.columnCount);
    } body {
        auto result = Matrix!OtherNumber(this.rowCount, other.columnCount);

        matrixMultiply(result, this, other);

        return result;
    }

    /// ditto
    @safe pure nothrow
    Matrix!OtherNumber opBinary(string op, OtherNumber)
    (const Matrix!OtherNumber other) const 
    if((op == "*") && !is(Number == OtherNumber) && is(Number : OtherNumber)) {
        opBinary!(op, OtherNumber)(other);
    }

    /**
     * Modify this matrix with a scalar value.
     */
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)(OtherNumber other)
    if(op != "in" && op != "~" && is(OtherNumber : Number)) {
        foreach(i; 0.._data.length) {
            mixin(`_data[i]` ~ op ~ `= other;`);
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

    /**
     * Returns: true if two matrices are equal and have the same type.
     */
    @safe pure nothrow
    bool opEquals(ref const Matrix!Number other) const {
         return _rowCount == other._rowCount
            && _columnCount == other._columnCount
            && _data == other._data;
    }
    
    /// ditto
    @safe pure nothrow
    bool opEquals(const Matrix!Number other) const {
        return opEquals(other);
    }
}

// Test basic matrix initialisation and foreach.
unittest {
    size_t rowCount = 4;
    size_t columnCount = 3;
    int expectedValue = 42;

    auto mat = Matrix!int(rowCount, columnCount, [
        42, 42, 42,
        42, 42, 42,
        42, 42, 42,
        42, 42, 42
    ]);

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
    auto mat = Matrix!int(3, 3);

    mat[0, 0] = 42;

    auto normalCopy = mat.dup;

    normalCopy[0, 0] = 27;

    assert(mat[0, 0] == 42, "Matrix .dup created a data reference!");

    immutable immutCopy = mat.idup;
}

// Test modifying a matrix row externally.
unittest {
    auto mat = Matrix!int(3, 3);

    auto row = mat[0];

    row[0] = 3;
    row[1] = 4;
    row[2] = 7;

    assert(mat[0] == [3, 4, 7]);
}

// Test immutable initialisation for a matrix
unittest {
    immutable mat = immutable Matrix!int(3, 3, [
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

        auto left = Matrix!int(rowCount, columnCount, [
            8, 8, 8, 8,
            8, 8, 8, 8,
            8, 8, 8, 8,
            8, 8, 8, 8,
        ]);

        auto right = Matrix!byte(rowCount, columnCount, [
            10, 10, 10, 10,
            10, 10, 10, 10,
            10, 10, 10, 10,
            10, 10, 10, 10,
        ]);

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

        auto matrix = Matrix!long(rowCount, columnCount, [
            matrixValue, matrixValue, matrixValue,
            matrixValue, matrixValue, matrixValue,
        ]);

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

unittest {
    // Test matrix equality.

    auto left = Matrix!int(3, 3, [
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    ]);

    auto right = immutable Matrix!int(3, 3, [
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    ]);

    assert(left == right);
}

// Test matrix multiplication
unittest {
    // Let's test the Wikipedia example, why not?
    auto left = Matrix!int(2, 3, [
        2, 3, 4,
        1, 0, 0
    ]);

    auto right = Matrix!int(3, 2, [
        0, 1000,
        1, 100,
        0, 10
    ]);

    auto result = left * right;

    int[][] expected = [
        [3, 2340],
        [0, 1000]
    ];


    foreach(i; 0..2) {
        foreach(j; 0..2) {
            assert(result[i, j] == expected[i][j]);
        }
    }
}

// Test matrix multiplication, with a numeric type on the 
// left which implicitly converts to the right.
unittest {
    auto left = Matrix!int(1, 1);
    auto right = Matrix!long(1, 1);

    Matrix!long result = left * right;
}

/**
 * This class defines a range of rows over a matrix.
 */
struct Rows(Number) if(isNumeric!Number) {
private:
    const(Number)[] _data;
    size_t _columnCount;
public:
    /**
     * Create a new rows range for a given matrix.
     */
    @safe pure nothrow
    this(ref const Matrix!Number matrix) {
        _data = matrix._data;
        _columnCount = matrix._columnCount;
    }
    
    /// ditto
    @safe pure nothrow
    this(const Matrix!Number matrix) {
        this(matrix);
    }

    /// Returns: true if the range is empty.
    @safe pure nothrow
    @property bool empty() const {
        return _data.length == 0;
    }

    /// Advance to the next row.
    @safe pure nothrow
    void popFront() {
        assert(!empty, "Attempted popFront on an empty Rows range!");
        
        _data = _data[_columnCount .. $];
    }

    /// Returns: The current row.
    @safe pure nothrow
    @property const(Number[]) front() const {
        assert(!empty, "Cannot get the front of an empty Rows range!");
        
        return this[0];
    }

    /// Save a copy of this range.
    @safe pure nothrow
    Rows!Number save() const {
        return this;
    }

    /// Retreat a row backwards.
    @safe pure nothrow
    void popBack() {
        assert(!empty, "Attempted popBack on an empty Rows range!");
        
        _data = _data[0 .. $ - _columnCount];
    }

    /// Returns: The row at the end of the range.
    @safe pure nothrow
    @property const(Number[]) back() const {
        assert(!empty, "Cannot get the back of an empty Rows range!");
        
        return this[$ - 1];
    }

    /**
     * Params:
     *     index = An index for a row in the range.
     *
     * Returns: A row at an index in the range.
     */
    @safe pure nothrow
    @property const(Number[]) opIndex(size_t index) const in {
        assert(index >= 0, "Negative index given to Rows opIndex!");
        assert(index < length, "Out of bounds index given to Rows opIndex!");
    } body {
        size_t offset = index * _columnCount;
        
        return _data[offset .. offset + _columnCount];
    }

    /// Returns: The current length of the range.
    @safe pure nothrow
    @property size_t length() const {
        if (_data.length == 0) {
            return 0;
        }

        return _data.length / _columnCount;
    }
    
    /// ditto
    @safe pure nothrow
    @property size_t opDollar() const {
        return length;
    }
}

/**
 * Returns: A range through a matrix's rows.
 */
@safe pure nothrow
Rows!Number rows(Number)(Matrix!Number matrix) {
    return typeof(return)(matrix);
}

unittest {
    auto mat = Matrix!int(3, 3, [
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

    // Test InputRange stuff
    for (auto range = mat.rows; !range.empty; range.popFront) {
        assert(range.front == expected[rowIndex++]);
    }

    // Test ForwardRange

    auto range1 = mat.rows;

    range1.popFront;
    range1.popBack;

    auto range2 = range1.save;

    range1.popFront;

    assert(range2.front == [4, 5, 6]);

    rowIndex = 3;

    // Test BidirectionalRange
    for (auto range = mat.rows; !range.empty; range.popBack) {
        assert(range.back == expected[--rowIndex]);
    }

    // Test RandomAccessRange

    auto range3 = mat.rows;

    range3.popFront;
    range3.popBack;

    assert(range3.length == 1);
    assert(range3[0] == [4, 5, 6]);
}

// Test 0 size Matrix rows
unittest {
    Matrix!int mat;

    assert(mat.rows.length == 0); 
}

/**
 * A static matrix type. This is a value matrix value type created directly
 * on the stack.
 */
struct Matrix(Number, size_t _rowCount, size_t _columnCount)
if(isNumeric!Number && _rowCount > 0 && _columnCount > 0) {
    /// The number of rows in this matrix.
    enum rowCount = _rowCount;
    /// The number of columns in this matrix.
    enum columnCount = _columnCount;
    /// true if this matrix is a zero-sized matrix.
    enum empty = false;
    /// true if this matrix is a square matrix.
    enum isSquare = rowCount == columnCount;

    /// The data backing this matrix.
    Number[columnCount][rowCount] array2D;

    alias array2D this;

    /**
     * Construct this matrix from a 2 dimensional static array.
     *
     * Params:
     *     array2D = A 2 dimension array of the same size.
     */
    @safe pure nothrow
    this(ref const(Number[columnCount][rowCount]) data) inout {
        array2D = data;
    }

    /// ditto
    @safe pure nothrow
    this(const(Number[columnCount][rowCount]) data) inout {
        array2D = data;
    }

    /**
     * Construct this matrix directly from a series of numbers.
     * This constructor is designed to be executed at compile time.
     *
     * Params:
     *     numbers... = A series of numbers to initialise the matrix with.
     */
    @safe pure nothrow
    this(Number[rowCount * columnCount] numbers...) {
        foreach(row; 0 .. rowCount) {
            foreach(column; 0 .. columnCount) {
                array2D[row][column] = numbers[row * columnCount + column];
            }
        }
    }

    /**
     * Returns: A reference to this matrix's data as a 1D array.
     */
    @trusted pure nothrow
    @property
    ref inout(Number[rowCount * columnCount]) array1D() inout {
        return (cast(Number*)array2D.ptr)[0 .. rowCount * columnCount];
    }

    // Even with alias this, we still need this overload.
    /**
     * Params:
     *    row = A row index.
     *
     * Returns: A row from the matrix.
     */
    @safe pure nothrow
    ref inout(Number[columnCount]) opIndex(size_t row) inout {
        return array2D[row];
    }

    /**
     * Params:
     *    row = A row index.
     *    column = A column index.
     *
     * Returns: A value from the matrix
     */
    @safe pure nothrow
    ref inout(Number) opIndex(size_t row, size_t column) inout {
        return array2D[row][column];
    }

    /**
     * Overload for foreach(rowIndex, columnIndex, value; matrix) {}
     */
    @trusted
    int opApply(int delegate(ref size_t, ref size_t, ref Number) dg) {
        int result = 0;

        matrixLoop: foreach(row, rowArray; array2D) {
            foreach(column, value; rowArray) {
                result = dg(row, column, value);

                if (result) {
                    break matrixLoop;
                }
            }
        }

        return result;
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
     *     other = Another matrix with an implicitly convertible numeric type.
     */
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)
    (ref const(Matrix!(OtherNumber, rowCount, columnCount)) other)
    if((op == "+" || op == "-") && is(OtherNumber : Number)) {
        foreach(i; 0 .. rowCount) {
            foreach(j; 0 .. columnCount) {
                mixin(`array2D[i][j]` ~ op ~ `= other.array2D[i][j];`);
            }
        }
    }

    /// ditto
    @safe pure nothrow
    void opOpAssign(string op, OtherNumber)
    (const(Matrix!(OtherNumber, rowCount, columnCount)) other)
    if((op == "+" || op == "-") && is(OtherNumber : Number)) {
        opOpAssign(other);
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
    Matrix!(Number, rowCount, columnCount) opBinary(string op, OtherNumber)
    (ref const(Matrix!(OtherNumber, rowCount, columnCount)) other)
    if((op == "+" || op == "-") && is(OtherNumber : Number)) {
        // Copy this matrix.
        typeof(return) result = this;

        mixin(`result ` ~ op ~ `= other;`);

        return result;
    }

    /// ditto
    @safe pure nothrow
    Matrix!(Number, rowCount, columnCount) opBinary(string op, OtherNumber)
    (const(Matrix!(OtherNumber, rowCount, columnCount)) other)
    if((op == "+" || op == "-") && is(OtherNumber : Number)) {
        return opBinary(other);
    }

    /**
     * Multiply two matrices.
     *
     * Given a matrix of size (m, n) and a matrix of size (o, p).
     * This operation can only work if n == o.
     * The resulting matrix will be size (m, p).
     *
     * Params:
     *     other = Another matrix
     *
     * Returns: The product of two matrices.
     */
    @safe pure nothrow
    Matrix!(Number, rowCount, otherColumnCount) 
    opBinary(string op, OtherNumber, size_t otherRowCount, size_t otherColumnCount)
    (ref const(Matrix!(OtherNumber, otherRowCount, otherColumnCount)) other) const
    if((op == "*") && (columnCount == otherRowCount) && is(OtherNumber : Number)) {
        typeof(return) result;

        matrixMultiply(result, this, other);

        return result;
    }

    /// ditto
    @safe pure nothrow
    Matrix!(Number, rowCount, otherColumnCount) 
    opBinary(string op, OtherNumber, size_t otherRowCount, size_t otherColumnCount)
    (const(Matrix!(OtherNumber, otherRowCount, otherColumnCount)) other) const
    if((op == "*") && (columnCount == otherRowCount) && is(OtherNumber : Number)) in {
        return opBinary!(op, OtherNumber, otherRowCount, otherColumnCount)(other);
    }

    @safe pure nothrow
    Matrix!(OtherNumber, rowCount, otherColumnCount) 
    opBinary(string op, OtherNumber, size_t otherRowCount, size_t otherColumnCount)
    (ref const(Matrix!(OtherNumber, otherRowCount, otherColumnCount)) other) const
    if((op == "*") && (columnCount == otherRowCount) && !is(Number == OtherNumber) && is(Number : OtherNumber)) {
        typeof(return) result;

        matrixMultiply(result, this, other);

        return result;
    }

    @safe pure nothrow
    Matrix!(OtherNumber, rowCount, otherColumnCount) 
    opBinary(string op, OtherNumber, size_t otherRowCount, size_t otherColumnCount)
    (const(Matrix!(OtherNumber, otherRowCount, otherColumnCount)) other) const
    if((op == "*") && (columnCount == otherRowCount) && !is(Number == OtherNumber) && is(Number : OtherNumber)) {
        return opBinary!(op, OtherNumber, otherRowCount, otherColumnCount)(other);
    }
}

// 0 size matrices are special case.

/// ditto
struct Matrix(Number, size_t _rowCount, size_t _columnCount)
if(isNumeric!Number && _rowCount == 0 && _columnCount == 0) {
    /// The number of rows in this matrix.
    enum rowCount = _rowCount;
    /// The number of columns in this matrix.
    enum columnCount = _columnCount;
    /// True if this matrix is a zero-sized matrix.
    enum empty = true;
    /// true if this matrix is a square matrix.
    enum isSquare = true;
}

/**
 * Alias all (M, 0), (0, N) size static matrices into one single zero-sized
 * type of size (0, 0).
 */
template Matrix(Number, size_t rowCount, size_t columnCount)
if ((rowCount > 0 && columnCount == 0) || (rowCount == 0 && columnCount > 0)) {
    alias Matrix = Matrix!(Number, 0, 0);
}

// Test copy constructor for 2D arrays.
unittest {
    int[3][2] data = [
        [1, 2, 3],
        [4, 5, 6],
    ];

    Matrix!(int, 2, 3) matrix = data;

    assert(data == matrix);
}

// Test move constructor for 2D arrays.
unittest {
    auto matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);
}

// Test immutable too.
unittest {
    immutable(int[3][3]) data = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ];

    Matrix!(int, 3, 3) matrix = data;

    assert(data == matrix);
}

unittest {
    int[3][3] data = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ];

    immutable(Matrix!(int, 3, 3,)) matrix = data;

    assert(data == matrix);
}

// Test 1D array matrix slicing.
unittest {
    auto matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);

    assert(matrix.array1D == [1, 2, 3, 4, 5, 6, 7, 8, 9]);

    matrix.array1D[0] = 347;

    assert(matrix[0][0] == 347);
}

// Test that copy semantics work property for 1D arrays.
unittest {
    auto matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);

    auto arr = matrix.array1D;

    arr[0] = 347;

    // The value should not have changed.
    assert(matrix[0][0] == 1);
}

// Test that reference semantics work property for 1D arrays.
unittest {
    auto matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);

    void foo(ref int[9] arr) {
        arr[0] = 347;
    }

    foo(matrix.array1D);

    // The should have changed.
    assert(matrix[0][0] == 347);
}

// Test const and immutable 1D array, just in case.
unittest {
    const matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);

    assert(matrix.array1D == [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    assert(is(typeof(matrix.array1D) == const int[9]));
}

unittest {
    immutable matrix = Matrix!(int, 3, 3)([
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]);

    assert(matrix.array1D == [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    assert(is(typeof(matrix.array1D) == immutable int[9]));
}

// Test compile time init with numbers.
unittest {
    enum matrix = Matrix!(int, 3, 3)(
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    );

    assert(matrix.array2D[0][0] == 1);
    assert(matrix.array2D[0][1] == 2);
    assert(matrix.array2D[0][2] == 3);
    assert(matrix.array2D[1][0] == 4);
    assert(matrix.array2D[1][1] == 5);
    assert(matrix.array2D[1][2] == 6);
    assert(matrix.array2D[2][0] == 7);
    assert(matrix.array2D[2][1] == 8);
    assert(matrix.array2D[2][2] == 9);
}

// Test zero sized matrices
unittest {
    Matrix!(int, 0, 0) nothing;
    Matrix!(int, 1, 1) scalar;

    assert(nothing.empty);
    assert(!scalar.empty);

    Matrix!(int, 0, 1) noRows;
    Matrix!(int, 1, 0) noColumns;

    assert(is(typeof(nothing) == typeof(noRows)));
    assert(is(typeof(noRows) == typeof(noColumns)));
}

// Test index and assignment for cells.
unittest {
    Matrix!(int, 3, 3) matrix;

    assert(matrix[0, 0] == 0);

    matrix[0, 0] = 3;

    assert(matrix[0, 0] == 3);

    matrix[0, 0] *= 3;

    assert(matrix[0, 0] == 9);
}

/**
 * Transpose (flip) a matrix.
 *
 * Params:
 *     matrix = The matrix to produce a transpose for.
 *
 * Returns: A new matrix which is the transpose of the given matrix.
 */
@safe pure nothrow
Matrix!Number transpose(Number)(const Matrix!Number matrix)
out(val) {
    assert(matrix.columnCount == val.rowCount);
    assert(matrix.rowCount == val.columnCount);
} body {
    auto result = typeof(return)(matrix.columnCount, matrix.rowCount);

    foreach(row; 0 .. matrix.rowCount) {
        foreach(col; 0 .. matrix.columnCount) {
            result[col, row] = matrix[row, col];
        }
    }

    return result;
}

/// ditto
@safe pure nothrow
Matrix!(Number, columnCount, rowCount)
transpose(Number, size_t rowCount, size_t columnCount)
(ref const Matrix!(Number, rowCount, columnCount) matrix) {
    typeof(return) result;

    foreach(row; 0 .. matrix.rowCount) {
        foreach(col; 0 .. matrix.columnCount) {
            result[col, row] = matrix[row, col];
        }
    }

    return result;
}

/// ditto
@safe pure nothrow
Matrix!(Number, columnCount, rowCount)
transpose(Number, size_t rowCount, size_t columnCount)
(const Matrix!(Number, rowCount, columnCount) matrix) {
    return transpose(matrix);
}

unittest {
    auto matrix = Matrix!int(2, 3, [
        1, 2, 3,
        0, -6, 7
    ]);

    int[] expected = [1, 0, 2, -6, 3, 7];

    auto result = matrix.transpose;

    assert(result.rowCount == matrix.columnCount);
    assert(result.columnCount == matrix.rowCount);
    assert(result._data == expected);
}

unittest {
    // When transposed twice, we should get the same matrix.
    auto matrix = Matrix!int(2, 3, [
        1, 2, 3,
        0, -6, 7
    ]);

    assert(matrix == matrix.transpose.transpose);
}

unittest {
    auto matrix = Matrix!(int, 2, 3)(
        1, 2, 3,
        0, -6, 7
    );

    assert(matrix == matrix.transpose.transpose);
}

// Test foreach on static matrices.
unittest {
    auto matrix = Matrix!(int, 2, 3)(
        1, 2, 3,
        0, -6, 7
    );

    foreach(row, col, value; matrix) {
        if (row == 0) {
            if (col == 0) {
                assert(value == 1);
            } else if (col == 1) {
                assert(value == 2);
            } else {
                assert(value == 3);
            }
        } else {
            if (col == 0) {
                assert(value == 0);
            } else if (col == 1) {
                assert(value == -6);
            } else {
                assert(value == 7);
            }
        }
    }
}

// Test binary modifying operations on static matrices.
unittest {
    auto left = Matrix!(int, 2, 3)(
        1, 2, 3,
        4, 5, 6
    );

    auto right = Matrix!(int, 2, 3)(
        1, 2, 3,
        4, 5, 6
    );

    left -= right;

    foreach(row, col, value; left) {
        assert(value == 0);
    }

    left -= right;
    left += right;

    foreach(row, col, value; left) {
        assert(value == 0);
    }
}

// Test binary copying operations on static matrices.
unittest {
    auto left = Matrix!(int, 2, 3)(
        1, 2, 3,
        4, 5, 6
    );

    auto right = Matrix!(int, 2, 3)(
        1, 2, 3,
        4, 5, 6
    );

    auto newMatrix = left - right;

    foreach(row, col, value; newMatrix) {
        assert(value == 0);
    }

    auto finalMatrix = newMatrix + left;

    finalMatrix -= left;

    foreach(row, col, value; finalMatrix) {
        assert(value == 0);
    }
}

// Test matrix multiplication on static matrices
unittest {
    auto left = Matrix!(int, 2, 3)(
        2, 3, 4,
        1, 0, 0
    );

    auto right = Matrix!(int, 3, 2)(
        0, 1000,
        1, 100,
        0, 10
    );

    auto result = left * right;

    int[][] expected = [
        [3, 2340],
        [0, 1000]
    ];

    foreach(i; 0..2) {
        foreach(j; 0..2) {
            assert(result[i, j] == expected[i][j]);
        }
    }
}

// Test matrix multiplication, with a numeric type on the 
// left which implicitly converts to the right.
unittest {
    Matrix!(int, 1, 1) left;
    Matrix!(long, 1, 1) right;

    Matrix!(long, 1, 1) result = left * right;
}