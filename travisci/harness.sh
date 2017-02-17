#!/bin/bash
# export PERL5LIB=$PERL5LIB:$PWD/ensembl-test/modules:$PWD/lib:$PWD/blib/arch/auto/Bio/DB/HTS/:$PWD/blib/arch/auto/Bio/DB/HTS/Faidx

export TEST_AUTHOR=$USER

export WORK_DIR=$PWD

echo "Running test suite"
echo "Using PERL5LIB: $PERL5LIB"

prove t $SKIP_TESTS

