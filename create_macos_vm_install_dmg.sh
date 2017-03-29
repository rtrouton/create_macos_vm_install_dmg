#!/bin/sh
#
# Preparation script for a customized OS X or macOS installer for use with VWware Fusion and ESXi
# 
# What the script does, in more detail:
# 
# 1. Mounts the InstallESD.dmg using a shadow file, so the original DMG is left
#    unchanged.
#
# 2. minstallconfig.xml is also copied, which is looked for by the installer environment's 
#    rc.* files that first load with the system. This allows us to never actually modify the 
#    BaseSystem.dmg and only drop in these extra files.
#
# 3. If desired, a second disk image in .iso format can be generated for use with VMware ESXi
#    servers running on Apple hardware. 
#
# Original script written by Tim Sutton:
# https://github.com/timsutton/osx-vm-templates/tree/master/prepare_iso
#
# Thanks: (brought over from Tim's original script)
# Idea and much of the implementation thanks to Pepijn Bruienne, who's also provided
# some process notes here: https://gist.github.com/4542016. The sample minstallconfig.xml,
# use of OSInstall.collection and readme documentation provided with Greg Neagle's
# createOSXInstallPkg tool also proved very helpful. (http://code.google.com/p/munki/wiki/InstallingOSX)
#
# User creation via package install method also credited to Greg, and made easy with Per
# Olofsson's CreateUserPkg (http://magervalp.github.io/CreateUserPkg)
#
# Antony Blakey for updates to support OS X 10.11:
# https://github.com/timsutton/osx-vm-templates/issues/40

usage() {
	cat <<EOF
Usage:
$(basename "$0") "/path/to/InstallESD.dmg" /path/to/output/directory
$(basename "$0") "/path/to/Install OS X [Name].app" /path/to/output/directory

Description:
Converts an OS X 10.7 and later, or macOS 10.12 and later, installer image to a new image that contains components
used to perform an automated installation. The new image will be named
'OSX_InstallESD_[osversion].dmg.' or macOS_InstallESD_[osversion].dmg.

EOF
}

msg_status() {
	echo "\033[0;32m-- $1\033[0m"
}
msg_error() {
	echo "\033[0;31m-- $1\033[0m"
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

if [ $(id -u) -ne 0 ]; then
	msg_error "This script must be run as root, as it saves a disk image with ownerships enabled."
	exit 1
fi	

ESD="$1"
if [ ! -e "$ESD" ]; then
	msg_error "Input installer image $ESD could not be found! Exiting.."
	exit 1
fi

if [ -d "$ESD" ]; then
	# we might be an install .app
	if [ -e "$ESD/Contents/SharedSupport/InstallESD.dmg" ]; then
		ESD="$ESD/Contents/SharedSupport/InstallESD.dmg"
	else
		msg_error "Can't locate an InstallESD.dmg in this source location $ESD!"
	fi
fi

SCRIPT_DIR="$(cd $(dirname "$0"); pwd)"
DEFINITION_DIR="$(cd $SCRIPT_DIR/..; pwd)"

if [ "$2" == "" ]; then
    msg_error "Currently an explicit output directory is required as the second argument."
	exit 1
else
	OUT_DIR="$2"
fi

if [ ! -d "$OUT_DIR" ]; then
	msg_status "Destination dir $OUT_DIR doesn't exist, creating.."
	mkdir -p "$OUT_DIR"
fi

if [ -e "$ESD.shadow" ]; then
	msg_status "Removing old shadow file.."
	rm "$ESD.shadow"
fi

# Script will prompt user if they want an additional image in .iso
# format for use with a VMware ESXi server.

echo "Do you also want an ISO disk image for use with VMware ESXi?"
select yn in "Yes" "No"; do
	case $yn in
		Yes) ISO=1; break;;
		No) msg_error "ISO disk image will not be created. Proceeding.."; break;;
	esac
done

MNT_ESD=$(/usr/bin/mktemp -d /tmp/vmware-apple-esd.XXXX)
SHADOW_FILE=$(/usr/bin/mktemp /tmp/vmware-apple-shadow.XXXX)
rm "$SHADOW_FILE"
msg_status "Attaching input installer image with shadow file.."
hdiutil attach "$ESD" -mountpoint "$MNT_ESD" -shadow "$SHADOW_FILE" -nobrowse -owners on 
if [ $? -ne 0 ]; then
	[ ! -e "$ESD" ] && msg_error "Could not find $ESD in $(pwd)"
	msg_error "Could not mount $ESD on $MNT_ESD"
	exit 1
fi

msg_status "Mounting BaseSystem.."
 BASE_SYSTEM_DMG="$MNT_ESD/BaseSystem.dmg"
 MNT_BASE_SYSTEM=$(/usr/bin/mktemp -d /tmp/vmware-apple-basesystem.XXXX)
 [ ! -e "$BASE_SYSTEM_DMG" ] && msg_error "Could not find BaseSystem.dmg in $MNT_ESD"
 hdiutil attach "$BASE_SYSTEM_DMG" -mountpoint "$MNT_BASE_SYSTEM" -nobrowse -owners on
 if [ $? -ne 0 ]; then
 	msg_error "Could not mount $BASE_SYSTEM_DMG on $MNT_BASE_SYSTEM"
 	exit 1
fi

SYSVER_PLIST_PATH="$MNT_BASE_SYSTEM/System/Library/CoreServices/SystemVersion.plist"


DMG_OS_VERS=$(/usr/libexec/PlistBuddy -c 'Print :ProductVersion' "$SYSVER_PLIST_PATH")
DMG_OS_VERS_MAJOR=$(echo $DMG_OS_VERS | awk -F "." '{print $2}')
DMG_OS_VERS_MINOR=$(echo $DMG_OS_VERS | awk -F "." '{print $3}')
DMG_OS_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :ProductBuildVersion' "$SYSVER_PLIST_PATH")

if [[ $DMG_OS_VERS_MAJOR -ge 12 ]]; then
  OSNAME=macOS
else
  OSNAME=OSX
fi
 
if [[ $DMG_OS_VERS_MAJOR -ge 13 ]]; then
    APFS=1
fi

msg_status "$OSNAME version detected: 10.$DMG_OS_VERS_MAJOR.$DMG_OS_VERS_MINOR, build $DMG_OS_BUILD"

DATE=$(date +%Y%m%d%H%M%S)
OUTPUT_DMG="$OUT_DIR/${OSNAME}_InstallESD_${DMG_OS_VERS}_${DMG_OS_BUILD}_${DATE}.dmg"
if [ -e "$OUTPUT_DMG" ]; then
	msg_error "Output file $OUTPUT_DMG already exists! We're not going to overwrite it, exiting.."
    hdiutil detach -force "$MNT_ESD"
	exit 1
fi

# We'd previously mounted this to check versions
hdiutil detach "$MNT_BASE_SYSTEM"

BASE_SYSTEM_DMG_RW="$(/usr/bin/mktemp /tmp/vmware-apple-basesystem-rw.XXXX).dmg"

msg_status "Creating empty read-write DMG located at $BASE_SYSTEM_DMG_RW.."
hdiutil create -o "$BASE_SYSTEM_DMG_RW" -size 10g -layout SPUD -fs HFS+J
hdiutil attach "$BASE_SYSTEM_DMG_RW" -mountpoint "$MNT_BASE_SYSTEM" -nobrowse -owners on

msg_status "Restoring the BaseSystem to the read-write DMG using asr.."

# This asr restore is needed as of 10.11 DP7 and up. See
# https://github.com/timsutton/osx-vm-templates/issues/40
#
# Note that when the restore completes, the volume is automatically re-mounted
# into /Volumes instead of the previous mountpoint. It is also visible as the 
# "-nobrowse" option is not applied.

asr restore --source "$BASE_SYSTEM_DMG" --target "$MNT_BASE_SYSTEM" --noprompt --noverify --erase

# To fix the volume being visible when remounted, check for the new
# volume which is mounted in /Volumes and unmount it.

if [[ -e "/Volumes/OS X Base System" ]]; then
   umount "/Volumes/OS X Base System"
elif [[ -e "/Volumes/Mac OS X Base System" ]]; then
   umount "/Volumes/Mac OS X Base System"
fi

# Remounting the disk image outside of /Volumes with the '-nobrowse' option.

hdiutil attach "$BASE_SYSTEM_DMG_RW" -mountpoint "$MNT_BASE_SYSTEM" -nobrowse -owners on

if [[ $DMG_OS_VERS_MAJOR -ge 9 ]]; then
    BASESYSTEM_OUTPUT_IMAGE="$OUTPUT_DMG"
    PACKAGES_DIR="$MNT_BASE_SYSTEM/System/Installation/Packages"

    rm "$PACKAGES_DIR"
	msg_status "Moving 'Packages' directory from the ESD to BaseSystem.."
	mv -v "$MNT_ESD/Packages" "$MNT_BASE_SYSTEM/System/Installation/"

	# This isn't strictly required for Mavericks, but Yosemite will consider the
	# installer corrupt if this isn't included, because it cannot verify BaseSystem's
	# consistency and perform a recovery partition verification
	msg_status "Copying in original BaseSystem dmg and chunklist.."
	cp "$MNT_ESD/BaseSystem.dmg" "$MNT_BASE_SYSTEM/"
	cp "$MNT_ESD/BaseSystem.chunklist" "$MNT_BASE_SYSTEM/"
else
    BASESYSTEM_OUTPUT_IMAGE="$MNT_ESD/BaseSystem.dmg"
    rm "$BASESYSTEM_OUTPUT_IMAGE"
	PACKAGES_DIR="$MNT_ESD/Packages"
fi

# Adding a custom rc.cdrom.local that will automatically erase the VM's
# boot drive. Also adding our auto-setup files: minstallconfig.xml and 
# OSInstall.collection

msg_status "Adding automated components.."
CDROM_LOCAL="$MNT_BASE_SYSTEM/private/etc/rc.cdrom.local"
if [[ ${APFS} -eq 1 ]]; then
    echo "diskutil eraseDisk apfs \"Macintosh HD\" GPTFormat disk0" > "$CDROM_LOCAL"
    msg_status "VM boot drive will be formatted using APFS."
else
    echo "diskutil eraseDisk jhfs+ \"Macintosh HD\" GPTFormat disk0" > "$CDROM_LOCAL"
    msg_status "VM boot drive will be formatted using HFS+ with journaling enabled."
fi
chmod a+x "$CDROM_LOCAL"
mkdir "$PACKAGES_DIR/Extras"
/bin/cat > "$PACKAGES_DIR/Extras/"minstallconfig.xml << 'minstallconfig_xml'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>InstallType</key>
	<string>automated</string>
	<key>Language</key>
	<string>en</string>
	<key>Package</key>
	<string>/System/Installation/Packages/OSInstall.collection</string>
	<key>Target</key>
	<string>/Volumes/Macintosh HD</string>
	<key>TargetName</key>
	<string>Macintosh HD</string>
</dict>
</plist>
minstallconfig_xml

/bin/cat > "$PACKAGES_DIR/"OSInstall.collection << 'osinstall_collection'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
	<string>/System/Installation/Packages/OSInstall.mpkg</string>
	<string>/System/Installation/Packages/OSInstall.mpkg</string>
</array>
</plist>
osinstall_collection

msg_status "Unmounting BaseSystem.."
hdiutil detach "$MNT_BASE_SYSTEM"

if [ $DMG_OS_VERS_MAJOR -lt 9 ]; then
	msg_status "Pre-Mavericks we save back the modified BaseSystem to the root of the ESD."
	hdiutil convert -format UDZO -o "$MNT_ESD/BaseSystem.dmg" "$BASE_SYSTEM_DMG_RW"
fi

msg_status "Unmounting.."
hdiutil detach "$MNT_ESD"

msg_status "Converting to .dmg disk image.."

if [[ $DMG_OS_VERS_MAJOR -ge 9 ]]; then
	msg_status "On Mavericks and later, the entire modified BaseSystem is our output dmg."
	hdiutil convert -format UDZO -o "$OUTPUT_DMG" "$BASE_SYSTEM_DMG_RW"
else
	msg_status "Pre-Mavericks we're modifying the original ESD file."
	hdiutil convert -format UDZO -o "$OUTPUT_DMG" -shadow "$SHADOW_FILE" "$ESD"
fi

rm -rf "$MNT_ESD" "$SHADOW_FILE" "$BASE_SYSTEM_DMG_RW"

if [[ $ISO = 1 ]]; then
   OUTPUT_ISO="$OUT_DIR/${OSNAME}_InstallESD_${DMG_OS_VERS}_${DMG_OS_BUILD}_${DATE}.iso"
   msg_status "Converting to .iso disk image...."
   /usr/bin/hdiutil convert "$OUTPUT_DMG" -format UDTO -o "$OUTPUT_ISO"
   /bin/mv $OUT_DIR/${OSNAME}_InstallESD_${DMG_OS_VERS}_${DMG_OS_BUILD}_${DATE}.iso.cdr "$OUTPUT_ISO"
fi

if [[ -n "$SUDO_UID" ]] && [[ -n "$SUDO_GID" ]]; then
	msg_status "Fixing permissions.."
	chown -R $SUDO_UID:$SUDO_GID "$OUT_DIR"
fi

msg_status "Checksumming .dmg disk image.."
MD5=$(md5 -q "$OUTPUT_DMG")
msg_status "MD5: $MD5"
msg_status "Built .dmg disk image is located at $OUTPUT_DMG."

if [[ -f "$OUTPUT_ISO" ]]; then
  msg_status "Checksumming .iso disk image.."
  MD5=$(md5 -q "$OUTPUT_ISO")
  msg_status "MD5: $MD5"
  msg_status "Built .iso disk image is located at $OUTPUT_ISO."
fi

msg_status "Build process finished."