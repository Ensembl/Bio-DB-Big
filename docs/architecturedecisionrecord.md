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

