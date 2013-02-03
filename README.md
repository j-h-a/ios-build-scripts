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
