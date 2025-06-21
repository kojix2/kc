#pragma once

#include <cstdint>

extern "C"
{
    // Write sparse tensor with read names included
    // coords: flattened coordinates array [row0, col0, row1, col1, ...]
    // values: k-mer count values (uint32_t)
    // read_names: array of null-terminated strings for row names
    // read_name_lengths: array of string lengths (excluding null terminator)
    // nnz: number of non-zero elements
    // num_rows: number of rows in the matrix
    // num_cols: number of columns in the matrix
    // filename: output file path
    // Returns 0 on success, non-zero on error
    int write_arrow_sparse(
        const char *filename,
        const int64_t *coords,
        const uint32_t *values,
        const char **read_names,
        const int64_t *read_name_lengths,
        int64_t nnz,
        int64_t num_rows,
        int64_t num_cols);
}
