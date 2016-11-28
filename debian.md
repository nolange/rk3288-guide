Create a debian installation
============================

Create the filesystem on your PC - debootstrap method
=====================================================

Prerequisites
-------------

-   root access on you host system (just for completeness)

-   *debootstrap*: this tool can setup a minimal debian system without
    using a existing paketmanager for the target.

-   *qemu*: *debootstrap* can finish the first step for a clean new
    system, further setup is required from this system. So far this
    requires running on the target - or via qemu on an emulated target

In case you are running on debian jessie, install debootstrap from the
backports (requires [setting this repo
up](https://backports.debian.org/Instructions))

``` {.bash}
apt-get install -t jessie-backports debootstrap
```

``` {.bash}
apt-get install binfmt-support qemu qemu-user-static debootstrap
```

Verify that debootstrap is version 1.0.72 or higher

see Debians [QEMU/debootstrap
approach](https://wiki.debian.org/EmDebian/CrossDebootstrap#QEMU.2Fdebootstrap_approach)

Creating the root fs (first step, host only)
--------------------------------------------

``` {.bash}
debootstrap --foreign --arch armhf stretch arm-stretch http://httpredir.debian.org/debian/
```

Some important notes:

-   if you now (or later) get a message similar to
    `systemd-sysv pre-depends on systemd`, then your debootstrap version
    is too old. A fitting one should be available from jessie-backports
    or onwards from stretch

-   if you get `/dev/null: Permission denied` or similar errors, this
    would mean the filesystem your new root resides on, is not mounted
    with dev permission (or explicitely with nodev). Find a fitting
    partition, and/or remout it with
    `mount -o remount,rw,exec,dev /srv/chroot/wheezy`

Finishing the installation
--------------------------

Prepare the quemu stub

``` {.bash}
cp /usr/bin/qemu-arm-static arm-stretch/usr/bin
```

``` {.bash}
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot arm-stretch /debootstrap/debootstrap --second-stage
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot arm-stretch dpkg --configure -a
```

Something that tends to break easily when moving the installation
around, are the sticky and setuid bits. You won\`t immediatly realise
they are missing either, but some strange issues will creep up later.
Its a good idea to list the special permissions and keep them together
with the fileystem.

``` {.bash}
find arm-stretch -perm /6000 -exec stat -c "%a %n" {} \; | sort > arm-stretch.perms
```

Further installations
---------------------

Right now, you could easily chroot into your new OS, install further
packages or make modifications. This is likely alot faster than doing it
on the hardware.

``` {.bash}
chroot arm-stretch

# install a desktop environment
tasksel

apt-get install....

# If you are using this as a clean template, remove all temporary stuff
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

exit
```

Packing up
----------

Finally, tar everything up. I prefer using archives instead of using cp,
it also serves as clean snapshot for later installations

``` {.bash}
tar cJf arm-stretch.tar.xz --numeric-owner -Xqemu-arm-static arm-stretch arm-stretch.perms
```

Writing the filesystem to disk
------------------------------

First, we would like to clean the partition, best to format it. I chosen
ext4 without journaling, which is functional similar to ext2 but faster.
Also the Journal can be easily reenabled at a later time. During setup I
dont consider a journal essential.

``` {.bash}
mkfs.ext4 -O ^has_journal /dev/sdf3
```

Next, note the UUID from the partition

``` {.bash}
blkid /dev/sdf3
```

Now, setup the partition by unpacking the archive on top of it.

``` {.bash}
tar -xf arm-stretch.tar.xz --strip-components=1 -C<path_to_mounted_partiton>

# Last sanity check
find <path_to_mounted_partiton> -perm /6000 -exec stat -c "%a %n" {} \; | sort
```

This almost concludes the setup, a few default configurations need to be
changed, most importantly the root password and mounting the root
filesystem.

Also debootstrap will copy some network settings from the host, to gain
internet access. This might be necessary to be corrected.

-   Changing the root password requires chrooting into the new System
    (TODO: move this to the installation part, requires quemu again..)

    ``` {.bash}
    chroot <path_to_mounted_partiton>
    passwd
    ```

-   Mounting the root filesystem is ideally done by UUID

    ``` {.bash}
    echo > <path_to_mounted_partiton>/etc/fstab \
      "UUID=3239e943-0463-4259-88fd-9bea4935b81c /               ext4    errors=remount-ro 0       1"
    ```

-   Change */etc/hostname*

-   Change */etc/resolv.conf*

-   Setup */etc/network/interfaces*


