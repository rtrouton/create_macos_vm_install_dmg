This script prepares OS X or macOS installer disk images for use with VMware Fusion and ESXi. It's adapted from the **prepare_iso** script created by Tim Sutton: [https://github.com/timsutton/osx-vm-templates/tree/master/prepare_iso](https://github.com/timsutton/osx-vm-templates/tree/master/prepare_iso)

**Pre-requisites**

1. This script
2. An installer from Apple's Mac App Store for one of the following versions of Mac OS X, OS X or macOS:

* 10.7.x
* 10.8.x
* 10.9.x
* 10.10.x
* 10.11.x
* 10.12.x


**Running the script**

Run the `create_macos_vm_install_dmg.sh` script with two arguments: the path to an "Install macOS.app" or the InstallESD.dmg contained within, and an output directory. 


Example usage: 

If you have a 10.12.x Sierra installer available, run this command:

`sudo /path/to/create_macos_vm_install_dmg.sh "/Applications/Install macOS Sierra.app" /path/to/output_directory`

This should produce a DMG file at the specified output directory named something similar to  `macOS_InstallESD_10.12.4_16E195_20170329111134.dmg`. An MD5 checksum is printed at the end of the process.


What the script does:

1. Mounts the InstallESD.dmg using a shadow file, so the original DMG is left unchanged.

2. Creates `minstallconfig.xml` and `OSInstall.collection` files and moves them into the proper place, for later references by the installer environment's `rc.` files that first load with the system. This allows us to never actually modify the BaseSystem.dmg and only drop in these extra files.

3. If desired, a second disk image in `.iso` format can be generated for use with VMware ESXi servers running on Apple hardware. 


Once you have the customized DMG file created, you can choose it as an install disk image in VMware Fusion when creating virtual machines in VMware Fusion.

This script has been tested with the followinng OS installers from the Mac App Store:

* Mac OS X 10.7.5
* OS X 10.8.5
* OS X 10.9.5
* OS X 10.10.5
* OS X 10.11.6
* macOS 10.12.4




NOTES: 

The OS X 10.9.x disk images created with this method will not install a recovery partition into a VM. As a workaround, it appears that this can be addressed via using Per Olofsson’s **Create Recovery Partition Installer** app to generate an installer that can install the missing recovery partition.

**Create Recovery Partition Installer** is available from here on GitHub:
[https://github.com/MagerValp/Create-Recovery-Partition-Installer](https://github.com/MagerValp/Create-Recovery-Partition-Installer)

In my testing, 10.7.x, 10.8.x, 10.10.x, 10.11.x and 10.12.x disk images will successfully install a recovery partition into the VM.
