#!/bin/bash

	function mount_image {
		echo mounting image

		media_loop=$(losetup -f || true)

		if [ ! -d root ]; then
			mkdir root
		fi
		if [ ! -d boot ]; then
			mkdir boot
		fi

		if [ ! "${media_loop}" ] ; then
			echo "losetup -f failed"
			echo "Unmount some via: [sudo losetup -a]"
			echo "-----------------------------"
			losetup -a
			echo "sudo kpartx -d /dev/loopX ; sudo losetup -d /dev/loopX"
			echo "-----------------------------"
			exit
		fi

		losetup ${media_loop} $1

		kpartx -av ${media_loop}
		# If running inside Docker, make our nodes manually, because udev will not be working.
		if [[ -f /.dockerenv ]]; then
			dmsetup --noudevsync mknodes
		fi

		sleep 1
		sync
		test_loop=$(echo ${media_loop} | awk -F'/' '{print $3}')

		if [ -e /dev/mapper/${test_loop}p1 ] ; then
			export media_prefix="/dev/mapper/${test_loop}p"
			export ROOT_media=${media_prefix}1
		else
			ls -lh /dev/mapper/
			echo "There was an error mounting the image! Not sure what to do."
			exit 1
		fi
		mount $ROOT_media root

		echo Mounted ROOT partition at ${PWD#}/root
	}

function unmount_image {
	root_dir=${PWD#}/root

	[ -f $root_dir ] && mountpoint -q $root_dir && _umount 10 $root_dir

	# try to find the mapped dir
	mount | grep ./root | grep -o '/dev/mapper/loop.' | grep -o 'loop.' | uniq | while read -r line ; do

		kpartx -d /dev/$line
		losetup -d /dev/$line

	done

	# If running inside Docker, make our nodes manually, because udev will not be working.
	if [[ -f /.dockerenv ]]; then
		dmsetup remove_all
		losetup -D
		sudo dmsetup --noudevsync mknodes
	fi


}

function chroot_mount {
	root_dir=${PWD#}/root

	echo Mounting system directories from root: $root_dir
	mount --bind /dev/ $root_dir/dev/
	mount --bind /proc/ $root_dir/proc/
	mount --bind /sys/ $root_dir/sys/
	mount --bind /run/ $root_dir/run/
	mount --bind /etc/resolv.conf $root_dir/etc/resolv.conf
        mount devpts $root_dir/dev/pts -t devpts

}

function chroot_umount {
	echo Unmounting system directories
	root_dir=${PWD#}/root
	_umount 60 ${PWD#}/root

}
