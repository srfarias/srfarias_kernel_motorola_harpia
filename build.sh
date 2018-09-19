#!/bin/bash

KDIR=$PWD
SRKDIR=~/srfariaskmau
TCDIR=~/arm-eabi-5.3/bin/arm-eabi-
DATE=$(date +"%m%d%y")
KNAME="SrfariasKernel"

export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=$TCDIR
export LD_LIBRARY_PATH="/usr/local/lib"
sudo ldconfig
export USE_CCACHE=1
export DEVICE="harpia"
export KBUILD_BUILD_USER="srfarias"
export KBUILD_BUILD_HOST="mau"
export FINAL_ZIP="$KNAME"-"$DEVICE"_"$DATE".zip

# Sanity check to avoid using erroneous binaries
rm -f arch/arm/boot/dts/*.dtb
rm -f arch/arm/boot/dt.img
make clean && make mrproper

echo "==> Making kernel binary..."
make harpia_defconfig
make -j3 zImage |& tee -a fail.log
if [ ${PIPESTATUS[0]} -ne 0 ] ; then
	echo "!!! Kernel compilation failed, can't continue !!!"
	exit 2
fi

echo "=> Making DTBs..."
make -j3 dtimage|& tee -a fail.log

echo "=> Making modules..."
make -j3 modules |& tee -a fail.log
if [ ${PIPESTATUS[0]} -ne 0 ] ; then
	echo "Module compilation failed, can't continue."
	exit 1
fi
rm -rf srfarias_install
mkdir -p srfarias_install
make -j3 modules_install INSTALL_MOD_PATH=srfarias_install INSTALL_MOD_STRIP=1 |& tee -a fail.log
if [ ${PIPESTATUS[0]} -ne 0 ] ; then
	echo "Module installation failed, can't continue."
	exit 1
fi

echo "==> Kernel compilation completed"

echo "==> Making Flashable zip"

echo "=> Finding modules"

find srfarias_install/ -name '*.ko' -type f -exec cp '{}' "$SRKDIR/system/lib/modules/" \;

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