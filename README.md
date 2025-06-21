# kc

kc counts k-mers for each read in a FASTQ file.  
Output is a tab-separated table: one line per read, one column per k-mer.

## Build

```
shards build -Dpreview_mt -Dexecution_context
```

## Usage

```
bin/kc -i input.fastq
```

## Output

- First row: header with all k-mers
- Following rows: read ID and k-mer counts (tab-separated)

## options

```
Usage: kc [options] -i FILE
    -i, --input FILE                 Input FASTQ file (.gz supported)
    -o, --output FILE                Output TSV file (default: stdout)
    -k, --kmer-size N                k-mer size (default: 3)
    -t, --threads N                  Number of worker threads (default: 4)
    -c, --chunk-size N               Reads per processing chunk (default: 1000)
    -v, --verbose                    Enable verbose output
    -h, --help                       Show this help message
```

## License

MIT
