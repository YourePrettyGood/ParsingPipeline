#!/bin/awk -f
#Assumes PE data
#Prepare the output redirection commands for index reads based on
# input variable "prefix":
BEGIN{
   I1output="gzip -9 > "prefix"_I1.fastq.gz";
   I2output="gzip -9 > "prefix"_I2.fastq.gz";
}
#Get the read pair ID, and also extract the index reads from the barcode
# field:
NR%4==1{
   split($2, readnum, ":");
   n_indexreads=split(readnum[4], barcodes, "+");
#Print the header and read sequence for I1:
   print $1" 3:"readnum[2]":"readnum[3]":"readnum[4] | I1output;
   print barcodes[1] | I1output;
   bc1len=length(barcodes[1]);
#If there's a second index read, print the header and read sequence
# for I2:
   if (n_indexreads > 1) {
      print $1" 4:"readnum[2]":"readnum[3]":"readnum[4] | I2output;
      print barcodes[2] | I2output;
      bc2len=length(barcodes[2]);
   }
}
#We choose to just steal the quality scores from the beginning of
# the input FASTQ's quality score line:
NR%4==0{
   print "+" | I1output;
   print substr($0, 1, bc1len) | I1output;
   if (n_indexreads > 1) {
      print "+" | I2output;
      print substr($0, 1, bc2len) | I2output;
   }
}
