#!/bin/sh
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#Make sure --cpus-per-task=8 matches NUM_THREADS below:
#SBATCH --cpus-per-task=8
#64 GB RAM is usually plenty for 8 threads of parsing for HiSeq 2500, 4000,
# or X lanes:
#SBATCH --mem=64000
#SBATCH -J i5PARSE
#24 hours is usually plenty for 
#SBATCH -t 24:00:00
#For some clusters, you may need --qos:
#SBATCH --qos=1day
#Be sure to change the e-mail address here:
#SBATCH --mail-user=CHANGETHIS@princeton.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end

PARSEDIR="[path to your sequencing run directory]/raw_data/i5_parse/"
pushd "${PARSEDIR}"
#divideConquerParser.sh [# input FASTQ files] [quoted space-separated list of FASTQ files] \
#[# parts to split into] [barcodes TSV file] [# to pass to --idxread] [# of mismatches to allow]
#Note: # of mismatches to allow will default to 0 if not provided.

#Specify the path to the ParsingPipeline:
PIPELINEDIR="/Genomics/grid/users/preilly/bin/ParsingPipeline"

NUM_THREADS=8 #ALWAYS MATCH THIS TO THE VALUE OF --cpus-per-task

NUM_READFILES=3 #ADJUST THIS TO MATCH HOW MANY OF THE R# VARIABLES ARE SET

READFILE_PREFIX="[Prefix typically given by bcl2fastq2 without barcode parsing]"

#Note: You may comment out any of these variables that you don't need,
# although you do need at least two: a read file, and an index read file
#Also, the file names may be different if bcl2fastq2 wasn't used to provide
# the whole-lane FASTQs to you.  For instance, Princeton HTSEQ has a different
# FASTQ nomenclature ending in things like _read_1_passed_filter.fastq.gz,
# _read_2_index_read_passed_filter.fastq.gz, etc.
#So you may have to adjust these suffixes appropriately.
R1="${READFILE_PREFIX}_R1_001.fastq.gz"
R2="${READFILE_PREFIX}_I1_001.fastq.gz"
R3="${READFILE_PREFIX}_I2_001.fastq.gz" #USE THIS ONLY IF YOU HAVE DUAL-INDEXED LIBRARIES
#R4="${READFILE_PREFIX}_R2.fastq.gz" #USE THIS ONLY IF YOU HAVE PAIRED-END LIBRARIES

I5INDICES="i5_indices.tsv" #Your customized version of i5_indices_template.tsv

PARSEREAD=3 #USE 2 IF YOU ARE PARSING i7, USE 3 IF YOU ARE PARSING i5
#Note that 2 and 3 only correspond to i7 and i5 if you place the i7 and i5
# read files as being the R2 and R3 variables.

NUM_MISMATCHES=1 #MAY SET TO 1, CHECK YOUR INDEX READ HISTOGRAM TO BE SURE 2 IS SAFE

srun ${PIPELINEDIR}/divideConquerParser.sh ${NUM_READFILES} "${R1} ${R2} ${R3} ${R4}" ${NUM_THREADS} ${I5INDICES} ${PARSEREAD} ${NUM_MISMATCHES}
popd
