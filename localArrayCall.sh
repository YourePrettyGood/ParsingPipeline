#!/bin/bash

#This script uses a metadata file and the task ID to
#run a pipeline job

#The arguments are:
#1) task number
#2) job type (i.e. TRIM)
#3) metadata file (TSV comprised of error rate, stringency, read file(s))
#Maybe later add support for QV style and min trimmed read length in metadata?
#Optional argument 4) minimum trimmed read length for all samples (default 1)
#Optional argument 5) minimum quality score for quality trimming (default 0)

#Note: SLURM submission parameters are specified in the sbatch
# call to this script (e.g. --mem, -N 1, --ntasks-per-node=1,
# --cpus-per-task, -t, --qos, -J)

TASKID=$1
JOBTYPE=$2
METADATA=$3

#Set the paths to the important executables:
SCRIPTDIR=`dirname $0`
source ${SCRIPTDIR}/pipeline_environment.sh

#If we later want to make concomitant quality trimming available, change this:
MINQV=0
if [[ "$5" -gt "0" ]]; then
   MINQV=$5
fi
#Same for minimum trimmed read length:
MINLENGTH=1
if [[ "$4" -gt "0" ]]; then
   MINLENGTH=$4
fi
#Same for quality score scale (33 or 64):
QVTYPE=33

WHICHSAMPLE=1
while read -r -a metadatafields
   do
   if [[ $WHICHSAMPLE -eq $TASKID ]]; then
      ERRORRATE="${metadatafields[0]}"
      STRINGENCY="${metadatafields[1]}"
      if [[ ! -z "${metadatafields[3]}" ]]; then
         READS="${metadatafields[2]} ${metadatafields[3]}"
         PAIRED=" --paired --retain_unpaired"
      else
         READS="${metadatafields[2]}"
         PAIRED=""
      fi
   fi
   (( WHICHSAMPLE++ ))
done < $METADATA
if [[ -z "$ERRORRATE" ]]; then
   echo "Unable to find sample $TASKID in metadata file. Skipping."
   exit 4
fi

if [[ $JOBTYPE =~ "TRIM" ]]; then
   #
   CMD="${TRIMGALORE} --path_to_cutadapt ${CUTADAPT} --phred${QVTYPE} --quality ${MINQV} -e ${ERRORRATE} --stringency ${STRINGENCY} --length ${MINLENGTH}${PAIRED} ${READS}"
else
   echo "Unintelligible job type $JOBTYPE"
   exit 3
fi

$CMD
