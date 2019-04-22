# ParsingPipeline

Parsing and adapter trimming scripts for Illumina data for use when i5 and/or i7 index reads are provided as separate synchronized FASTQs
## Scripts that are not mine:
1. `barcode_splitter.py`

This script is needed by `divideConquerParser.sh`, as it is the main parsing workhorse.  divideConquerParser.sh just preprocesses the files to split into `n` parts, run in parallel on `n` cores, and merge the results back together.
All credit for this script goes to Lance Parsons, as it comes from [his bitbucket](https://bitbucket.org/lance_parsons/paired_sequence_utils/src/355e838b92d0/barcode_splitter.py)

## divideConquerParser.sh

This is a bash wrapper script to divide the reads into roughly equal chunks, parse each chunk in parallel, and then merge the results. The current implementation takes up quite a bit of space during the splitting step, since it has to decompress the reads to split them, and then compress the splits. I'll be testing the --filter flag to GNU coreutils split to mitigate the issue in the future.

`i5_parse_template.sbatch` is an example SBATCH script for using `divideConquerParser.sh` to parse Illumina data with filenames in bcl2fastq2 style. It should give you an idea of how to call `divideConquerParser.sh`.

## `ReadHistogram.sh` and `labelIndexReadHistogram.pl`

These scripts are used for parsing diagnostics. `ReadHistogram.sh` simply takes in a read file (and optionally arguments to GNU coreutils `sort`, such as setting the temp directory used), and outputs a "histogram" of the read sequences contained, in descending order of frequency.

This "histogram" can then be used with a barcode file (like that used by `divideConquerParser.sh` and `barcode_splitter.py`) to label the rows of this "histogram" with the library ID, and how many mismatches it has relative to the barcode sequence provided (up to 2 mismatches).

Oftentimes this is the fastest way to pre-diagnose problems with your barcode file *before spending a lot of time parsing*. It also helps with some pooling or lane quality diagnostics.

## localArrayCall.sh

This is a bash wrapper script for adapter trimming with [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) used in conjunction with task arrays of your cluster job engine of choice (for Princeton, we have SLURM).

It is dependent on `pipeline_environment.sh`, which simply specifies the absolute paths to the dependencies ([Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) and [cutadapt](https://cutadapt.readthedocs.io/en/stable/)).

The call style is very similar to that used for my [Pseudoreference Pipeline](https://github.com/YourePrettyGood/PseudoreferencePipeline/). It essentially involves passing a task ID (e.g. with SLURM's `$SLURM_ARRAY_TASK_ID` environment variable), a job type, a metadata file, and any extra options.

The metadata file is a tab-separated file with one line per sample to be trimmed. For the `TRIM` jobtype, the columns are:

1. Error rate for matching adapter bases
1. Stringency (minimum number of matching bases required to trim)
1. Read 1 path
1. Read 2 path (ignore if trimming single-ended data)

Trim Galore is very nice in that it automatically detects the Illumina adapter type used, and maintains paired read synchronization seamlessly, which is why I use it here instead of Trimmomatic or writing my own cutadapt wrapper.
