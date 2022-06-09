# ParsingPipeline

Parsing and adapter trimming scripts for Illumina data for use when i5 and/or i7 index reads are provided as separate synchronized FASTQs
## Scripts that are not mine:
1. `barcode_splitter.py`

This script is needed by `divideConquerParser.sh`, as it is the main parsing workhorse.  divideConquerParser.sh just preprocesses the files to split into `n` parts, run in parallel on `n` cores, and merge the results back together.
All credit for this script goes to Lance Parsons, as it comes from [his bitbucket](https://bitbucket.org/lance_parsons/paired_sequence_utils/src/355e838b92d0/barcode_splitter.py)

## Parsing scripts:

### `extractIndexReads.awk`

This awk script generates gzipped index read FASTQ files based on the index sequences found in the standard Illumina 1.8+ header.  This enables parsing using `divideConquerParser.sh` when a sequencing center only provides you with unparsed R1 and R2 FASTQ files (e.g. Novogene has done this before, other providers may as well).

Be sure to pass `-v "prefix=[output FASTQ prefix]"` when calling the script, and either pipe the uncompressed contents of the R1 FASTQ file in, or use process substitution to pass it in as an argument.

Example usage:

```bash
#Extracts index reads from R1 reads from lane Pgc20_L2
#Outputs to Pgc20_L2_I1.fastq.gz and Pgc20_L2_I2.fastq.gz
gzip -dc Pgc20_L2_R1.fastq.gz | /usr/bin/time -v [path to ParsingPipeline]/extractIndexReads.awk -v "prefix=Pgc20_L2" 2> eIR_fromR1_Pgc20_L2.stderr > eIR_fromR1_Pgc20_L2.stdout
#Typically you'd want to generate read histograms for the resultant
# I1 and I2 read files like so:
gzip -dc Pgc20_L2_I1.fastq.gz | [path to ParsingPipeline]/ReadHistogram.sh | [path to ParsingPipeline]/labelIndexReadHistogram.pl -b Pgc20_L2_i7_barcodes.tsv > Pgc20_L2_I1_Histogram.tsv
gzip -dc Pgc20_L2_I2.fastq.gz | [path to ParsingPipeline]/ReadHistogram.sh | [path to ParsingPipeline]/labelIndexReadHistogram.pl -b Pgc20_L2_i5_barcodes.tsv > Pgc20_L2_I2_Histogram.tsv
#Usage for later i5 parsing with divideConquerParser.sh might look like:
[path to ParsingPipeline]/divideConquerParser.sh 4 "Pgc20_L2_R1.fastq.gz Pgc20_L2_R2.fastq.gz Pgc20_L2_I1.fastq.gz Pgc20_L2_I2.fastq.gz" 8 Pgc20_L2_i5_barcodes.tsv 4
```

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

The output is essentially just two columns:

1. Index sequence
2. Count of index reads matching the sequence in column 1

Usage:

`ReadHistogram.sh <input FASTQ> [sort options]`

Note that `[sort options]` is an optional argument, but must be a quoted string in order to work properly.  Treat it like a quoted version of what you would normally pass to `sort`.

Example usage:

`ReadHistogram.sh MySequencingLane_I1.fastq.gz > MySequencingLane_i7_index_histogram.tsv`

One error message that sometimes comes up is:

`sort: write failed: /tmp/[some weird string]: No space left on device`

If you see this message, or you think you have a TON of reads to sort through, you should pass a second argument to `ReadHistogram.sh` that specifies the arguments to `sort` you want to add.  For instance, you could add `"-T [path to a temp directory with a lot of space]"` (make absolutely sure to keep the double quotes!), which would tell `sort` to place its temporary files in the directory you provided, rather than `/tmp`.

The `/tmp` directory is a special directory in Linux that has its own filesystem and usually doesn't have a ton of space compared to other drives/mounts. Unix `sort` performs a type of "external" sort that sorts subsets of the input data, then stores them temporarily to disk, and finally performs a sorting merge of all the subsets at the end (similar to the merge step of a merge sort), so for extremely large inputs it will often require more disk space than is available in `/tmp`.  Check `man sort` to ensure that your version of `sort` supports the `-T` option.

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

Note: In general, leave the minimum quality score for trimming at it's default (i.e. 0), as quality trimming is detrimental for most purposes.  Modern mappers and reads are much more tolerant of poor-quality regions, so retaining the information in these regions can actually be helpful.

The only use-case where it may still be beneficial is for RNAseq data for *de novo* transcriptome assembly.

The minimum quality score option should only really be used for RNAseq data meant for *de novo* transcriptome assembly as per [McManes (2014)](https://dx.doi.org/10.3389/fgene.2014.00013), and set to at least 5.

The metadata file is a tab-separated file with one line per sample to be trimmed. For the `TRIM` jobtype, the columns are:

1. Error rate for matching adapter bases
1. Stringency (minimum number of matching bases required to trim)
1. Read 1 path
1. Read 2 path (ignore if trimming single-ended data)

Trim Galore is very nice in that it automatically detects the Illumina adapter type used, and maintains paired read synchronization seamlessly, which is why I use it here instead of Trimmomatic or writing my own cutadapt wrapper.
