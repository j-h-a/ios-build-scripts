#!/bin/bash



# Functions used in the script
# ------------------------------------------------------------------------------

# Function to print usage report to stderr
function print_usage {
	cat - >&2 <<UsageDelimiter

$0: Builds project in release mode and packages it into an IPA file.

Usage: $0 -o output.ipa [options]
Options:
  -b <build_dir>    Specify build dir, defaults to './build' if not specified.
  -c                Clean up (delete) the build directory afterwards.
  -d <output_dsym>  The name of the (optional) output dSYM.zip file.
  -h                Show this help.
  -o <output_ipa>   The name of the output .ipa file (required).

Usage examples:
$0 -o MyApp.ipa -d MyApp.app.dSYM.zip -c
$0 -h

UsageDelimiter
}

# Function to print any error to stderr
function print_error {	# $1=theerror $2=printusage $3=exitcode
	echo "" >&2
	echo "ERROR: $1" >&2
	if [ $2 -ne 0 ]; then
		print_usage
	fi
	if [ $3 -ne 0 ]; then
		exit $3
	fi
}



# Start of script
# ------------------------------------------------------------------------------

# Init variables
help=0
error=""
cleanup=0
BUILD_DIR="./build"
OUTPUT_IPA=""
OUTPUT_DSYM=""

# Parse the options
while getopts ":b:cd:ho:" opt; do
	case $opt in
	b)
		BUILD_DIR="$OPTARG"
		;;
	c)
		cleanup=1
		;;
	d)
		OUTPUT_DSYM="$OPTARG"
		;;
	h)
		help=1
		;;
	o)
		OUTPUT_IPA="$OPTARG"
		;;
	\?)
		error="Unrecognised option: -$OPTARG"
		;;
	:)
		error="You must specify an argument for the -$OPTARG option."
		;;
	esac
done

# Check for requesting help
if [ $help -ne 0 ]; then
	print_usage
	exit 0
fi

# Make sure we got all required arguments
if [ -z "$error" ]; then
	# Required: OUTPUT_IPA
	if [ -z $OUTPUT_IPA ]; then
		error="You must specify an output IPA file."
	fi
fi

# Check for any errors
if [ -n "$error" ]; then
	print_error "$error" 1 1
fi

# We are good to go...
echo

# Remove build directory
rm -rf "$BUILD_DIR"

# Build project in release mode
xcodebuild CONFIGURATION_BUILD_DIR="$BUILD_DIR" -configuration Release clean build

# Package it into the IPA file
APP_BUNDLE=`ls -d $BUILD_DIR/*.app`
xcrun -verbose -sdk iphoneos PackageApplication "$APP_BUNDLE" -o "${PWD}/$OUTPUT_IPA"

# Check if we should zip up the dSYM directory
if [ -n $OUTPUT_DSYM ]; then
	# Zip up the dSYM directory
	mv $BUILD_DIR/*.app.dSYM .
	DSYM_DIR=`ls -d *.app.dSYM`
	zip $OUTPUT_DSYM -r $DSYM_DIR
	mv $DSYM_DIR $BUILD_DIR
fi

# Cleanup...
if [ $cleanup -ne 0 ]; then
	echo
	echo "Cleaning up..."
	rm -rf "$BUILD_DIR"
fi
