#!/bin/bash
if [ -z $2 ] || [ -z $3 ]
then
 printf "\nUsage: \n\n\tbash build.sh [thread_amount] device_codename maintainer_username\n\n\tNOTE: '[thread_amount]' can be an integer or 'auto'.\n\n"
 exit 1
fi

# Shall the toolchain be merged and unpacked?

NEEDSWORK=false

# Functions

function clrln
{
  i=0
  COLUMNS=$(tput cols)
  printf '\r'
  while [ $i -lt $COLUMNS ]
  do
    printf ' '
    i=$(($i + 1))
  done
  printf '\r'
}

function fail
{
  clrln
  printf "\n\n\e[91m%s""$1""\n\n\e[91m\e[0m\n"
  exit 1
}

function ok
{
  clrln
  printf "\n\n\e[92m\e[1m === ""$1"" === \e[0m\n"
}

KERNEL_DIR=$PWD
TOOLCHAINDIR=$(pwd)/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_arm-linux-gnueabihf
DATE=$(date +"%d%m%Y")
export $(cat Makefile | head -3 | sed 's/ //g')
KERNEL_VERSION="$VERSION"".""$PATCHLEVEL"".""$SUBLEVEL"
KERNEL_NAME="Linux_v""$KERNEL_VERSION"

# Warn about cleaning the environment

if [ "$4" == clean ]
then
 printf "\n\e[91m\e[1mWARNING: \e[0m\e[91myour build environment will be cleaned after getting the toolchain ready, this is your last opportunity to hit CTRL+C if you don't want to.\e[0m\n\n"
fi

# Merge the toolchain parts, unpack it and remove compressed files.

printf '\n\e[93m=> Preparing toolchain\e[0m\n'
if [ $NEEDSWORK == 'true' ]
then
 cd $TOOLCHAINDIR
 printf '\n\e[5m- Joining files...\e[0m'
 cat arm-linux-gnueabi.tar.xz.part* > arm-linux-gnueabi.tar.xz
 clrln
 printf '\e[92m+ Joining files\e[0m'
 printf '\n\e[5m- Unpacking files...\e[0m'
 tar xf 'arm-linux-gnueabi.tar.xz' || fail 'Unable to prepare the toolchain, please check the errors above.'
 clrln
 printf '\e[92m+ Unpacking files...\e[0m'
else
 printf '\e[92m+ Nothing to do.\e[0m'
fi

cd $KERNEL_DIR

export ARCH=arm
# export KBUILD_BUILD_HOST="SEND_NUDES__PLEASE"
export CROSS_COMPILE=$TOOLCHAINDIR/bin/arm-linux-gnueabihf-
export USE_CCACHE=1
export DEVICE="$2"
export KBUILD_BUILD_USER="$3"
Anykernel_DIR=$KERNEL_DIR/Anykernel2/$DEVICE
mkdir -p $Anykernel_DIR
# VER="-v70"
export FINAL_ZIP="$KERNEL_NAME"-"$DEVICE"-"$DATE"".zip"
if [ "$1" == 'auto' ]
then
 t=$(nproc --all)
else
 t=$1
fi
# Clean if 4th parameter is 'clean'
if [ "$4" == 'clean' ]
then
 make -j$t clean
fi
GCCV=$("$CROSS_COMPILE"gcc -v 2>&1 | tail -1 | cut -d ' ' -f 3)
printf "\n\n\e[1mTHREADS: \e[0m$t\n\e[1mDEVICE: \e[0m$2\n\e[1mMAINTAINER: \e[0m$3\n\e[1mGCC VERSION: \e[0m$GCCV\n\e[1mVERSION: \e[0m""$KERNEL_VERSION""\n\n"
echo "=> Making kernel binary..."
if [ -f "arch/$ARCH/configs/""$2""_defconfig" ]
then
 make $2_defconfig
else
 fail "Device codename $2 requested, but no configuration file has been found."
fi
make -j$t zImage || fail "Kernel compilation failed, can't continue."
echo "=> Making modules..."
make -j$t modules || fail "Module compilation failed, can't continue."
make -j$t modules_install INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 || fail "Module installation failed, can't continue."
mkdir -p "$Anykernel_DIR/modules/system/lib/modules/pronto"
find modules/ -name '*.ko' -type f -exec cp '{}' "$Anykernel_DIR/modules/system/lib/modules/" \;
cp "$Anykernel_DIR/modules/system/lib/modules/wlan.ko" "$Anykernel_DIR/modules/system/lib/modules/pronto/pronto_wlan.ko"

ok 'Kernel compilation completed'

cp $KERNEL_DIR/arch/arm/boot/zImage $Anykernel_DIR

cd $Anykernel_DIR

printf '\n=> Making flashable zip\n'

echo '  => Generating changelog'

if [ -e $Anykernel_DIR/changelog.txt ]
then
 rm $Anykernel_DIR/changelog.txt
fi

git log --graph --pretty=format:'%s' --abbrev-commit -n 200  > changelog.txt

echo "  - Changelog generated"

zip -r9 $FINAL_ZIP * -x *.zip $FINAL_ZIP > /dev/null

ok 'Flashable zip created'
printf "\n\e[1mRESULT: \e[0m%s""$Anykernel_DIR/$FINAL_ZIP\n"
exit 0
