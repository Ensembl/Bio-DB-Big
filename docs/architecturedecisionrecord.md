# Architecture Decision Record

## 1. Use Architecture Decision Records
Date: 2017-03-29

### Status
Approved

### Context
We need to record architecture decisions made on this project. This was suggested after looking at [Thoughtwork's technology radar](https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records).

### Decision
We have adopted part of the system and have created a file to record decisions. We are not using the official ADR toolkit because we want to first make sure this technique will work.

### Consequences
All future decisions made about architecture will be recorded here.

## 2. Use Thread Safe Globals with CURL
Date: 2017-03-29

### Status
Approved

### Context
libBigWig allows programmers to use a callback C subroutine to pass parameters into CURL e.g. proxies, timeouts, following redirects, trusting remote SSL certificates. Some of these are useful for us to override from the Perl layer.

### Decision
The callback cannot take in any data payload as it is currently implemented. The only sensible way to get the variables into CURL is to use globals in the non-XS layer and have the XS layer set these values and use them with every connection we make. Any attempt to use Perl subroutines to set these values resulted in major issues with program stability and lots of exceptions occurring. Using globals seems to work. We also made this thread-safe with the use of `MY_CXT_KEY` as directed by Perl's documentation on safely storing global variables.

### Consequences
Any new CURL params that need to be modified will have to have a global variable defined and added to `Big.xs` with `bigfileCallBack` modified accordingly.

## 3. Make AutoSQL More Aware of Possible Field Misnaming
Date: 2017-03-29

### Status
Approved

### Context

Misnames can occur in two ways. First is that columns have been called different things over time e.g. item_colour is a synonym in some files for itemRgb. 

Second is AutoSQL generation. BigBeds must be accompanied with an AutoSQL record. This can be given to `bedToBigBed` or if not given the fields can be automatically generated. For example after we run the following commands:

```
$ curl -s http://rest.ensembl.org/overlap/region/human/1:1000000-1200000.bed?feature=transcript > out.bed
$ wget https://genome.ucsc.edu/goldenpath/help/hg19.chrom.sizes
$ bedToBigBed -type=bed4+16 out.bed hg19 out.bb
```

This will generate AutoSQL like so (other info omitted):

```
$ bigBedInfo -as out.bb
table bed
"Browser Extensible Data"
   (
   string chrom;       "Reference sequence chromosome or scaffold"
   uint   chromStart;  "Start position in chromosome"
   uint   chromEnd;    "End position in chromosome"
   string name;        "Name of item."
lstring field6;	"Undocumented field"
lstring field7;	"Undocumented field"
lstring field8;	"Undocumented field"
lstring field9;	"Undocumented field"
lstring field10;	"Undocumented field"
lstring field11;	"Undocumented field"
lstring field12;	"Undocumented field"
lstring field13;	"Undocumented field"
lstring field14;	"Undocumented field"
lstring field15;	"Undocumented field"
lstring field16;	"Undocumented field"
lstring field17;	"Undocumented field"
lstring field18;	"Undocumented field"
lstring field19;	"Undocumented field"
lstring field20;	"Undocumented field"
lstring field21;	"Undocumented field"
   )
```

The BigBed file is correct and does represent a set of transcripts but does not use standard names.

### Decision
Determining what a BigBed file is meant to be is beyond the scope of this module. What a file is meant to be depends not only on column count but on asking a downstream program what it expected. However we can make the situation easier to handle. AutoSQL has been changed to support alternative name specification to solve the first source of bad column names. 

### Consequences
Future modifications to make guesses about columns will not be accepted in.
