# rasp-pi-min-console-build

Version 0.0.2
Kevin Boone, February 2023

## What is this?

This is a collection of shell and Perl scripts that build a minimal-ish,
read-only installation of Linux on an SD card, ready for use in a Raspberry Pi.
It's mostly been tested on the Pi 3B+ -- my favourite Pi -- but it should
work on later models.

This system is designed to form the basis of a _console-only_ Pi Linux
installation whose main design goal is instant-on, instant-off operation.
Because the root filesystem is read-only, there is no shut-down procedure --
just power off. On a Pi 3B+ with no tweaks or overclocking, it takes nine
seconds from power-on to a workable command prompt. A secondary, related design
goal is that nothing that a user does at runtime will ever be able to break the
installation badly enough that it won't start up.

Although the system is read-only, most of the SD card will be reserved for user
files, and this part will be writeable.

This software is intended for experienced Linux users, who like to work at the
command line :) There is some support for X, but this isn't really what
this software is for. If you want to extend the installation, you'll certainly
need to be familiar with what is in the Raspberry Pi repositories.

This software should work with any Pi, but I've mostly tested with the 3B+. By
'minimal' I don't mean the amount of storage -- even an SD card that costs only
a few pennies has way more storage than is required. Rather, I mean the number
of processes and services that are started. I'm aiming for a boot time of a few
seconds, measured from the time the kernel starts (which is about five seconds
after power-on). It goes without saying that all the auto-configuration stuff
in a desktop Linux (`systemd`, `udev`, `dbus`, Pulse, etc) would be completely
inappropriate here.

The utilities to be installed are reasonably configurable but, because it's a
read-only installation, a decision has to be made at build time -- there's no
package manager, or any other way to update the installation after build. In
fact, many things are fixed at build time, that would normally be configurable.
This intransigence is all aimed at the main design goal: instant-on,
instant-off. 

This is not a complete Linux and it certainly isn't a Linux distribution -- it
is intended as a base for customization.  You'll need to add configuration for
most external devices that you plan to connect, as well as deciding in advance
what software packages to install to use them. If you just want a light(-ish)
conventional desktop Linux for the Pi, I can recommend DietPi and Alpine.

The Linux installation built by `rasp-pi-min-console-build` boots to a shell
prompt with multiple virtual consoles.  It can be configured to auto-login a
user. Only one user is created by default -- user `test` with password `test`
(but this can be changed). There is, of course, no facility to add new users at
runtime.

The build process can generate configuration for wifi networking, but only with
fixed configuration parameters that are specified in advance.  There are also
options to enable ALSA audio and USB storage.

It is worth stressing again that, by design, the root filesystem is completely
read-only at run-time.  Of course, this means that all configuration must be
done by hacking on the files in this repository, and then building a new image
on SD card. There is intentionally no way to modify any configuration at
run-time.

`rasp-pi-min-console-build` is a specific implementation of the general
technique for implementing a minimal, read-only Linux that I describe on my
website:

https://kevinboone.me/pi\_minimal.html

## Implementation notes

### Read-only Linux on the Pi

Why would you want a read-only Linux, anyway? For embedded and kiosk
applications, users won't follow a shut-down procedure -- it might not even be
possible to. By making the entire installation read-only, this problem is
completely removed. Since nothing is writeable, nothing can be left in a broken
state if the user just pulls the plug. Moreover, there is no fault that a user
can create -- that doesn't involve physical trauma -- that can't be fixed by
rebooting.

But even a general-purpose computer can benefit from instant-on, instant-off
operation. Keep in mind that the Pi has no sleep/suspend/low-power mode.  The
only way to power off a regular Pi Linux safely is to go through a full,
orderly shutdown, which can take a minute. Rebooting can take two minutes. This
read-only Linux reboots in about ten seconds.

Raspbian and similar distributions are not at all designed to run in a
read-only environment. In fact, it takes a lot of effort to make read-only
operation possible with any modern Linux.  Most obviously, there has to be a
`/tmp` directory that can hold temporary files. Many utilities expect to be
able to write to `/var`, `/run` and other places. My approach is to define
`/tmp` to be in in-memory filesystem using `tmpfs`; all other directories that
have to be writable are symbolic links to directories under `/tmp`. Utilities
that change configuration at runtime -- such as <code>dhcpcd</code> when it
configures a network interface -- have to be provided with ways to overwrite
configuration files (like <code>/etc/resolv.conf</code>) that are on a
read-only filesystem. Again, symlinks come to our rescue here. Still, the
set-up is a little fiddly.

### Living without auto-configuration

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
conventional desktop Linux systems, but is completely inappropriate in 
an embedded or single-purpose installation.

## Filesystem layout

The build process creates three partitions on the SD card. Of these, only the
third is writeable, and this should contain only user data.  The
`prepare-card.sh` script allocates all the space on the SD card, that is not
used by the first two partitions, to this user partition.

It should go without saying that, although the _system_ is read-only, rebooting
without saving user data will have no happier outcome than than it would on any
computer. However, because the user partitionis mounted with the `sync` 
option, it should be impossible to get into a situation where there is
a heap of data waiting to be flushed to the SD card, and you power off.
This is the cause of many a corrupt filesystem in desktop Linux systems.
Of course, you _can_ still power off while there's data waiting to be
flushed but, with the `sync` option, when a "save" operation claims
it's finished, it actually is. The synchronous operation does come with
a speed penalty, of course. 

### Networking 

If networking is enabled in the configuration file, the build will include
networking utilities, and scripts to configure the network adapters using DHCP.
For wifi networking, the configuration will need to include the details of the
access point and a password, if used. Enabling networking also enables the SSHD
server for remote login. Even if auto-login is enabled for the console, the
SSHD server expects a password. Starting a wifi network can take a little
while, but this doesn't delay getting to a shell prompt, as it happens later.

There's no point providing any nice, graphical way for the user to select 
network configuration, because it can't be stored anywhere. 

### Time setting

The Raspberry Pi has no real-time clock. If networking is enabled, the time is
set using a simple script that gets its from one of Google's webservers. This
isn't a very robust approach, but it works for simple applications.

### Boot process

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

### What is running after boot?

The following process, other than those in the kernel, will always be
running:

    syslogd
    init
    login
    bash

If networking is enabled, we also have

    dhcpd
    wpa_supplicant (if wifi is enabled)

The following processes are optional, and are running if enabled by
settings in CONFIG.sh

    gpm
    sshd

And that's it. All these processes together use only about 30Mb or RAM,
which is a big deal on a Pi 3B+, which only has about 860Mb after the GPU
has taken its share.

### System log

The system log deamon is my own:

https://github.com/kevinboone/syslogd-lite

It is designed to use minimal resources, which it achieves by maintaining
a fixed size, rolling buffer of no more than 100 log lines (by default).
Note that the system log is in the conventional place -- `/var/log/messages`
-- which is in RAM in this implementation.

### Console appearance and keyboard layout

This software is designed to generate a Linux installation that will be used
with console-based tools.  Consequently, I've included tools to set the
appearance and size of the console font. The console configuration file is
<code>rootfs-overlay/etc/default/console-setup</code>.  You could also just
invoke <code>setfont</code>  with a font file in
<code>/usr/share/consolefonts</code>.  

By default no keyboard configuration is done. The <code>loadkeys</code> utility
(e.g., <code>loadkeys uk</code>) could be inovked to set a keyboard layout.
The default keyboard layout is US.

### USB storage

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

### Audio

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

### Official touch-screen support

There's nothing special to do to enable the display part of the Pi 
official touch-screen -- support is built into firmware. However, to enable 
the touch sensitivity and the backlight control, you'll need to enable
kernel modules `rpi-ft5406` and `rpi_backlight` respectively. You can
just add these to `OPTIONAL_MODULES` (see below). For the record, 
the backlight brightness is set in the range 0-255 by writing 
`/sys/class/backlight/rpi_backlight/brightness`. 

### Optional kernel modules

There is no device detection -- any kernel modules you'll need will have
to be installed at boot time. There is a setting `OPTIONAL_MODULES` for
this. Modules specified here are loaded very early in the boot process 
-- before showin a prompt. So if you're using modules that are slow to
load, or might even fail to load, it would be better to create an additional
script under <code>rc1.d</code> and do the load there.

### Bluetooth and serial UART

The default installation disables Bluetooth, and configures the serial
UART (pins 8 and 10) as device `/dev/ttyAMA0`. You could, in principle,
use this UART as the console, but I've assumed it's more likely to be
used to connect another device. The boot process adds permissions
for AMA0 to the default user. To restore the default functionality,
remove the `dtoverlay=pi3-disable-bt` line from `config.txt`. Of course,
you'll need to install all the Bluetooth software if you actually
want to use BT. Disabling it shaves about 0.4 seconds off the boot time.

## How to build 

### How to build

Here is the basic procedure to build with default configuration.

- Insert an SD card, or a card reader with an SD card, into the workstation.
  The card must be at least 2Gb, but larger is no problem -- all available
  space will be used. This must be an SD card that you don't mind being
  wiped.

- Check using, for example, `dmesg`, what is the `/dev` device that represents
  the SD card, e.g., `/dev/sdb`. There may also be `/dev` entries for
  specific partitions -- ignore these.

- Edit `CONFIG.sh` to determine what is to be installed, and any other
  settings that need to be edited. It is <b>crucial</b> that the value
of `CARD` -- the default SD card device -- is correct. Errors in this
area could be catastrophic for the host system.

- Run `build.sh` as an unprivileged user. This will download all the 
  packages, and populate local copies of the root filesystem and boot
  partition. This will take a long time.

- Run `prepare-card.sh` as root, passing the size of the root filesystem
  in megabytes (see below). This will create three partitions on the
  card, and put a new FAT filesystem on the first, and ext4 filesystems
  on the others. The first partition will contain the Pi boot firmware
  and kernel; the second will contain the root filesystem; the third
  will contain the home directory of the single user. To find the
  size of the root filesystem, run `du -h /tmp/rootfs` after build.
  Allow some additional space -- see below for why.
  Note that `prepare-card.sh` is, in principle, a one-time operation
  for a specific card. You can run `build.sh` and `copy-to-card.sh`
  without preparing the card again. However, you will need to run
  `prepare-card.sh` again if you add additional packages, and the root
  filesystem gets too large to fit. This is why I suggested allowing
  a bit of extra space in the root partition. If you have enabled all the
  options in CONFIG.sh, including X support, use '900' (megabytes) 
  as the argument to `prepare-card.sh`.

- Run `copy-to-card.sh` as root. This will copy the local versions of
  the root and boot partitions to the card, and set the appropriate
  ownership and permissions.

- If you want to clean up all intermediate files, run `./cleanall.sh`.

Note that a full build, with nothing cached, will take about 30 minutes
-- longer if you have included extra packages.
Most of that time will be spent downloading from repositories, but
populating the SD card is also fairly time-consuming.

### The build process

Here is what <code>build.sh</code> does.

1. Downloads the latest Pi firmware/kernel bundle, and unpacks it 
into a directory that will become the boot partition of the SD card.

2. Merges into the boot directory the content of the <code>bootfiles/</code>
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
 
## Configuration notes

### Settings file CONFIG.sh

This file is used during the image build process, and is also copied to
the build, into the `/etc`/ directory, where its settings are used
at run-time. I hope that the copious comments in this file make it reasonably
clear what the various settings do. 

### X support

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

To start an X session run `sudo startx`. This will start the X server, a single
terminal session, and the Matchbox window manager. The X server needs to run as
root because it's a pain to change all the permissions of all the devices it
uses. However, it starts the window manager and terminal as the unprivileged
user. When the window manager exits, the X session will end. For
convenient you can run the `stopx` script to make that happen.

It's a pretty crude
setup and, at best, it's a starting point for running an X-based installation,
and will need radical customization for anything practical.  Once we start
running X, the benefits of using a minimal, read-only distribution like this,
start to become less significant.

Keep in mind that, even when X support is enabled, other than a window manager
and a terminal, no X applications are installed in the default configuration.


## Usage notes

### Console and virtual terminals

The first three virtual terminals (accessed by pressing Alt-F1 ... Alt+F3)
are for user session. The user 'test' is automatically logged in. 
VT4 is reserved for the system console -- this is where boot messages
will go. With luck, there won't be any, because all but the most important
are suppressed to speed up the boot. 

### User 

The build creates one single, default user called 'test', with password
'test'. You'll only need the password to run `sudo` -- there is
no `root` user. 

### User data

The user's home directory is on the third partition of the SD card.
Neither `build.sh` not `copy-to-card.sh` will remove any of this
data. However, `prepare-card.sh` will erase all data on the card.

### Reboot

Ctrl+Alt+Del should work. There is no shutdown procedure. To reboot at
the prompt, run `/sbin/reboot -f`. 

### Audio 

There is, of course, no Pulse audio in this installation. You can use
ordinary ALSA drivers -- although most audio/video utilities now default
to using Pulse. For example, to play audio using VLC:

    vlc -A alsa --alsa-audio-device sysdefault:CARD=Headphones {audio_file}

With an HDMI monitor, the default ALSA device is HDMI audio. It is, of
course, possible to create a script that launches VLC (or whatever)
with the appropriate settings. To get a list of ALSA devices, 
use `aplay -L`.

### Video 

Since the sad demise of `omxplayer`, I have not been able to find any way
to play video adequately in a console session. The latest version of VLC
is supposed to support the Pi's video hardware, but I could not get it
to work as yet.

### wifi selection 

If `ENABLE_WIFI` is selected at build time, then a startup script will be
generated that enables a wifi interface. The settings for the access point
are defined in `CONFIG.sh`, which is copied to the root filesystem.

Obviously, this process requires that the wifi properties be known in
advance. You can change the access point at runtime using:

    $ sudo /sbin/setwifi {SSID} {KEY}

To get a list of reachable access points, do

    $ sudo /sbin/scanwifi 

The results are not persistent because, of course, nothing is in this
kind of set-up. Please note that it might take ten seconds or more for
a change to the access point to take effect, and there's no real way to
get an indication when it finished -- or even if it succeeded -- except
by checking that wifi communication is possible.

### Console mouse

By default, `gpm` is enabled, to provide USB mouse support in the console.
You can disable it to shave a fraction of a second of the boot time, but
it's very useful if you're working entirely in the console. Use the
left and right buttons to select text, and the middle button to paste.

## If you really must write the root filesystem

If you really, really must update the root filesystem at runtime, it is
possible. To remount writeable:

    $ sudo mount -o remount,rw /

and to make it read-only again:

    $ sudo mount -o remount,ro /

I can see why it might be useful to do this for simple administrative
operations, like changing a user password, or adding an entry to `/etc/hosts`.
However, this isn't at all how this system is intended to be used and, if you
run the build process again, it's going to overwrite any changes made this way.

## Problems and limitations

- 'Minial' here refers to the load at runtime, not the size of the installation.
  Because the build uses the Raspbian repositories, and follows all the
dependencies, the size of the root partition will actually be large 
-- hundreds of megabytes at least. Since storage is so cheap, I don't
deam this to be a problem, so long as none of these bloated dependencies
do anything at runtime.

- It takes a long time to run `build.sh`, because nothing is cached. Each
package is downloaded from the repository each time. This
makes testing a new configuration tedious. 

- No video playback support so far -- not on the console, anyway. VLC 
under X will play full-screen 720p (at least) video, but I haven't been
able to get it working on the console.

- By default, no software firewall is installed. This system isn't
designed for exposing services to the Internet. 

## Troubleshooting

During build, watch for errors from `prepare-card.sh` and `copy-to-card.sh`.
Unfortunately, errors from `build.sh` will flash past so fast that you
won't see them. A common problem is not allocating enough space on the
SD card for the root filesystem (too small an argument to 
`prepare-card.sh`).

If the screen is completely blank, and the green LED of the Pi never flashes,
check that the boot files are in the first partition of the SD and, that the
'bootable' flag is set on this partition, and that it is of type 11, that is,
VFAT.  It isn't enough for the Pi that the filesystem be of VFAT type, the
appropriate type code must be set in the partition table, and it must be marked
as bootable. 

The type code should be set by `prepare-card.sh`.  Unfortunately,
`prepare-card.sh` cannot set the boot flag -- it uses `fdisk` to partition the
card, which can only toggle the flag. So it's as likely to turn the flag off as
to turn it on. It's generally not a good idea to run `fdisk` on a card that is
mounted -- and some Linux installations mount SD cards as soon as they are
plugged in. However, it's safe to use it to change the boot flag.

The Pi firmware displays nothing until the kernel boots, and even then 
little is displayed, to increase boot speed. If the boot process does
output anything, it will be on virtual terminal 4 (press Alt+F4).

If the time is wrong -- please wait a while. The start-up scripts use Google's
servers to retrieve the time, and they can be slow to respond. 
However, if the time is never correct, this may indicate a general
failure of networking. 

## Bundle contents 

`bootfiles` -- contains files that will be copied to the boot partiion 
during the build (e.g., `cmdline.txt`). Editing these files is the appropriate
way to modify the firmware and kernel boot conditions.
The defaults should work, but it's not unusual to
have to change these files to, for example, enable specific features in
firmware. These are standard Raspberry Pi files that are well documented.

`build.sh` -- the main build script. Must be run as an unprivileged user.

`cache` -- this directory is created by the build, and contains cached 
copies of artefacts downloaded from the Raspbian repository.

`cleanall.sh` -- removes everything created by the build script, except the
`cache` directory.

`CONFIG.sh` -- all the configuration parameters for the build and at runtime

`contrib-bin` -- binaries that have been built elsewhere and included in
this build process (e.g., the custom system log daemon). The distinction
between this directory and `rootfs-overlay` is that the latter is part of
this project, while `contrib-bin` contains foreign binaries that have their
own projects.

`copy-to-card.sh` -- Copies the root, home, and boot images created by
`build.sh` to an SD card. Probably has to be run as root.

`get_deb.pl` -- A script to download packages from the Raspbian repository.

`misc-config` -- A few configuration files that could not be placed in
`rootfs-overlay` because their target directories are generated during the
build.

`prepare-card.sh` -- partitions an SD card read for `copy-to-card.sh`.


## Revisions

0.0.2, February 2023:
- Updated the `get_deb.pl` script to version 0.2, which includes caching support
- Removed the non-GPL firmware that was stuck in the `rootfs-overlay` directory. Oops.

0.0.1, December 2022:
First release

