#!/bin/bash

# BEGIN Messages
msg_info() { 
	local txt saut="\n";
	[[ "$1" == "-n" ]] && saut="" && shift; 
	txt="$1"; 
	shift; 
	printf " $(date +%H:%M:%S) [ INFO  ] $txt$saut" "$@"; 
}

msg_error() { 
	local txt=$1; 
	shift; 
	printf " $(date +%H:%M:%S) [ ERROR ] $txt\n" "$@"; 
}

die() {
	msg_error "$@" 
	exit 1
}
# END Messages

# BEGIN CHROOT UTILS ( from arch-chroot ) 
ignore_error() {
  "$@" 2>/dev/null
  return 0
}

chroot_add_mount() {
  mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_maybe_add_mount() {
  local cond=$1; shift
  if eval "$cond"; then
    chroot_add_mount "$@"
  fi
}

chroot_not_arch() {
#	TMP_ROOT=Arch Boostrap
	TMP_ROOT=$1
#	NEW_ROOT=$RACINE
	NEW_ROOT=$2
	[ "${NEW_ROOT:${#NEW_ROOT}-1}" == "/" ] && NEW_ROOT="${NEW_ROOT:0:${#NEW_ROOT}-1}"
	chroot_maybe_add_mount "! mountpoint -q '$TMP_ROOT/install.arch'" "$NEW_ROOT" "$TMP_ROOT/install.arch" -t none -o bind &&
	chroot_setup_others
}

init_chroot() {
	CHROOT_ACTIVE_MOUNTS=()		
	chroot_maybe_add_mount "! mountpoint -q '$1'" "$1" "$1" --bind 
	mount_setup "$1"
}

mount_setup() {
	[[ -z $CHROOT_ACTIVE_MOUNTS ]] && CHROOT_ACTIVE_MOUNTS=()
	
	if [[ ! $testtrap ]]; then
		[[ $(trap -p EXIT) ]] && printf "\033[01;31m==> ERROR:\033[m (BUG): attempting to overwrite existing EXIT trap\n" >&2 && exit 1
# 		die "$_bug_chroot"
		trap 'chroot_teardown' EXIT
		testtrap=1
	fi
# 	printf "\033[01;31m==> ERREUR:\033[m (BUG): attempting to overwrite existing EXIT trap\n" >&2 && exit 1
	chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
	chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
	ignore_error chroot_maybe_add_mount "[[ -d '$1/sys/firmware/efi/efivars' ]]" \
		efivarfs "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
	chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
	chroot_add_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
# 	echo "Montage SHM" &&
	chroot_add_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
	ignore_error chroot_maybe_add_mount "[[ -d '$1/run/shm' ]]" \
		shm "$1/run/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
	chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
# 	echo "Montage SHM fin" 
# 	[[ ! -e $1/run/shm ]] && mkdir -p $1/run/shm &&
# 	chroot_add_mount shm "$1/run/shm" -t tmpfs -o mode=1777,nosuid,nodev 
}

chroot_teardown() {
  [ "$CHROOT_ACTIVE_MOUNTS" != "" ] && umount "${CHROOT_ACTIVE_MOUNTS[@]}"
  unset CHROOT_ACTIVE_MOUNTS
  [ "$1" == "reset" ] && CHROOT_ACTIVE_MOUNTS=() 
}

chroot_add_resolv_conf() {
  local chrootdir=$1 resolv_conf=$1/etc/resolv.conf

  # Handle resolv.conf as a symlink to somewhere else.
  if [[ -L $chrootdir/etc/resolv.conf ]]; then
    # readlink(1) should always give us *something* since we know at this point
    # it's a symlink. For simplicity, ignore the case of nested symlinks.
    resolv_conf=$(readlink "$chrootdir/etc/resolv.conf")
    if [[ $resolv_conf = /* ]]; then
      resolv_conf=$chrootdir$resolv_conf
    else
      resolv_conf=$chrootdir/etc/$resolv_conf
    fi

    # ensure file exists to bind mount over
    if [[ ! -f $resolv_conf ]]; then
      install -Dm644 /dev/null "$resolv_conf" || return 1
    fi
  fi

  chroot_add_mount /etc/resolv.conf "$resolv_conf" --bind
}

chroot_new_root () {
	msg "$_chroot_newroot_msg" "$NAME_MACHINE"
	arch_chroot "$RACINE" "/bin/bash"
}

#ADAPTED FROM AIS
# chroot into new root
arch_chroot () {
# 	local ROOT_CHROOT="$( [ "$2" != "" ] && echo $2 || echo $RACINE )"
# 	$exe chroot $ROOT_CHROOT ${1}
	local ROOT_CHROOT="$1"
	[[ ! -e $ROOT_CHROOT ]] && [[ ! -z "$RACINE" ]] && ROOT_CHROOT="$RACINE" || shift
	chroot $ROOT_CHROOT ${@}
	return $?
}

#
# Other function to execute more complexs commands in chroot using "EOF"
#
#lix_chroot () {
#	local root=$1; shift
#	chroot $root /bin/bash <<EOF
#		${@}
#EOF
#	[[ ! -z $FILE_COMMANDS ]] && echo "${@}" >> $FILE_COMMANDS
#}

declare -A to_mount

[[ -z "$1" ]] && die "No directory specified !"
# On vérifie que ce n'est pas "/" puis qu'on est bien sur un système...
if [[ -e "$1" ]] && [[ "$1" != "/" ]]; then
	if [[ -e "$1/bin" ]] && [[ -e "$1/dev" ]] && [[ -e "$1/proc" ]] && [[ -e "$1/sys" ]] && [[ -e "$1/run" ]] && [[ -e "$1/tmp" ]]; then 
		[[ -d $1/bin ]] && PATH=$PATH:/bin:/sbin:/usr/sbin
		msg_info -n "Setup chroot to \"$1\"\r"
		init_chroot "$1" || die "Failed to setup chroot in /"
		msg_info "Setup chroot to \"$1\"...ok"
		msg_info "Chrooting to \"$1\""
		chroot "$1"
	else
		die "Unable to find a valid system in \"$1\"!"
	fi
else
	die "\"$1\" is not valid directory !"
fi


# END
