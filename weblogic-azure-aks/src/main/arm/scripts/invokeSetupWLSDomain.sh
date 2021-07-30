# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script starts"

#Function to output message to stdout
function echo_stderr() {
    echo "$@" >&2
    echo "$@" >>stdout
}

function echo_stdout() {
    echo "$@" >&2
    echo "$@" >>stdout
}

# PENDING(edburns): write some of the parameters to file.  Others are passed directly to the script.
function write_parameters_to_file() {
}


#Function to display usage message
function usage() {
    echo_stdout "./invokeSetupWLSDomain.sh ..."
    if [ $1 -eq 1 ]; then
        exit 1
    fi
}

#Function to validate input
function validate_input() {

}

validate_input

# invoke the setupWLSDomain passing the parameters and the file

exit $exitCode
