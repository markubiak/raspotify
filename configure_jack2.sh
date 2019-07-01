#! /bin/bash

OPTFLAGS='-mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard'
OPTFLAGS='-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits'
export LINKFLAGS='-std=gnu++11 -lstdc++'
export CFLAGS="-Wall $OPTFLAGS"
export CXXFLAGS="-Wall $OPTFLAGS"
export CC=arm-linux-gnueabihf-gcc
export CXX=arm-linux-gnueabihf-g++
./waf configure --prefix=/toolchain/rpi-tools/arm-bcm2708/arm-bcm2708hardfp-linux-gnueabi/arm-bcm2708hardfp-linux-gnueabi/sysroot
