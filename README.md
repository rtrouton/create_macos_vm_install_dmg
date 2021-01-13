This script prepares macOS installer disk images for use with virtualization software like VMware Fusion or Parallels. 

**Pre-requisites**

1. This script
2. An installer for one of the following versions of macOS:

* 10.12.x
* 10.13.x
* 10.14.x
* 10.15.x
* 11.1


**Running the script**

Run the `create_macos_vm_install_dmg.sh` script with two arguments: the path to an "Install macOS.app" and an output directory. 


Example usage: 

If you have a macOS Mojave 10.14.x installer available, run this command:

`sudo /path/to/create_macos_vm_install_dmg.sh "/Applications/Install macOS Mojave.app" /path/to/output_directory`

This should produce a disk image file at the specified output directory named something similar to  `macOS_[OS Version Number Here]_installer.dmg`.


What the script does:

1. Creates an empty read-write disk image file.

2. Uses the macOS installer's `createinstallmedia` tool to erase the disk image, copy the installer files and set up the disk image to be bootable.

3. If desired, a second disk image in `.iso` format can be generated. This should produce a disk image file at the specified output directory named something similar to  `macOS_[OS Version Number Here]_installer.iso`.

Once you have the disk image file created, you can choose it as an install disk image in VMware Fusion or Parallels when creating macOS virtual machines.

This script has been tested with the following OS installers:

* macOS 10.12.6
* macOS 10.13.6
* macOS 10.14.6
* macOS 10.15.5
* macOS 11.0 beta 3




**NOTE**: 

An earlier script for preparing disk images for macOS virtual machines is available in the `previous_version` directory. This script supports building installers for the following versions of Mac OS X, OS X and macOS:

* 10.7.x
* 10.8.x
* 10.9.x
* 10.10.x
* 10.11.x
* 10.12.x
