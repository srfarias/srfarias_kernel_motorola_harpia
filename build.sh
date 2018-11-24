#!/bin/bash

KDIR=$PWD
SRKDIR=~/srfariaskmau
TCDIR=~/arm-eabi-5.x/bin/arm-eabi-
DATE=$(date +"%d%m%y")
KNAME="SrfariasKernel"

export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=$TCDIR
export LD_LIBRARY_PATH="/usr/local/lib"
sudo ldconfig
export CONFIG_CCACHE=y
export DEVICE="harpia"
export KBUILD_BUILD_USER="srfarias"
export KBUILD_BUILD_HOST="mau"
export FINAL_ZIP="$KNAME"-"$DEVICE"_"$DATE".zip

# Sanity check to avoid using erroneous binaries
rm -f $SRKDIR/system/lib/modules/pronto/pronto_wlan.ko
rm -f $SRKDIR/tools/zImage
rm -f $SRKDIR/tools/dt.img
rm -f arch/arm/boot/dts/*.dtb
rm -f arch/arm/boot/dt.img
make clean && make mrproper

echo "==> Making kernel binary..."
make harpia_defconfig
make -j12 zImage |& tee -a fail.log

echo "=> Making DTBs..."
make -j12 dtimage

echo "==> Kernel compilation completed"

echo "==> Making Flashable zip"

cp  $KDIR/arch/$ARCH/boot/zImage $SRKDIR/tools/

cp $KDIR/arch/arm/boot/dt.img $SRKDIR/tools/

cd $SRKDIR

zip -r $FINAL_ZIP * -x .git README.md *placeholder > /dev/null

if [ -e $FINAL_ZIP ] ; then
	echo "==> Flashable zip created"
	echo "*** Enjoy your kernel! ***"
	exit 0
else
	echo "!!! Unexpected error. Abort !!!"
	exit 1
fi
