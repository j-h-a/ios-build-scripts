# !/bin/bash



# Functions used in the script
# ------------------------------------------------------------------------------

# Function to print usage report to stderr
function print_usage {
	cat - >&2 <<UsageDelimiter

$0: Re-signs an IPA file.

Usage: $0 -i input.ipa [options]
Options:
  -e <entitlements>             Supply custom entitlements. If not supplied
                                then default distribution entitlements will be
                                generated using values from the app bundle.
  -h                            Show this help.
  -i <input_ipa>                Input IPA file. Must be supplied.
  -k                            Keep temporary directory.
  -o <output_ipa>               If not supplied, input file is overwritten.
  -p <provisioning_profile>     Specify the provisioning profile to use. If not
                                supplied the one already in the bundle is used.
  -s <signing_identity>         Specify a different signing identity. Default
                                value is 'iPhone Distribution:'.
  -v                            Perform verification.
  -x                            Display extra information after verification
                                (only works with -v option).

Usage examples:
$0 -i MyApp.ipa -o MyApp_resigned.ipa -p AppStoreProfile.mobileprovision -kvx
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

# Function to create a default ResourceRules.plist file
function create_resource_rules {
	# Create the resource rules file
	cat - > "$RESOURCE_RULES" <<ResourceRulesPlistDelimiter
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>rules</key>
		<dict>
			<key>.*</key>
			<true/>
			<key>Info.plist</key>
			<dict>
				<key>omit</key>
				<true/>
				<key>weight</key>
				<real>10</real>
			</dict>
			<key>ResourceRules.plist</key>
			<dict>
				<key>omit</key>
				<true/>
				<key>weight</key>
				<real>100</real>
			</dict>
		</dict>
	</dict>
</plist>
ResourceRulesPlistDelimiter
}

# Function to create a default entitlements file
function create_entitlements {
	# Create the entitlements file
	cat - > "$ENTITLEMENTS" <<EntitlementsPlistDelimiter
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>application-identifier</key>
		<string>$BUNDLE_SEED.$BUNDLE_IDENTIFIER</string>
		<key>get-task-allow</key>
		<false/>
		<key>keychain-access-groups</key>
		<array>
			<string>$BUNDLE_SEED.*</string>
		</array>
	</dict>
</plist>
EntitlementsPlistDelimiter
}



# Start of script
# ------------------------------------------------------------------------------

# Init variables
help=0
error=""
verify=0
cleanup=1
extra=0
INPUT_IPA=""
OUTPUT_IPA=""
SIGN_IDENTITY="iPhone Distribution:"
PROV_PROFILE=""
ENTITLEMENTS=""

# Parse the options
while getopts ":e:hi:ko:p:s:vx" opt; do
	case $opt in
	e)
		ENTITLEMENTS="$OPTARG"
		;;
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
		OUTPUT_IPA="$OPTARG"
		;;
	p)
		PROV_PROFILE="$OPTARG"
		;;
	s)
		SIGN_IDENTITY="$OPTARG"
		;;
	v)
		verify=1
		;;
	x)
		extra=1
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
unzip "$INPUT_IPA" -d $TEMP_DIR 1>/dev/null
if [ $? -ne 0 ]; then print_error "Failed to unzip input IPA file: $INPUT_IPA" 0 1; fi

# Get the app bundle name with path
PAYLOAD_DIR="$TEMP_DIR/Payload"
APP_BUNDLE="$PAYLOAD_DIR/`ls $PAYLOAD_DIR/`"

# Get the info.plist file and bundle identifier
INFO_PLIST="$APP_BUNDLE/Info.plist"
BUNDLE_IDENTIFIER=`/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST"`
echo "App Bundle: $APP_BUNDLE ($BUNDLE_IDENTIFIER)"

# Use existing provisioning profile if none specified
if [ -z "$PROV_PROFILE" ]; then
	PROV_PROFILE="$APP_BUNDLE/embedded.mobileprovision"
fi

# Use input IPA as output if no output file specified
if [ -z "$OUTPUT_IPA" ]; then
	OUTPUT_IPA="$INPUT_IPA"
fi

# Signing...

# Create the resource rules
RESOURCE_RULES="$TEMP_DIR/ResourceRules.plist"
create_resource_rules
echo "Resource Rules created: $RESOURCE_RULES"

# Create default entitlements file if one wasn't specified
if [ -z "$ENTITLEMENTS" ]; then
	# Get the bundle seed (use the first one from the ApplicationIdentifierPrefix array in the provisioning profile)
	security cms -D -i "$PROV_PROFILE" > "$TEMP_DIR/mobileprovision.plist"
	BUNDLE_SEED=`/usr/libexec/PlistBuddy -c 'Print :ApplicationIdentifierPrefix:0' "$TEMP_DIR/mobileprovision.plist"`
	# Create entitlements file
	ENTITLEMENTS="$TEMP_DIR/Entitlements.plist"
	create_entitlements
	echo "Entitlements created: $ENTITLEMENTS ($BUNDLE_SEED.$BUNDLE_IDENTIFIER)"
fi

# Sign the app bundle
echo
echo "Signing the app bundle at $APP_BUNDLE..."
codesign --resource-rules "$RESOURCE_RULES" --entitlements "$ENTITLEMENTS" -fs "$SIGN_IDENTITY" "$APP_BUNDLE"
if [ $? -ne 0 ]; then print_error "Codesign failed, stopping." 0 1; fi

# Packaging...

# Use xcrun to run the PackageApplication tool (create the output IPA file)
echo
echo "Packaging app into $OUTPUT_IPA..."
xcrun -verbose -sdk iphoneos PackageApplication "$APP_BUNDLE" -o "${PWD}/$OUTPUT_IPA" --sign "$SIGN_IDENTITY" --embed "$PROV_PROFILE"
if [ $? -ne 0 ]; then print_error "PackageApplication failed, stopping." 0 1; fi

# Verification...
if [ $verify -ne 0 ]; then
	echo
	echo "Verifying $APP_BUNDLE..."
	rm -rf "$PAYLOAD_DIR"
	unzip $OUTPUT_IPA -d $TEMP_DIR 1>/dev/null
	codesign -v "$APP_BUNDLE"
	if [ $? -ne 0 ]; then print_error "Verification failed." 0 0; fi
	# Display extra info
	if [ $extra -ne 0 ]; then
		echo
		echo "Extra Info - Embedded Provisioning Profile"
		echo "------------------------------------------"
		security cms -D -i "$APP_BUNDLE/embedded.mobileprovision"
		echo
		echo "Extra Info - Bundle Contents Info"
		echo "---------------------------------"
		codesign -dvvvv "$APP_BUNDLE"
		echo
		echo "Extra Info - Embedded Entitlements"
		echo "----------------------------------"
		codesign -d --entitlements - "$APP_BUNDLE"
	fi
fi

# Cleanup...
if [ $cleanup -ne 0 ]; then
	echo
	echo "Cleaning up..."
	rm -rf "$TEMP_DIR"
fi
