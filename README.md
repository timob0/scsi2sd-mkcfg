# scsi2sd-mkcfg
A tool to configure SCSI2SD for FAT formatted SD cards with multiple disk images

## What?

This script helps you to generate a scsi2sd_config.xml file for a FAT formatted SD card that holds multiple harddisk images. It will scan the SD card for files with suffixes of .dsk, .img or .iso and add them as virtual SCSI drives to the config file. It will figure out from the partition layout and the FAT filesystem structure at which sector addresses the files are stored on the SD card and what their size is.

Once the config file is generated, tweak it as per you needs (remove SCSI ids you don't need etc.) and use the scsi2sd-util application to upload it to the SCSI2SD hardware. Then pop in the SD card and you should see your new SCSI disks on the target computer.

## Why?

Out of the box, scsi2sd works with raw SD cards, i.e. you have to use lowlevel tools to transfer your images - such as dd etc. which means that on a regular computer, you can't see what's on the card and more importantly, you can't use it with emulators to update your images. This script aims to help with that so that you can interchange the FAT formatted card with emulators and with real, SCSI based computers.

## How?

1) Prepare your SD card, i.e. format it with FAT32 (exFAT on Mac, vfat on Linux)
2) Copy over the disk images you wish to use, make sure they have a img or dsk suffix (iso should also work and give you a virtual SCSI CD-Rom)
3) Clone this repo to some folder (`git clone https://github.com/timob0/scsi2sd-mkcfg.git`), make the script(s) executable (`chmod 775 mkcfg_*.sh`)
4) Install fatcat (see below)
5) Review and adjust boardconfig.xml (the one included works for a 5.1 rev SCSI2SD)
6) Find the mountpoint of your SD card (Linux: /media/user/cardname, Mac: /Volumes/CARDNAME)
7) Run the mkcfg_linux.sh or mkcfg_osx.sh script, depending which OS you are on. use the mountpoint from step 6) as a parameter, e.g. `./mkcfg_osx.sh /Volumes/PORTABLE`
8) Review the generated scsi2sd_config.xml, check board configuration and SCSI ids
9) Use scsi2sd-util to transfer the config file to the SCSI2SD board (load from file, save to device)
10) Pop the sdcard into the SCSI2SD board and use it with your target computer

## Needed software:
- You need the fatcat binary installed on your computer:
  - On both, Linux and Mac, clone this repo: https://github.com/Gregwar/fatcat.git
  - On Linux: Follow the instructions on the README file to configure, build and install
  - On Mac: Overlay the downloaded source with the provided, patched fatcat.cpp from this repo (fatcat/src/fatcat.cpp), then follow the README to build and install. Alternatively, the fatcat binary for x86_64 is included in this repo in bin/osx/fatcat (add it to PATH or copy to /usr/local/bin)
  - Both: Verify that you have fatcat on your path and it's version 1.1.0 (type in fatcat in terminal, you should get the help screen)

## Caveats:
- This is terminal based, no UI
- This is avaialable for Linux and Mac OSX, no Windows version included. Should be possible to port to Cygwin though.
- The image files on the SD card must be stored on contigous blocks. This usually is ensured when adding images to a frehly formatted card. Once you start deleting and replacing images, chances a high that they get fragmented (=stored in multiple pieces on different locations on the card) which makes them unusable on the target system and very likely will lead to corruption. To work around this, when you have to replace images, just rename the old one and add a different suffix (.old) and add the updated image. From time to time, backup the SD card to a computer, format it and add back the files, leaving out the to be deleted ones. This way you will make sure that files always occupy contigous space.
- The script will assign SCSI IDs to each .img, .dsk and .iso file in the order it finds them. To deactivate an image, just replace the suffix with something else and rerun the script. You still might have to change the SCSI Id in the config file.
- SCSI CD ROms are theoretically supported, an image with .iso suffix will be configured as a SCSI CD Rom drive type. Some additional work is required to report back a different sector size and vendor.
- This has been tested with a Macintosh Portable, Model 5120 only, using disk images that I've created with the Basilisk Emulator on a Mac OS X computer. There is no guarantee this will work on any other configuration. 

## TODO:
- Complete SCSI CD Rom support
- Align with bluescsi naming convention (type and id part of the filename)

## Disclaimer:
Use this on your own risk, I will not be liable for damage whatsoever caused the use of the provided software.
