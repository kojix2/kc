#include "arrow_sparse.hpp"
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <arrow/ipc/api.h>
#include <vector>
#include <memory>

// Arrow sparse tensor writer using official Arrow C++ library
// Writes data in Arrow IPC format for maximum compatibility

extern "C"
{
    int write_arrow_sparse(
        const char *filename,
        const int64_t *coords,
        const uint32_t *values,
        const char **read_names,
        const int64_t *read_name_lengths,
        int64_t nnz,
        int64_t num_rows,
        int64_t num_cols)
    {
        try
        {
            // Create Arrow arrays for the sparse data

            // 1. Read names (string array)
            arrow::StringBuilder read_name_builder;
            for (int64_t i = 0; i < num_rows; i++)
            {
                auto status = read_name_builder.Append(read_names[i], read_name_lengths[i]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> read_name_array;
            auto status = read_name_builder.Finish(&read_name_array);
            if (!status.ok())
                return -1;

            // 2. Row indices (int64 array)
            arrow::Int64Builder row_builder;
            for (int64_t i = 0; i < nnz; i++)
            {
                auto status = row_builder.Append(coords[i * 2]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> row_array;
            status = row_builder.Finish(&row_array);
            if (!status.ok())
                return -1;

            // 3. Column indices (int64 array)
            arrow::Int64Builder col_builder;
            for (int64_t i = 0; i < nnz; i++)
            {
                auto status = col_builder.Append(coords[i * 2 + 1]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> col_array;
            status = col_builder.Finish(&col_array);
            if (!status.ok())
                return -1;

            // 4. Values (uint32 array)
            arrow::UInt32Builder value_builder;
            for (int64_t i = 0; i < nnz; i++)
            {
                auto status = value_builder.Append(values[i]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> value_array;
            status = value_builder.Finish(&value_array);
            if (!status.ok())
                return -1;

            // 5. Row indices for read names mapping
            arrow::Int64Builder read_row_builder;
            for (int64_t i = 0; i < nnz; i++)
            {
                auto status = read_row_builder.Append(coords[i * 2]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> read_row_array;
            status = read_row_builder.Finish(&read_row_array);
            if (!status.ok())
                return -1;

            // Create schema
            auto schema = arrow::schema({arrow::field("read_id", arrow::utf8()),
                                         arrow::field("row", arrow::int64()),
                                         arrow::field("col", arrow::int64()),
                                         arrow::field("value", arrow::uint32())});

            // Map row indices to read names for the sparse data
            arrow::StringBuilder sparse_read_builder;
            for (int64_t i = 0; i < nnz; i++)
            {
                int64_t row_idx = coords[i * 2];
                auto status = sparse_read_builder.Append(read_names[row_idx], read_name_lengths[row_idx]);
                if (!status.ok())
                    return -1;
            }
            std::shared_ptr<arrow::Array> sparse_read_array;
            status = sparse_read_builder.Finish(&sparse_read_array);
            if (!status.ok())
                return -1;

            // Create table
            auto table = arrow::Table::Make(schema, {sparse_read_array,
                                                     row_array,
                                                     col_array,
                                                     value_array});

            // Write to file
            auto output_result = arrow::io::FileOutputStream::Open(filename);
            if (!output_result.ok())
                return -1;
            auto output = output_result.ValueOrDie();

            auto writer_result = arrow::ipc::MakeFileWriter(output, schema);
            if (!writer_result.ok())
                return -1;
            auto writer = writer_result.ValueOrDie();

            status = writer->WriteTable(*table);
            if (!status.ok())
                return -1;

            status = writer->Close();
            if (!status.ok())
                return -1;

            status = output->Close();
            if (!status.ok())
                return -1;

            return 0;
        }
        catch (...)
        {
            return -1;
        }
    }
}
