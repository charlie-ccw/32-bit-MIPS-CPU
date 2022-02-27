#!/bin/bash
set -eou pipefail

# - "DIR"    - Source directory e.g. "rtl"
DIR="$1"
TESTTYPE="$2"
TESTCASE="$3"
TESTINSTR="$4"

# Discard previous outputs
rm -rf test/4-output/${TESTTYPE}/${TESTCASE}*

# Redirect output to stder (&2) so that it seperate from genuine outputs
# Using ${VARIANT} substitures in the value of the variable VARIA T
# >&2 echo "Test CPU using test-type ${TEST_TYPE} test-case ${TESTCASE}"

# >&2 echo " 2 - Compiling test-bench"
iverilog -Wall -g 2012 \
   -s bus_cpu_tb \
   -P bus_cpu_tb.RAM_INIT_FILE=\"test/1-binary/${TESTTYPE}/${TESTCASE}.txt\" \
   -o test/2-simulator/${TESTTYPE}/mips_cpu_tb_${TESTCASE} \
   test/bus_cpu_tb.v test/ram_mapped.v ${DIR}/mips_cpu_*.v  

# >&2 echo " 3 - Running test-bench"
set +e
test/2-simulator/${TESTTYPE}/mips_cpu_tb_${TESTCASE} > test/3-output/${TESTTYPE}/${TESTCASE}.stdout
# Capture the exit code of the simulator in a variable
RESULT=$?
set -e

# Check whether the simulator returned a failure code, and immediately quit
if [[ "${RESULT}" -ne 0 ]] ; then
   echo "  ${TESTTYPE}  ${TESTCASE}, FAIL"
   exit
fi

# >&2 echo "    Extracting result of OUT instructions"
PATTERN="register_v0_final "
NOTHING=""
# Use "grep" to look only for lines containing PATTERN
set +e
grep "${PATTERN}" test/3-output/${TESTTYPE}/${TESTCASE}.stdout > test/3-output/${TESTTYPE}/${TESTCASE}.out-lines
set -e
# Use "sed" to replace "register_v0_final :" with nothing
sed -e "s/${PATTERN}/${NOTHING}/g" test/3-output/${TESTTYPE}/${TESTCASE}.out-lines > test/3-output/${TESTTYPE}/${TESTCASE}.out


# >&2 echo "  b - Comparing output"
set +e
diff -w test/4-reference/${TESTTYPE}/${TESTCASE}.out test/3-output/${TESTTYPE}/${TESTCASE}.out
RESULT=$?
set -e

# Based on whether differences were found, either pass or fail
if [[ "${RESULT}" -ne 0 ]] ; then
   echo "  ${TESTTYPE}_${TESTCASE}  ${TESTINSTR}  Fail"
else
   echo "  ${TESTTYPE}_${TESTCASE}  ${TESTINSTR}  Pass"
fi

# ${TESTTYPE}_${TESTCASE} is considered to be TESTID