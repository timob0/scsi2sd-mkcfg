#!/bin/sh
mountpoint=$1
if [ "" = "$1" ];
then
	echo "Usage: $0 mountpoint"
	echo "mountpoint points to a FAT formatted storage card, such as /Volumes/SDCARD"
	echo "Exiting."
	exit 1
fi

dev=`diskutil info "$mountpoint" | grep "Device Node" | cut -c31-`
disk=/dev/`diskutil info "$mountpoint" | grep "Part of Whole" | cut -c31-`

echo "Unmounting disk.."
diskutil unmountDisk $disk

if [ "" = "$dev" ];
then
	echo "No device found for $mountpoint. Exiting."
	exit 1
fi

echo "Using $mountpoint with disk $disk device $dev"

echo "Finding FAT partition and partition offset"
part=`sudo fdisk $disk | grep FAT`
if [ "" = "$part" ];
then
	echo "No FAT partition found. Exiting."
fi
echo $part

startsector=`sudo fdisk $disk | grep FAT | cut -f2 -d'[' | cut -f1 -d']' | cut -f1 -d'-' | sed 's/ *//'`
ofs=$((startsector*512))
echo "First partition starts at block $startsector ($ofs bytes)"

# Check if we have a FAT formatted disk
if [ "FAT" != `sudo fatcat $disk -O $ofs -i | tail +3 | head -1 | cut -c18-20` ];
then
	echo "Disk $disk is not FAT formatted. Exiting."
	exit 1
fi

# Get disk info
dskinf=`sudo fatcat $disk -O $ofs -i | tail -16 | head -3`

bytes_per_sector=`echo $dskinf | sed -e 's/[a-zA-Z ]*//g' | cut -d: -f2`
sectors_per_cluster=`echo $dskinf | sed -e 's/[a-zA-Z ]*//g' | cut -d: -f3`
bytes_per_cluster=`echo $dskinf | sed -e 's/[a-zA-Z ]*//g' | cut -d: -f4`

ofs_sect=$((ofs / bytes_per_sector))

echo Bytes per sector: $bytes_per_sector
echo Sectors per cluster: $sectors_per_cluster
echo Bytes per cluster: $bytes_per_cluster
echo FAT partition start at $ofs_sect sectors into the card

rm -f devices.xml
scsitgt=1
for f in `sudo fatcat $disk -O $ofs -l / | tail -n+3 | grep '^f' | cut -f5 -d' '`;
do
	echo "************************************************************************************************************"
	echo Found file $f
	typ=`echo $f | cut -d. -f2`
	devtype=0x9
	if [ "img" = $typ ]; then
		devtype=0x0
	elif [ "dsk" = $typ ]; then
		devtype=0x0
	elif [ "iso" = $typ ]; then
		devtype=0x1
	fi

	if [ "0x9" = $devtype ]; then
		echo "Skipping file $f, not a disk image"
		continue
	fi
	finfo=`sudo fatcat $disk -O $ofs -e /$f`
	# echo FINFO $finfo
	fcluster=`echo $finfo | cut -d, -f 2 | sed 's/[^0-9]*//g'`
	fsize=`echo $finfo | cut -d, -f 3 | cut -d' ' -f 4 | sed 's/[^0-9]*//g'`
	fsize_in_secs=`echo "$fsize / $bytes_per_sector" | bc`
	# echo FSIZE $fsize

	# find out cluster address for file
	# echo FCLUSTERNO. $fcluster
	#           sudo fatcat $disk -O $ofs -@ $fcluster | tail +2 | head -1 | cut -f1 -d' '
	fclustaddr=`sudo fatcat $disk -O $ofs -@ $fcluster | tail +2 | head -1 | cut -f1 -d' '`
	# echo FCLUSTADR $fclustaddr bytes
	fclustaddr=$((fclustaddr + ofs))
	# echo FCLUSTADR+OFS $fclustaddr bytes
	faddr_in_secs=`echo "$fclustaddr / $bytes_per_sector" | bc`
	# echo FCLUSTADR $faddr_in_secs blocks

	echo "File $f size is $fsize bytes ($fsize_in_secs blocks) starting at address $fclustaddr ($faddr_in_secs blocks)"

	echo "<SCSITarget id=\"$scsitgt\">" >> devices.xml
        echo "	<enabled>true</enabled>" >> devices.xml
        echo "	<quirks>apple</quirks>" >> devices.xml
        echo "	<deviceType>0x0</deviceType>" >> devices.xml
        echo "	<deviceTypeModifier>0x0</deviceTypeModifier>" >> devices.xml
        echo "	<sdSectorStart>$faddr_in_secs</sdSectorStart>" >> devices.xml
        echo "	<scsiSectors>$fsize_in_secs</scsiSectors>" >> devices.xml
        echo "	<bytesPerSector>512</bytesPerSector>" >> devices.xml
        echo "	<sectorsPerTrack>63</sectorsPerTrack>" >> devices.xml
        echo "	<headsPerCylinder>255</headsPerCylinder>" >> devices.xml
        echo "	<vendor> SEAGATE</vendor>" >> devices.xml
        echo "	<prodId>          ST225N</prodId>" >> devices.xml
        echo "	<revision> 1.0</revision>" >> devices.xml
        echo "	<serial>123456781234000$scsitgt</serial>" >> devices.xml
	echo "</SCSITarget>" >> devices.xml
	scsitgt=$((scsitgt + 1))
done

echo "Generating config file scsi2sd_config.xml.."

# Create scsi2sd config file
echo "<SCSI2SD>"     > scsi2sd_config.xml
cat boardconfig.xml >> scsi2sd_config.xml
cat devices.xml     >> scsi2sd_config.xml
echo "</SCSI2SD>"   >> scsi2sd_config.xml

echo Remounting disk...
sudo diskutil mountDisk $disk
echo "Please copy scsi2sd_config.xml file to SD card and use it to reconfigure SCSI2SD on target machine."
cp scsi2sd_config.xml $mountpoint

echo "Done."
exit 0
