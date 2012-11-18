#!/bin/bash



# Functions used in the script
# ------------------------------------------------------------------------------

# Function to print usage report to stderr
function print_usage {
	echo "" >&2
	echo "$0: Builds project in release mode and packages it into an IPA file." >&2
	echo "" >&2
	echo "Usage: $0 -o output.ipa [options]" >&2
	echo "Options:" >&2
	echo "  -b <build_dir>    Specify build dir, defaults to './build' if not specified." >&2
	echo "  -c                Clean up (delete) the build directory afterwards." >&2
	echo "  -h                Show this help." >&2
	echo "  -o <output_ipa>   The name of the output ipa file." >&2
	echo "" >&2
	echo "Usage examples:" >&2
	echo "$0 -o MyApp.ipa -c" >&2
	echo "$0 -h" >&2
	echo "" >&2
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

# Parse the options
while getopts ":cho:p:s:" opt; do
	case $opt in
	b)
		BUILD_DIR="$OPTARG"
		;;
	c)
		cleanup=1
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

# Cleanup...
if [ $cleanup -ne 0 ]; then
	echo
	echo "Cleaning up..."
	rm -rf "$BUILD_DIR"
fi
