#!/bin/sh
# mountpoint=/media/timo/1E63-B588
mountpoint=$1
if [ "" = "$1" ];
then
	echo "Usage: create.sh mountpoint"
	echo "mountpoint points to a FAT formatted storage card, such as /media/user/SDCARD"
	echo "Exiting."
	exit 1
fi

dev=`lsblk -oNAME,MOUNTPOINT -l | grep $mountpoint | cut -f1 -d' ' | sed -e 's/[0-9]*//g'` 
disk=/dev/$dev

if [ "" = "$dev" ];
then
	echo "No device found for $mountpoint. Exiting."
	exit 1
fi

echo "Using $mountpoint with device $disk"

echo "Finding partition offset"
ofs=`sudo parted -m /dev/sdc "UNIT b PRINT QUIT" | tail -1 | cut -d: -f2 | sed -e 's/B//'`
echo "First partition starts at $ofs bytes"

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
for f in `ls $mountpoint`;
do
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
	# echo $finfo
	fcluster=`echo $finfo | cut -d, -f 2 | sed -s 's/[^0-9]*//g'`
	fsize=`echo $finfo | cut -d, -f 3 | cut -d' ' -f 4 | sed -s 's/[^0-9]*//g'`
	fsize_in_secs=`echo "$fsize / $bytes_per_sector" | bc`
	# echo $fsize

	# find out cluster address for file
	# echo $fcluster
	# sudo fatcat $disk -O $ofs -@ $fcluster | tail +2 | head -1 | cut -f1 -d' '
	fclustaddr=`sudo fatcat -O $ofs $disk -@ $fcluster | tail +2 | head -1 | cut -f1 -d' '`
	fclustaddr=$((fclustaddr + ofs))
	faddr_in_secs=`echo "$fclustaddr / $bytes_per_sector" | bc`
	# echo $fclustaddr

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

echo "copy config file to SD card.."
cp scsi2sd_config.xml $mountpoint

echo "Done."
exit 0
