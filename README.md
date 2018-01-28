# chroot-extra
This is a small scripts aimed at automating a chroot environnement.<br />
Based on <a href="https://git.archlinux.org/arch-install-scripts.git/" title="ArchLinux - arch-install-scripts">arch-chroot</a>

# Usage
First you have to give execute permission to chroot-extra :<br />
chmod +x chroot-extra/chroot-extra
Or directly install :
\# install /path/to/chroot-extra /usr/bin/

And assume your system is mounted on /mnt, as superuser, do  <br />
\# chroot-extra/chroot-extra /mnt/
Or if you had installed on the system, do 
\# chroot-extra /mnt/
