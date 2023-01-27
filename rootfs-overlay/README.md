# rasp-pi-min-ro-build

Kevin Boone, May 2021

This is a collection of shell and Perl scripts that build a minimal-ish,
read-only installation of Linux on an SD card, ready for use in a Raspberry Pi.
It should work with any Pi, but I've mostly tested with the 3B+. By 'minimal' I
don't mean the amount of storage -- even an SD card that costs only a few
pennies has way more storage than is required. Rather, I mean the number of
processes and services that are started. I'm aiming for a boot time of only a
few seconds, measured from the time the kernel starts. It goes without saying
that all the auto-configuration stuff in a desktop Linux (`systemd`, `udev`,
`dbus`, etc) would be completely inappropriate here.

This is not a complete Linux and it certainly isn't a Linux distribution -- it
is intended as a base for customization.  The intended application is for
embedded systems, or terminals for other equipment. You'll need to add
configuration for most external devices that you plan to connect, as well as
deciding in advance what software packages to install. If you just what a
light(-ish) conventional desktop Linux for the Pi, I can recommend DietPi and
Alpine.

The Linux installation built by `rasp-pi-min-ro-build` boots to a shell prompt.
It can be configured to auto-login a user. Only one user is created by default
-- user `test` with password `test` (but this can be changed).

The build process can generate configuration for Wifi networking, but only with
fixed configuration parameters that are specified in advance.  There are also
options to enable ALSA audio and USB storage.

By design, the system is completely read-only at run-time.  The root filesystem
is mounted read-only, and never made writable. There is therefore no shut-down
process -- it is designed so that it's completely safe just to power-off when
you're done. Of course, this means that all configuration must be done by
hacking on these files, and then building a new image on SD card. There is
intentionally no way to modify any configuration at run-time.

`rasp-pi-min-ro-build` is a specific implementation of the general technique
for implementing a minimal, read-only Linux that I describe on my website:

https://kevinboone.me/pi\_minimal.html

## Read-only Linux on the Pi

Why would you want a read-only Linux, anyway? For embedded and kiosk
applications, users won't follow a shut-down procedure -- it might not even be
possible to. By making the entire installation read-only, this problem is
completely removed. Since nothing is writeable, nothing can be left in a broken
state if the user just pulls the plug. Moreover, there is no fault that a user
can create -- that doesn't involve physical trauma -- that can't be fixed by
rebooting.

Raspbian and similar distributions are not at all designed to run in a
read-only environment. In fact, it takes a lot of effort to make read-only
operation possible with any modern Linux.  Most obviously, there has to be a
`/tmp` directory that can hold temporary files. Many utilities expect to be
able to write to `/var`, `/run` and other places. My approach is to defined
`/tmp` to be in in-memory filesystem using `tmpfs`; all other directories that
have to be writable are symbolic links to directories under `/tmp`. Utilities
that change configuration at runtime -- such as <code>dhcpcd</code> when it
configures a network interface -- have to be provided with ways to overwrite
configuration files (like <code>/etc/resolv.conf</code>) that are on a
read-only filesystem. Again, symlinks come to our rescue here. Still, the
set-up is a little fiddly.

## Living without auto-configuration

To get the fastest possible boot to a working (console) interface,
<i>nothing</i> is auto-configured, beyond the facilities provided by the
kernel. There's no <code>udev</code>, no <code>avahi</code>, etc.  The
installation script knows what needs to be done for common peripherals like USB
storage. However, for anything complicated you'll need (as a minimum) to
specify what kernel modules need to be loaded.  There's no easy way to figure
this out, except by looking on a conventional Raspberry Pi desktop system, to
see what modules are actually loaded when particular peripherals are plugged
in.

This is not a defect -- it is a feature. Auto-configuration is great for
desktop systems, but is completely inappropriate in an embedded or
single-purpose installation.

## Networking 

If networking is enabled in the configuration file, the build will include
networking utilities, and scripts to configure the network adapters using DHCP.
For Wifi networking, the configuration will need to include the details of the
access point and a password, if used. Enabling networking also enables the SSHD
server for remote login. Even if auto-login is enabled for the console, the
SSHD server expects a password. Starting a Wifi network can take a little
while, but this doesn't delay getting to a shell prompt, as it happens later.

The Raspberry Pi has no real-time clock. If networking is enabled, the time is
set using a simple script that gets its from one of Google's webservers. This
isn't a very robust approach, but it works for simple applications.

There's no point providing any way for the user to select network
configuration, because it won't be remembered. 

## Boot process

The Linux start-up process uses <code>init</code>. Most of the initialization
is done in a single script <code>/etc/rc.d/startup.sh</code>. There is no
meaningful notion of "run level" here -- technically everything operates at run
level 1. So <code>init</code> will run subsidiary start-up scripts in
<code>/etc/rc1.d</code>, in alphanumeric order. Of course you can add new
scripts for additional configuration. As in a conventional (pre-systemd) Linux,
the scripts in <code>/etc/rc1.d</code> are actually symlinks to scripts in
<code>/etc/init.d</code>. The links have conventional names of the form
<code>SNNsomething</code>, where the NN is a two-digit number indicating the
start order. There are no corresponding <code>Kxxsomething</code> scripts for
shutting down, because shutting down amounts to powering off. 

The scripts in <code>/etc/init.d</code> are always included in the build; if a
feature is enabled in <code>CONFIG.sh</code> that usually means that the
corresponding symlink to <code>/etc/rc1.d</code> gets created. Otherwise there
is no symlink, and the script will not be run.

## Console appearance and keyboard layout

This software is designed to generate a Linux installation that will be used
with console tools, if it even has a user interface at all.  Consequently, I've
included tools to set the appearance and size of the console font. The console
configuration file is <code>rootfs-overlay/etc/default/console-setup</code>.
You could also just invoke <code>setfont</code>  with a font file in
<code>/usr/share/consolefonts</code>.  

By default no keyboard configuration is done. The <code>loadkeys</code> utility
(e.g., <code>loadkeys uk</code>) could be inovked to set a keyboard layout.

## USB storage

If ENABLE\_STORAGE=1 in `CONFIG.sh`, the boot process will include
<code>/etc/rc1.d/S05storage</code>, which is a symlink to
<code>/etc/init.d/storage</code>. This script mounts a single USB storage
device on <code>/mnt</code>. The block device is hard-coded as
<code>/dev/sda</code>, which is appropriate for a non-partitioned USB stick,
with any filesystem. If the memory stick is partitioned, you'll probably need
to change this to <code>/dev/sda1</code>. It doesn't matter what kind of
filesystem is on the memory stick (provided it's supported by the kernel).
However, if it <i>isn't</i> VFAT, you'll need to think about the file ownership
on the filesystem. If it <i>is</i> VFAT, the use of the <code>user</code>
option in the mount will make the files appear to be owned by the console user,
which is very convenient -- unless you want the external storage to be
read-only also.

The default set-up uses the <code>sync</code> option in the mount, so that
there's less chance that this storage will be corrupted when powering off. Of
course, this makes storage writes less responsive.

The hard-coding of the block device means that there's no realistic possibility
of using multiple storage devices. You'd need a device management framework for
that, with <code>udev</code> and <code>dbus</code> and all that stuff, which is
exactly what I'm trying to avoid.

No harm will come from enabling storage support when there is no storage device
-- you'll just get an error message at boot time that probably won't be
visible. 

## Audio

If `ENABLE_AUDIO=1` in `CONFIG.sh`, the build will include basic 
ALSA utilities. More importantly, though, it will load the kernel's
audio drivers, and set the permissions appropriately on
<code>/dev/snd</code>. A few sample sounds are included in
<code>/usr/share/sounds</code>.

If you're using an HDMI monitor then most likely HDMI audio
will be ALSA device 0, and the audio jack will be device 1. So
to play audio through the jack, you could test with

    aplay -D hw:1 ...

To get a list of known audio devices, do `aplay -L`.

The basic build does not include any particular audio players apart
from basic ASLA utilities. If you want anything else, you can add
the package(s) to `OPTIONAL_PKGS` in `CONFIG.sh`.

## Official touch-screen support

There's nothing special to do to enable the display part of the Pi 
official touch-screen -- support is built into firmware. However, to enable 
the touch sensitivity and the backlight control, you'll need to enable
kernel modules `rpi-ft5406` and `rpi_backlight` respectively. You can
just add these to `OPTIONAL_MODULES` (see below). For the record, 
the backlight brightness is set in the range 0-255 by writing 
`/sys/class/backlight/rpi_backlight/brightness`. 

## Optional kernel modules

There is no device detection -- any kernel modules you'll need will have
to be installed at boot time. There is a setting `OPTIONAL_MODULES` for
this. Modules specified here are loaded very early in the boot process 
-- before showin a prompt. So if you're using modules that are slow to
load, or might even fail to load, it would be better to create an additional
script under <code>rc1.d</code> and do the load there.

## Bluetooth and serial UART

The default installation disables Bluetooth, and configures the serial
UART (pins 8 and 10) as device `/dev/ttyAMA0`. You could, in principle,
use this UART as the console, but I've assumed it's more likely to be
used to connect another device. The boot process adds permissions
for AMA0 to the default user. To restore the default functionality,
remove the `dtoverlay=pi3-disable-bt` line from `config.txt`. Of course,
you'll need to install all the Bluetooth software if you actually
want to use BT. Disabling it shaves about 0.4 seconds off the boot time.

## How to build 

Here is the basic procedure to build with default configuration.

- Edit `CONFIG.sh` to determine what is to be installed, and any other
  settings that need to be edited.

- Insert an SD card, or a card reader with an SD card, into the workstation.
  The card must be at least 1Gb, but larger is no problem -- all available
  space will be used. This must be an SD card that you don't mind being
  wiped.

- Check using, for example, `dmesg`, what is the `/dev` device that represents
  the SD card, e.g., `/dev/sdb`. There may also be `/dev` entries for
  specific partitions -- ignore these.

- Run `prepare-card.sh` as root. This will create two partitions on the
  card, and put a new FAT filesystem on the first, and an ext4 filesystem
  on the second. The first partition will contain the Pi boot firmware
  and kernel; the second will contain the root filesystem.

- Run `build.sh` as an unprivileged user. This will download all the 
  packages, and populate local copies of the root filesystem and boot
  partition. 

- Run `copy-to-card.sh` as root. This will copy the local versions of
  the root and boot partitions to the card, and set the appropriate
  ownership and permissions.

- If you want to clean up all intermediate files, run `./cleanall.sh`.

Note that a full build, with nothing cached, will take about 15 minutes.
Most of that time will be spent downloading from repositories, but
populating the SD card is also fairly time-consuming.

## The build process

Here is what <code>build.sh</code> does.

1. Downloads the latest Pi firmware/kernel bundle, and unpacks it 
into a directory that will become the boot partition of the SD card.

2. Merges into the boot directory the content of the <code>bootfiles/<code>
directory. This is the place to set specific firmware and kernel 
parameters.

3. Downloads all the packages that are needed according to the configured
options, along with all their dependencies. These all go into a directory
that will become the root filesystem on the SD card. 

4. Merges with this directory the contents of <code>contrib-binaries</code>.

5. Merges the contents of <code>overlay-rootfs</code>, substituting
placeholders in some configuration files for values in <code>CONFIG.sh</code>.

6. Copies <code>CONFIG.sh</code> itself into the generated <code>/etc</code>
directory, where it will be read at runtime by a number of scripts.
 
## Repository contents

`contrib-binaries/` -- this directory contains pre-compiled binaries of
utilities that are not available in the Raspbian repository -- probably
because I wrote them. For example, this build uses a minimal version of
`syslogd` that is designed for use with  a temporary logfile in memory.
(see https://github.com/kevinboone/syslogd-lite for more information).
This directory is structured as it will appear in the root filesystem.

`rootfs-overlay/` -- files that will overwrite versions that are downloaded
from repositories. These files contain configuration specific for this
build. Some files might need to be edited, but it's difficult to
document every conceivable change. 

`bootfiles/` -- additional files that will be copied to the boot partition of the
card (e.g., cmdline.txt). The defaults should work, but it's not unusual to
have to change these files to, for example, enable specific features in
firmware. These are standard Raspberry Pi files that are well documented.

`misc-config` -- various configuration files that could not be placed
in `rootfs-overlay` because their target directories are generated
during the build.

## Settings file CONFIG.sh

This file is used during the image build process, and is also copied to
the build, into the `/etc`/ directory, where its settings are used
at run-time. I hope that the copious comments in this file make it reasonably
clear what the various settings do. 

## X support

It is possible, but probably not advisable, to run a graphical X session in a
Linux installation like this. If you set `INSTALL_X=1` in `CONFIG.sh`, the
installer will download and install a minimal set of software to run X. It is
at this point, however, that we realize how much `udev` and `dbus` do for us in
a regular, desktop Linux -- here we have to hack on the X11 configuration file
manually to add all the input devices and screen settings. It's a bit like
being back in the 90s.  The sample file at `rootfs-overlay/etc/X11/X.conf`
should work for a system with a single USB keyboard, a single USB mouse, and a
single monitor. However, I can't promise that it works in any set-up but my
own.

To start an X session run `sudo /usr/bin/startx.sh`. This will start the X
server, a single terminal session, and the Matchbox window manager. The X
server needs to run as root because it's a pain to change all the permissions
of all the devices it uses. However, it starts the window manager and terminal
as the unprivileged user.

This installation is at best a starting point for running an X-based
installation, and will need radical customization for anything practical.  Once
we start running X, the benefits of using a minimal, read-only distribution
like this, start to become less significant.


