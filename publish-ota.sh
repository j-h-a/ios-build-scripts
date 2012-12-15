#!/bin/bash



# Functions used in the script
# ------------------------------------------------------------------------------

# Function to print usage report to stderr
function print_usage {
	cat - >&2 <<UsageDelimiter

$0: Publishes an IPA file for over-the-air installation.
Generates two files (install.html and install.plist) that can be placed
alongside the IPA file for over-the-air installation.

Usage: $0 -i input.ipa -u installURL [options]
Options:
  -h                Show this help.
  -i <input_ipa>    Input IPA file. Must be supplied.
  -k                Keep temporary directory.
  -o <output_dir>   The output directory for the install files. If specified
                    install.html and install.plist will be generated here and
                    the IPA file will also be copied here. If not specified
                    the install files will be placed in the working directory.
  -u <install_url>  The URL where the files will be available. This should be
                    the URL path without trailing slash or filenames.
  -v                Include version information in the install.html file.

Usage examples:
$0 -i MyApp.ipa -o ~/public_html/ota -u http://example.com/ota -kv
$0 -h

UsageDelimiter
}

# Function to print any error to stderr
function print_error {	# $1=error_message $2=print_usage $3=exit_code
	echo "" >&2
	echo "ERROR: $1" >&2
	if [ $2 -ne 0 ]; then
		print_usage
	fi
	if [ $3 -ne 0 ]; then
		exit $3
	fi
}

# Function to create an over-the-air installation HTML file
function create_install_html {	# $1=url_path $2=app_name $3=output_file
	# Create the install HTML file
	cat - > "$3" <<InstallHtmlDelimiter
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
	<head>
		<meta name="viewport" content="width=device-width, user-scalable=yes">
		<title>$2 Over-the-air Installation</title>
		<style type="text/css">body{color:#000000;font:14px Arial, Helvetia, sans-serif; background-color: #FFFFFF;}</style>
	</head>
	<body>
		<a href="itms-services://?action=download-manifest&url=$1/install.plist">Install $2</a>
		$VERSION_INFO
	</body>
</html>
InstallHtmlDelimiter
}

# Function to create an over-the-air installation manifest (plist file)
function create_install_plist {	# $1=url_path $2=ipa_filename $3=bundle_id $4=app_version $5=display_name $6=output_file
	# Create the install manifest
	cat - > "$6" <<InstallPlistDelimiter
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>items</key>
		<array>
			<dict>
				<key>assets</key>
				<array>
					<dict>
						<key>kind</key>
						<string>software-package</string>
						<key>url</key>
						<string>$1/$2</string>
					</dict>
				</array>
				<key>metadata</key>
				<dict>
					<key>bundle-identifier</key>
					<string>$3</string>
					<key>bundle-version</key>
					<string>$4</string>
					<key>kind</key>
					<string>software</string>
					<key>title</key>
					<string>$5</string>
				</dict>
			</dict>
		</array>
	</dict>
</plist>
InstallPlistDelimiter
}



# Start of script
# ------------------------------------------------------------------------------

# Init variables
help=0
error=""
cleanup=1
copyipa=0
versioninfo=0
INPUT_IPA=""
OUTPUT_DIR="./"
INSTALL_URL=""
VERSION_INFO=""

# Parse the options
while getopts ":hi:ko:u:v" opt; do
	case $opt in
	h)
		help=1
		;;
	i)
		INPUT_IPA="$OPTARG"
		;;
	k)
		cleanup=0
		;;
	o)
		OUTPUT_DIR="$OPTARG"
		copyipa=1
		;;
	u)
		INSTALL_URL="$OPTARG"
		;;
	v)
		versioninfo=1
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
	# Required: INPUT_IPA
	if [ -z $INPUT_IPA ]; then
		error="You must specify an input IPA file."
	fi
	# Required: INSTALL_URL
	if [ -z $INSTALL_URL ]; then
		error="You must specify an installation URL."
	fi
fi

# Check for any errors
if [ -n "$error" ]; then
	print_error "$error" 1 1
fi

# We are good to go...

echo

# Create a clean temporary directory
TEMP_DIR="tmp"
rm -rf $TEMP_DIR
if [ $? -ne 0 ]; then print_error "Couldn't remove old temporary directory at $TEMP_DIR" 0 1; fi
mkdir $TEMP_DIR
if [ $? -ne 0 ]; then print_error "Couldn't create temporary directory at $TEMP_DIR" 0 1; fi
echo "Using temporary directory: $TEMP_DIR"

# unzip the IPA fila
echo "Unzipping IPA file..."
unzip $INPUT_IPA -d $TEMP_DIR 1>/dev/null
if [ $? -ne 0 ]; then print_error "Failed to unzip input IPA file: $INPUT_IPA" 0 1; fi

# Get the app bundle name with path
PAYLOAD_DIR="$TEMP_DIR/Payload"
APP_BUNDLE="$PAYLOAD_DIR/`ls $PAYLOAD_DIR/`"

# Get the info.plist file and bundle identifier
INFO_PLIST="$APP_BUNDLE/Info.plist"
BUNDLE_IDENTIFIER=`/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST"`
BUNDLE_VERSION=`/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST"`
BUNDLE_NAME=`/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$INFO_PLIST"`
echo "App Bundle: $APP_BUNDLE ($BUNDLE_IDENTIFIER v$BUNDLE_VERSION)"
IPA_FILENAME=`basename "$INPUT_IPA"`

# Get the version information
if [ $versioninfo -ne 0 ]; then
	MOD_VERS="$BUNDLE_VERSION"
	MOD_DATE=`stat -f %m $INPUT_IPA`
	MOD_DATE=`date -r $MOD_DATE`
	VERSION_INFO="<br> Version: $MOD_VERS <br> Updated: $MOD_DATE"
fi

# Create the installation html file
echo "Creating install files..."
# Create install HTML file: $1=url_path $2=app_name $3=output_file
create_install_html "$INSTALL_URL" "$BUNDLE_NAME" "$OUTPUT_DIR/install.html"
# Create install manifest: $1=url_path $2=ipa_filename $3=bundle_id $4=app_version $5=display_name $6=output_file
create_install_plist "$INSTALL_URL" "$IPA_FILENAME" "$BUNDLE_IDENTIFIER" "$BUNDLE_VERSION" "$BUNDLE_NAME" "$OUTPUT_DIR/install.plist"

# Copy the IPA file if required
if [ $copyipa -ne 0 ]; then
	echo "Copying $INPUT_IPA to $OUTPUT_DIR"
	cp "$INPUT_IPA" "$OUTPUT_DIR/"
fi

# Cleanup...
if [ $cleanup -ne 0 ]; then
	echo
	echo "Cleaning up..."
	rm -rf "$TEMP_DIR"
fi
