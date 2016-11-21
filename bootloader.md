Overview
========

This guide is a work in progress to document the steps necessary to get
a recent debian, kernel and u-boot working on the Firefly-Rk3288. It
encompasses some notes made over a year, and I will try to expand the
points given some time

Rockchip propietry loader
-------------------------

Confusingly enough its open-source and based on (a quite old version) of
u-boot.

General Influences on this guide
--------------------------------

The primary goal is to depend as little as possibly on *custom
behaviour*, and instead focus on using mainline kernel and bootloader.
The directions are further guided on the broad decissions of the
community, for example by using a common partitioning scheme.

Overall Targets
---------------

-   \[x\] Use mainline u-boot with tftp functionality

-   \[ \] Have u-boot installed on eMMC to work without SD-Card.
    (Mostly done)

-   \[x\] Setup a SD-Card to be usable from a normal PC

-   \[ \] Patch a kernel with a few necessary patches (USB-Fix,
    Mali DRM). (Need to redo this and make patches this time)

-   \[ \] Setup debian stretch with that custom kernel
    (commandline only). (Need to redo this)

-   \[ \] Allow boot from the SD-Card without changing u-boots
    default options. (Use u-boot scripts ore pxelinux?)

-   \[ \] Get an X-Server with Mali Userspace

-   \[ \] Setup a debian stretch installation with the normal
    distro-kernel, compile additional modules (mali) with DKMS.

    Means possibility to just apt-get upgrade, kernel modules will
    automatically be recompiled. This means using DKMS and some hooks to
    generate a RAMdisk and update the bootscripts

-   \[ \] EFI Boot?

Some thing that will **not work** afterwards:

-   The Android image has some expectations about the layout and
    the bootloader. The available images wont work anymore, as soon as
    you remove either of those.

    **This guide assumes you don\`t want to run Android**

-   Features from Rockchips propietary loader - no recovery (loader)
    mode. Probably no fastboot.

    Several Tools wont work afterwards

Tools and details
-----------------

The information on the Rk3288 is spread over the web.

### Recovery Mode

The Friefly has a switch to boot into a special Recovery mode, this is a
feature of the Rockchip bootloader.

### Maskrom Mode

Maskrom mode can be entered by connecting two points before powering on.
This should allow repairing the eMMC if the device cant boot anymore.
Unfortunatly *rkflashtool* \* is unable to read/write flash in this mode
and rockchips own *update-tool* did not work at all.

What I havent seen documented, but seems to be a feature: **Maskrom mode
will boot from SD-Card first**

\* Quite possibly I just picked one of the many out-dated forks

**Recommendations:**

-   Prepare an emergency SD-Card with U-Boot and Linux first. When the
    eMMC Bootloader is bricked, you can enter Maskrom and boot from this
    SD-Card, then delete the first MB from the eMMC

-   Zero out the eMMC to kill the Loader and always boot from SD, until
    you are confident enough to write to the eMMC

SD-Card: Mainline u-boot and mainline Linux
-------------------------------------------

### Preparation: Bootloader from SD-Card

To get the bootrom to load from SD-Card, two paths can be taken:

-   Keep the propietary loader, and change to linux mode, either by
    choosing it from within android or by manually deleting the
    "misc" partition.

    This allows keeping the Android installation alive

    TODO: Test if this really works, I dont have a propietary loader
    installed anymore

-   Delete the propietary loader. Either from rkflashtools or linux.

    dd if=/dev/zero of=/dev/mmcblk0 bs=1M. (README.rockchip from u-boot)
    dd if=/dev/zero of=/dev/mmcblk2 bs=1M. (on my system)

    TODO: which is correct on a new system?

### Setting up a SD card for linux

The bootrom expects the loader at a fixed address of 32KB, and has a
severe size-limit of 32KB. u-boot solves this by creating a fairly
minimal loader, which loads the full u-boot (which, as far as I know
could theoretically boot without help).

The Environment Variables are stored on mmc aswell, which is typically
fine with sd-cards, the onboard MMC has however a 512KB Blocksize for
Erases. Should the same u-boot be able to run and write into eMMC one
day, the environment would have to be moved to a better place, like in
the block from 2-4MB (should therefore allow blocksizes up to 2MB)

  -------- -------------------------
  32K      u-boot spl
  96K      u-boot env \*
  128K     u-boot
  16M      boot (bootable flag)
  128MB+   filesystem partition(s)
  -------- -------------------------

\* (likely better to be moved to 3M - (env size), because of emmc erase
block size)

To ensure easy handling of the final SD-Card, partitions should be
created to mask these areas in "reserved" space.

``` {.bash}
parted --script /dev/sdf \
    mklabel gpt \
    mkpart bootloader 0 16Mib \
    set 1 hidden on \
    mkpart boot fat32 16Mib 128Mib \
    set 2 boot on \
    mkpart rootfs ext2 128Mib 4Gib \
 

mkfs.fat  /dev/sdf2
mkfs.ext2 /dev/sdg3

parted --script /dev/sdf \
    unit s \
    p
```

This should result in output close to the below:

    Model:  FCR-HS3 -3 (scsi)
    Disk /dev/sdf: 15564800s
    Sector size (logical/physical): 512B/512B
    Partition Table: gpt
    Disk Flags: 

    Number  Start   End      Size     File system  Name        Flags
     1      34s     32767s   32734s                bootloader  hidden
     2      32768s  262143s  229376s               boot        boot, esp

(Note that partitions should be sufficiently aligned, \#1 is an
exception since it just reserves the space)

u-boot has some sensible defaults since 2016.11, those could be written
to the sd card (or MMC) via `gpt write mmc 0 \$partitions` I would still
recomment doing it manually

### Installing the bootloader

Setting up the u-boot on a SD-Card can happen the following way:

``` {.bash}
# https://github.com/nolange/u-boot/archive/ethernet_new.zip

CROSS_COMPILE=arm-linux-gnu-
SOURCEDIR=~/git/u-boot
TARGET="firefly-rk3288"
BUILDDIR=/tmp/uboot-out
make -C "$SOURCEDIR" CROSS_COMPILE=$CROSS_COMPILE "O=${BUILDDIR%/}"  ${TARGET}_config
make -C "$SOURCEDIR" CROSS_COMPILE=$CROSS_COMPILE "O=${BUILDDIR%/}"

$BUILDDIR/tools/mkimage -n rk3288 -T rksd -d $BUILDDIR/spl/u-boot-spl.bin $BUILDDIR/u-boot-spl.rksd


dd if=$BUILDDIR/u-boot-spl.rksd of=/dev/sdf seek=64
dd if=$BUILDDIR/u-boot-dtb.img of=/dev/sdf seek=256
```
