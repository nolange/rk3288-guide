### Stopgap: Writing an existing image to SD (Doesnt work right now)

``` {.bash}
# unpack the update image
rkunpack Firefly-RK3288_SDBoot_Ubuntu14.04_201503021436.img
# once more
rkunpack embedded-update.img
# now extract kernel and initrd from the boot partition
unmkbootimg --kernel vmlinuz --ramdisk initrd.img -i linux-boot.img 
```

You will end up with 3 files:

-   vmlinuz - the compressed kernel
-   initrd.img - the compressed initial ram disk
-   linux-rootfs.img - the "root" partition

Copy the kernel and initrd to the boot partition (\#2)

``` {.bash}
mkimage -n 'Ramdisk Image' -A arm -O linux -T ramdisk -C gzip -d initrd.img initramfs.uImage
# mount the hidden boot partition
mount /dev/sdg2 /mnt/
cp vmlinuz initrd.img /mnt/

cat > /mnt/boot.scr <<EOF
# run bootcmd_mmc0 for testing this
fatload ${devtype} ${devnum}:${distro_bootpart} ${kernel_addr_r} vmlinuz
fatload ${devtype} ${devnum}:${distro_bootpart} ${ramdisk_addr_r} initramfs.uImage
fatload ${devtype} ${devnum}:${distro_bootpart} ${fdt_addr_r} ${soc}-${board}${boardver}.dtb

setenv bootargs "console=tty0 console=ttyS2 earlyprintk root=/dev/mmcblk0p2 rw rootfstype=ext2"

if fdt addr ${fdt_addr_r}; then bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r};else bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdtcontroladdr};fi
EOF
```

Copy the root filesystem to the root partition (\#3):

``` {.bash}
# mount the filesystem - needs root rights
mount -o loop,ro linux-rootfs.img /mnt/
# mount sd partition... TODO
cp -r -p -a /mnt/. /media/xxxxx/
sync
```

### Creating a Debian installation

### Checking for valid u-boot????

The current scheme from the u-boot spl has a list of devices for reading
the full u-boot. There are\`nt any checks whether the devices actually
contain an u-boot, means it might just load random garbage. some header
detection magic or checksums would be neat

https://git.busybox.net/buildroot/tree/board/firefly/firefly-rk3288
