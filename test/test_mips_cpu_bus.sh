#!/bin/bash
set -eou pipefail

# - "DIR"  - Source directory e.g. "rtl"
DIR="$1"
INSTRUCTION="${2:-all}"

for TESTFOLDER in test/1-binary/*; do

    TESTTYPE="$(basename -- $TESTFOLDER)"

    for i in ${TESTFOLDER}/*.txt; do 
        TESTCASE="$(basename -- $i)"
        TESTCASE=${TESTCASE//".txt"/} # Remove ".txt"
        TESTINSTR=${TESTCASE//"_tb"*/}
        if [[ ${INSTRUCTION} != "all" ]]; then
            if [[ ${INSTRUCTION} == ${TESTINSTR} ]]; then
                ./test/run_one_testcase.sh ${DIR} ${TESTTYPE} ${TESTCASE} ${TESTINSTR}
            fi
        else
            ./test/run_one_testcase.sh ${DIR} ${TESTTYPE} ${TESTCASE} ${TESTINSTR}
        fi
        
    done

done