# ParsingPipeline

Parsing and adapter trimming scripts for Illumina data for use when i5 and/or i7 index reads are provided as separate synchronized FASTQs
## Scripts that are not mine:
1. `barcode_splitter.py`

This script is needed by `divideConquerParser.sh`, as it is the main parsing workhorse.  divideConquerParser.sh just preprocesses the files to split into `n` parts, run in parallel on `n` cores, and merge the results back together.
All credit for this script goes to Lance Parsons, as it comes from [his bitbucket](https://bitbucket.org/lance_parsons/paired_sequence_utils/src/355e838b92d0/barcode_splitter.py)

## Parsing scripts:

### `divideConquerParser.sh`

This is a bash wrapper script to divide the reads into roughly equal chunks, parse each chunk in parallel, and then merge the results. The current implementation takes up quite a bit of space during the splitting step, since it has to decompress the reads to split them, and then compress the splits. I'll be testing the --filter flag to GNU coreutils split to mitigate the issue in the future.

`i5_parse_template.sbatch` is an example SBATCH script for using `divideConquerParser.sh` to parse Illumina data with filenames in bcl2fastq2 style. It should give you an idea of how to call `divideConquerParser.sh`.

Example usage:

Use 8 cores for a single-indexed paired-end (so R1, R2, and I1 FASTQ files) dataset:

`divideConquerParser.sh 3 "MyLane_R1.fastq.gz MyLane_R2.fastq.gz MyLane_I1.fastq.gz" 8 MyLane_i7_indices.tsv 3`

Use 8 cores for single-indexed paired-end dataset, but changing the listing order of the files so the index read file is first:

`divideConquerParser.sh 3 "MyLane_I1.fastq.gz MyLane_R1.fastq.gz MyLane_R2.fastq.gz" 8 MyLane_i7_indices.tsv 1`

Use 8 cores for single-indexed single-end dataset, where index read file is last:

`divideConquerParser.sh 2 "MyLane_R1.fastq.gz MyLane_I1.fastq.gz" 8 MyLane_i7_indices.tsv 2`

Use 8 cores to perform the i5 parse of a dual-indexed paired-end dataset (where i5 is the *_I1.fastq.gz file, and i7 is the *_I2.fastq.gz file):

`divideConquerParser.sh 4 "MyLane_R1.fastq.gz MyLane_R2.fastq.gz MyLane_I1.fastq.gz MyLane_I2.fastq.gz" 8 MyLane_i5_indices.tsv 3`

**Note that the 5th (last) argument is the 1-based position of the index read file you want to parse on.  This number must be less than or equal to the total number of read files you would like to parse.

### `ReadHistogram.sh` and `labelIndexReadHistogram.pl`

These scripts are used for parsing diagnostics. `ReadHistogram.sh` simply takes in a read file (and optionally arguments to GNU coreutils `sort`, such as setting the temp directory used), and outputs a "histogram" of the read sequences contained, in descending order of frequency.

This "histogram" can then be used with a barcode file (like that used by `divideConquerParser.sh` and `barcode_splitter.py`) to label the rows of this "histogram" with the library ID, and how many mismatches it has relative to the barcode sequence provided (up to 2 mismatches).

Oftentimes this is the fastest way to pre-diagnose problems with your barcode file *before spending a lot of time parsing*. It also helps with some pooling or lane quality diagnostics.

### `ReadHistogram.sh`

This quick bash script just simply wraps a one-liner that creates a histogram TSV of the index reads, sorted in descending order by count.  This histogram file is useful as a QC check before parsing, as it usually takes substantially less time to run than parsing.

It's essentially just two columns:

1. Index sequence
2. Count of index reads matching the sequence in column 1

Example usage:

`ReadHistogram.sh MySequencingLane_I1.fastq.gz > MySequencingLane_i7_index_histogram.tsv`

### `labelIndexReadHistogram.pl`

This script is intended to be used in tandem with `ReadHistogram.sh` (and may be piped to), in order to do a quick sanity check on your barcode file.  If the output from this script does not show most or all of your main barcodes with 0 mismatches at the top of the file, you either misspecified your barcodes file (maybe forgot to revcomp the index sequences?) or something went seriously wrong with the sequencing run.  This also gives a first-pass idea of how much error there was in the index read, and how many reads you should expect after parsing.

The output is a modified version of what comes from `ReadHistogram.sh` in that a variable number of columns is added, one per matching barcode from your barcodes file (with up to 2 mismatches).

Example usage:

`ReadHistogram.sh MySequencingLane_I1.fastq.gz | labelIndexReadHistogram.pl -b MySequencingLane_i7_indices.tsv > MySequencingLane_labeled_i7_histogram.tsv`

You may want to save the read histogram to a file, and feed it to `labelIndexReadHistogram.pl` with the `-i` option, in case you need to diagnose barcode file problems without waiting a long time for each run of `ReadHistogram.sh`.

**Note that your barcode file must be a proper TSV (i.e. columns separated by single `\t` characters, NOT spaces.  Many text editors have the annoying behaviour of inputting a certain number of spaces instead of a true tab character.  Using spaces will make the barcode parser output gibberish/fail, and will not produce any labels from this script.**

An easy way to check for tabs in your barcode file is to run `hexdump -C < MySequencingLane_i7_indices.tsv` and examine the output for `09` characters.  The ASCII code for the tab character is 09 in hexadecimal (see [ASCII Table](http://asciitable.com/)

## localArrayCall.sh

This is a bash wrapper script for adapter trimming with [Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) used in conjunction with task arrays of your cluster job engine of choice (for Princeton, we have SLURM).

It is dependent on `pipeline_environment.sh`, which simply specifies the absolute paths to the dependencies ([Trim Galore](https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/) and [cutadapt](https://cutadapt.readthedocs.io/en/stable/)).

The call style is very similar to that used for my [Pseudoreference Pipeline](https://github.com/YourePrettyGood/PseudoreferencePipeline/). It essentially involves passing a task ID (e.g. with SLURM's `$SLURM_ARRAY_TASK_ID` environment variable), a job type, a metadata file, and any extra options.

The extra options are:

1. Minimum read length required before a read (or read pair) is omitted (default: 1 bp, but you should set this to higher, e.g. at least k if you're using kmers downstream)
1. Minimum quality score when quality trimming (default: 0, which means quality trimming is skipped)

The minimum quality score option should be used for RNAseq data as per [McManes (2014)](https://dx.doi.org/10.3389/fgene.2014.00013), and set to at least 5.

The metadata file is a tab-separated file with one line per sample to be trimmed. For the `TRIM` jobtype, the columns are:

1. Error rate for matching adapter bases
1. Stringency (minimum number of matching bases required to trim)
1. Read 1 path
1. Read 2 path (ignore if trimming single-ended data)

Trim Galore is very nice in that it automatically detects the Illumina adapter type used, and maintains paired read synchronization seamlessly, which is why I use it here instead of Trimmomatic or writing my own cutadapt wrapper.
