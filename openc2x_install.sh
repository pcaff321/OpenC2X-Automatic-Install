#!/bin/bash

# Make sure this script is run as sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Do you have a USB device to write to? (y/n)" && read use_USB

if [[ $use_USB == 'y' ]]; then
    # Set the FILESDIR variable on your shell and select the USB device to write to. 
    FILESDIR=$USER_HOME/OpenC2X_Image
    echo "--------------------------------------------------------"
    lsblk | grep sd
    echo "--------------------------------------------------------"
    echo "Please select your USB drive from the device list above. It must begin with /dev/ and typed in this format: /dev/sdb"
    echo && echo "---->" && read DEVICE
    echo "--------------------------------------------------------"
    echo "The USB device you have selected is:" $DEVICE
    echo "--------------------------------------------------------"
else
    echo "Not writing to USB. Please manually install image to USB after image is prepared."
fi


PS3='Please select your preferred configuration listed above: '
options=("default" "ar71xx_generic" "x86_64" "x86_geode" "Quit")
select opt in "${options[@]}"
do
    case $REPLY in
        "1")
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "2")
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "3")
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "4")
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "Quit")
            exit 1
            break
            ;;
        *) echo "no config chosen, cancelling"
           exit 1;;
    esac
done


# Download packages

sudo apt install build-essential ccache ecj fastjar file g++ gawk gettext git java-propose-classpath libelf-dev libncurses5-dev libncursesw5-dev libssl-dev python python2.7-dev python3 unzip wget python3-setuptools python3-dev rsync subversion swig time xsltproc zlib1g-dev python3-distutils-extra python3-distlib asciidoc bash binutils bzip2 flex git-core g++ gcc util-linux gawk help2man intltool libelf-dev zlib1g-dev make libncurses5-dev libssl-dev patch perl-modules python3-dev unzip wget gettext xsltproc zlib1g-dev libboost-dev libxml-parser-perl libusb-dev bin86 bcc sharutils gcc-multilib openjdk-8-jdk git


# Download OpenC2X
git clone https://github.com/florianklingler/OpenC2X-embedded.git


# Enter the OpenC2X directory

cd OpenC2X-embedded/


./scripts/feeds update -a

./scripts/feeds install -a

CONFIG_SOURCE=configs/config.$opt.default

if [ "$opt" = "default" ]; then
    CONFIG_SOURCE='configs/config.default'
fi


cp $CONFIG_SOURCE .config
cat configs/config.default >> .config
echo 'CONFIG_PACKAGE_gpsd-clients=y' >> .config
echo 'CONFIG_PACKAGE_hostapd=y' >> .config
echo 'CONFIG_PACKAGE_kmod-ath9k=y' >> .config
echo 'CONFIG_PACKAGE_ath9k-htc-firmware=y' >> .config
echo 'CONFIG_PACKAGE_tcpdump=y' >> .config
echo 'CONFIG_PACKAGE_iptables-mod-tee=y' >> .config
echo 'CONFIG_PACKAGE_chrony=y' >> .config
echo 'CONFIG_PACKAGE_bash=y' >> .config
echo 'CONFIG_PACKAGE_nano=y' >> .config
echo 'CONFIG_PACKAGE_strace=y' >> .config
echo 'CONFIG_PACKAGE_grep=y' >> .config


make download
make -j1 V=s


gunzip ./bin/targets/*/*/lede-*-combined-ext4.img.gz


if [[ $use_USB == 'n' ]]; then
exit 1
fi

cd ..
mkdir OpenC2X_Image
cd OpenC2X_Image


# get the tinycore package from pc engines
# wget https://www.pcengines.ch/file/apu_tinycore.tar.bz2

wget https://www.pcengines.ch/file/apu_tinycore.tar.bz2

# get the MBR image file mbr.bin from the syslinux source package at:
# wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-4.04.tar.bz2
# (the file is located in: syslinux-4.04/mbr/mbr.bin)
# move the mbr.bin into the OpenC2X_Image directory.

wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-4.04.tar.bz2
tar -xvjf syslinux-4.04.tar.bz2 --no-same-owner && cp syslinux-4.04/mbr/mbr.bin . && rm -rf syslinux-4.04 syslinux-4.04.tar.bz2

# partition and format
umount ${DEVICE}1
dd if=/dev/zero of=${DEVICE} count=1 conv=notrunc
echo -e "o\nn\np\n1\n\n\nw" | fdisk ${DEVICE}
mkfs.vfat -n XENIAL_APU -I ${DEVICE}1

# make the device bootable
syslinux -i ${DEVICE}1
dd conv=notrunc bs=440 count=1 if=./mbr.bin of=${DEVICE}
parted ${DEVICE} set 1 boot on

## unpack modified installers
mount ${DEVICE}1 /mnt
tar -C /mnt -xjf ./apu_tinycore.tar.bz2 --no-same-owner


cd ../OpenC2X-embedded
sudo cp ./bin/targets/*/*/lede-*-combined-ext4.img /mnt
sudo umount /mnt

