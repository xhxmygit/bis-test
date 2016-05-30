#!/bin/bash
#
# Template for creating ICA test case scripts to
# run on Linux distributions.
#

ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during setup of test
ICA_TESTFAILED="TestFailed"        # Error during execution of test

CONSTANTS_FILE="constants.sh"


UpdateTestState()
{
    echo $1 > ~/state.txt
}


#
# Create the state.txt file so ICA knows we are running
#
echo "Updating test case state to running"
UpdateTestState $ICA_TESTRUNNING

#
# Source the constants.sh file to pickup definitions from
# the ICA automation
#
if [ -e ./${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    echo "Warn : no ${CONSTANTS_FILE} found"
fi

#
# Put your test case code here
#

#
# As an example test case, simulate some work by sleeping
#
SLEEP_TIME=1
if [ $TIMEOUT ]; then
    echo "Overriding default sleep time to ${TIMEOUT}"
    SLEEP_TIME=${TIMEOUT}
fi

sleep ${SLEEP_TIME}

#
# Write some information to a summary log. This text will be
# included in the e-mail summary sent by ICA.  So only
# include what you want displayed in the e-mail message.
#
echo "slept for ${SLEEP_TIME} seconds" > summary.log

#
# If you have an error, handle the error. When terminating the
# test case, set the status to either ICA_TESTABORTED or
# ICA_TESTFAILED.
#
# UpdateTestState $ICA_TESTFAILED
# exit 1
#
# or
#
# Let ICA know we completed successfully
#
dbgprint 1 "Updating test case state to completed"
UpdateTestState $ICA_TESTCOMPLETED

exit 0

