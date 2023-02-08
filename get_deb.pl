#!/usr/bin/perl -w

# This utility downloads .deb p_mainackages and all their dependencies from a
#   repository and expands them into a selectable staging directory. The code
#   keeps track internally of what has been downloaded, to avoid getting caught
#   up in a dependency loop. It also caches downloaded packages and the package
#   index.
#
# This utility only takes package names as arguments. Everything else is
#   expected to be configurated by environment variables, for which there are
#   _no defaults_. These variables MUST be set when this script is exected:
#
# ROOTFS -- the directory to which packages will be expanded. This will be 
# essentially an image of the root filesystem.
#
# TMP -- the temporary directory. This script itself does not use this,
# but some tools it invokes might do.
#
# RASPBIAN_RELEASE -- the name of the release: buster, bullseye, etc.
#
# CACHEDIR -- directory in which to cache the downloaded .deb files
#
# Copyright (c)2018-2023 Kevin Boone, GPLv3.0

use strict;

my $staging = $ENV{'ROOTFS'};
my $tmp = $ENV{'TMP'};
my $release = $ENV{'RASPBIAN_RELEASE'};
my $cachedir = $ENV{'CACHEDIR'};
system ("mkdir -p $cachedir");
                    
# Base URL for the repository
my $base ="http://archive.raspbian.org/raspbian";

# Work out where the Packages file is for the specified distribution
my $remote_packages_main = "$base/dists/$release/main/binary-armhf/Packages.gz";
my $remote_packages_nonfree = "$base/dists/$release/non-free/binary-armhf/Packages.gz";

# This is the local main Packages file
my $packages_main = "$cachedir/Packages-main";
# This is the local non-free Packages file
my $packages_nonfree = "$cachedir/Packages-nonfree";

if (-f $packages_main)
  {
  print ("Local copy of Packages-main exists -- not downloading again\n");
  }
else
  {
  print ("Downloading $packages_main from $remote_packages_main\n");
  system ("curl -L -o ${packages_main}.gz $remote_packages_main");
  system ("gunzip ${packages_main}.gz");
  }

if (-f $packages_nonfree)
  {
  print ("Local copy of Packages-nonfree exists -- not downloading again\n");
  }
else
  {
  print ("Downloading $packages_nonfree from $remote_packages_nonfree\n");
  system ("curl -L -o ${packages_nonfree}.gz $remote_packages_nonfree");
  system ("gunzip ${packages_nonfree}.gz");
  }

my @downloaded_debs = ();

# If the package is found, returns a list with two elements --
#   the URL offset to the download in the repo, and the 
#   dependencies. Both are empty if the entry is not found. 
sub find_package_in_index ($$)
  {
  my $found = 0;
  my $index = $_[0]; 
  my $name = $_[1]; 
  my $rel_url = "";
  my $depends = "";
  if ($index eq "nonfree")
    {
    open (PACKAGES, $packages_nonfree) or die "Can't open $packages_nonfree\n";
    }
  else
    {
    open (PACKAGES, $packages_main) or die "Can't open $packages_main\n";
    }

  while (<PACKAGES>)
    {
    my $line = $_;
    chomp ($line);
    if ($found)
      {
      if ($line)
        {

        if ($line =~ /Filename: (.*)$/)
          {
          $rel_url = $1;
          }
        if ($line =~ /Depends: (.*)$/)
          {
          $depends = $1;
          }
        }
      else
        {
        $found = 0;
        }
      }
    else
      {
      if ($line eq "Package: $name")
        {
        $found = 1;
        }
      }
    }
  close (PACKAGES);
  if ($rel_url)
    {
    return ($rel_url, $depends);
    }
  else
    {
    printf ("returning empty\n");
    return ("", "");
    }
  }


sub find_package_in_main_index ($)
  {
  return find_package_in_index ("main", $_[0]);
  }


sub find_package_in_nonfree_index ($)
  {
  return find_package_in_index ("nonfree", $_[0]);
  }


sub download_deb ($)
  {
  my $rel_url = $_[0]; 
  my $url = $base . "/" . $rel_url;
  print ("Download url is $url\n");
  my $debfile = $cachedir . "/" . substr $url, rindex ($url, '/') + 1;
  if (-f $debfile)
    {
    printf ("Local file $debfile is already downloaded\n");
    }
  else
    {
    system ("curl -L -o $debfile $url");
    }

  if (-e $debfile)
    {
    system ("ar x $debfile");
    if (-e "data.tar.xz") 
      {
      my $datafile = `realpath data.tar.xz`;
      chomp ($datafile);
      printf ("Uncompressing filesystem contents for $debfile\n");
      system ("cd $staging; xzdec $datafile | tar xf - ");
      }
    elsif (-e "data.tar.gz") 
      {
      my $datafile = `realpath data.tar.gz`;
      chomp ($datafile);
      }
    else
      {
      print (".deb data file format not recognized\n");
      }
    unlink ("control.tar.gz");
    unlink ("control.tar.xz");
    unlink ("data.tar.gz");
    unlink ("data.tar.xz");
    unlink ("debian-binary");
    }
  else
    {
    print ("Error: can't download .deb file: $url\n");
    }
  }

sub get_package_and_dependencies ($);

sub get_package_and_dependencies ($)
  {
  my $name = $_[0]; 
  if (grep (/^$name$/, @downloaded_debs)) 
    {
    print ("Package $name already downloaded\n");
    }
  else
    {
    push (@downloaded_debs, $name);
    my @temp = find_package_in_main_index ($name);
    my $rel_url = $temp[0];
    if ($rel_url)
      {
      printf ("Package $name found in main index\n");
      }
    else
      {
      @temp = find_package_in_nonfree_index ($name);
      $rel_url = $temp[0];
      if ($rel_url)
        {
        printf ("Package $name found in nonfree index\n");
        }
      }
    my $depends = $temp[1];
    if ($rel_url)
      {
      system ("mkdir -p $staging");
      print ("Downloading $name from $rel_url\n");
      download_deb ($rel_url);
      if ($depends)
        {
        my @deps = split (',', $depends);
        foreach my $dep (@deps)
          {
          $dep =~ s/^\s+|\s+$//g;
          $dep =~ /(\S*)/;
          $dep = $1;
          printf ("Downloading dependency $dep\n");
          get_package_and_dependencies ($dep);
          }
        }
      }
    else
      {
      print ("Package $name has no offset URL -- is it in the index?\n");
      }
    }
  }


for (my $i = 0; $i < scalar (@ARGV); $i++)
  {
  get_package_and_dependencies ($ARGV[$i]);
  }



