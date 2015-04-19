iOS Build Scripts
=================

Useful scripts for building, signing, and distributing iOS projects.

make-ipa.sh
===========

	Builds project in release mode and packages it into an IPA file.

	Usage: make-ipa.sh -o output.ipa [options]
	Options:
	  -b <build_dir>    Specify build dir, defaults to './build' if not specified.
	  -c                Clean up (delete) the build directory afterwards.
	  -h                Show this help.
	  -o <output_ipa>   The name of the output ipa file.

	Usage examples:
	make-ipa.sh -o MyApp.ipa -c
	make-ipa.sh -h

publish-ota.sh
==============

	Publishes an IPA file for over-the-air installation.
	Generates two files (install.html and install.plist) that can be placed
	alongside the IPA file for over-the-air installation.

	Usage: publish-ota.sh -i input.ipa -u installURL [options]
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
	publish-ota.sh -i MyApp.ipa -o ~/public_html/ota -u http://example.com/ota -kv
	publish-ota.sh -h

re-sign-ipa.sh
==============

	Re-signs an IPA file.

	Usage: re-sign-ipa.sh -i input.ipa [options]
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
	re-sign-ipa.sh -i MyApp.ipa -o MyApp_resigned.ipa -p AppStoreProfile.mobileprovision -kvx
	re-sign-ipa.sh -h

json-validate.xcodecustomscript
===============================

This is a custom Xcode build script, intended to run from Xcode as part of the
build process. It strips single-line C++ style comments from JSON files and
validates the JSON at compile time.

The validation saves time if you are using hand-written JSON data in your app
bundle as it finds any errors at compile time, while the comments allow you to
annotate your hand-written JSON. Only lines that begin with `//` (optionally
preceeded by whitespace) are stripped.

    // This comment is supported and will be stripped
    {
        // This comment is also stripped
        "myArray" : [1, 2, 3] // This comment is not stripped
    }

The script outputs the file, line, and column of any errors in the format that
Xcode uses for errors. This means you can click on the error to jump straight
to it in the IDE and Xcode will annotate the affected lines with the error
message right in the editor.

### To use this script in your project:

1.  In the Project Navigator select your project, then in the 'TARGETS' section
    select your target and go to the 'Build Rules' tab.
2.  Click the '+' to add a custom build rule.
3.  In the text-field named "Process [Source files with names matching:]" enter
    `*.json`.
4.  In the section named "Using [Custom script:]" paste the contents of the
    `json-validate.xcodecustomscript` file.
5.  In the "Output Files" section below, click the '+' to add an output file
    and in the text field enter `$(DERIVED_FILE_DIR)/$(INPUT_FILE_NAME)` as the
    output file name.
6.  Optional: The name of the rule will be "Files '*.json' using Script" - you
    can click on this and change it to "Validate JSON", or whatever you like.
