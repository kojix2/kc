#pragma once

#include <cstdint>

extern "C"
{
    // Write sparse tensor in Arrow format
    // coords: flattened coordinates array [row0, col0, row1, col1, ...]
    // values: values array corresponding to coordinates
    // nnz: number of non-zero elements
    // num_rows: number of rows in the matrix
    // num_cols: number of columns in the matrix
    // filename: output file path
    // Returns 0 on success, non-zero on error
    int write_arrow_sparse_coo(
        const char *filename,
        const int64_t *coords,
        const double *values,
        int64_t nnz,
        int64_t num_rows,
        int64_t num_cols);
}
