#!/usr/bin/env bash

#
# Run a Julia $COMMAND (see definition below) in an pristine environment with the
# package args[0] added. Set a timeout.
#
# Arguments:
# - args[0] -- package name
# - args[1] (optional) -- package version
#
# Env vars:
#  - BATCH=true will put the output to a file rather than on the console
#

args=( $1 )
pkg="${args[0]}"
COMMAND="Pkg.test(\"$pkg\");"
JULIACMD="/home/julia/Apps/julia-1.8.5-log/julia"
#JULIACMD="julia"
POSTPROC="/home/artem/data/Code/Haskell/dedup/dedup"
#POSTPROC="cat"

# Record the current directory. Note: don't move around or it'll stop working!
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Process args and build a command (PKG_INIT) to call Pkg accordingly
if [[ $# -eq 0 ]]; then
    echo "Error: missing arguments. Provide package name to process and, optionally, its version."
    exit 1
fi
if (( ${#args[@]} == 2 )); then
    ver="${args[1]}"
    PKG_INIT="Pkg.add(; name=\"$pkg\", version=\"$ver\")"
elif ! [ -z ${2+x} ]; then
    ver="$2"
    PKG_INIT="Pkg.add(; name=\"$pkg\", version=\"$ver\")"
else
    PKG_INIT="Pkg.add(\"$pkg\")"
fi
PKG_INIT="using Pkg; ${PKG_INIT}"
COMMAND="$PKG_INIT; $COMMAND"

# Silent versions of pushd/popd
pushd () {
    command pushd "$@" > /dev/null
}
popd () {
    command popd "$@" > /dev/null
}

#
# Prepare and cd into clean directory
# Intend to keep Julia depot there, so make a dir for it
#
mkdir -p "$pkg/depot"
pushd $pkg

#
# Call Julia with a timeout
#

# NOTE: Below the main command is spelled twice on every branch of if -- this is unfortunate
#       Make sure to edit both instances if you want to update the command
if [ -z "${BATCH}" ]; then
    JULIA_DEPOT_PATH="$PWD/depot" timeout 2400 $JULIACMD -e "$COMMAND" 2>&1 | $POSTPROC
    retcode=$?
    echo "$retcode" > test-result.txt
else
		echo "RUN TESTS    $pkg"
    out="$(JULIA_DEPOT_PATH="$PWD/depot" timeout 2400 $JULIACMD -e "$COMMAND" 2>&1 | $POSTPROC)"
    retcode=$?
    echo "$retcode" > test-result.txt
    echo "$out" > test-out.txt
    echo "FILTER TYPES $pkg"
    outlog="$(cat test-out.txt | sed -n -e 's/^.*JLSUBTYPELOG: //p' | sort | uniq)"
    echo "$outlog" > type-annotations.csv
    echo "ALL DONE     $pkg"
fi

popd

# ATTENTION
# The rm below is needed when run over big set of packages so that we don't run out
# of disk space. Otherwise it's pretty expensive to restart the analysis.
# rm -rf "$pkg/depot"
