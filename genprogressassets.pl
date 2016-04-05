#!/usr/bin/perl

#
# The MIT License (MIT)
#
# Copyright (c) 2016 yaalaa
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Manages translations, source and exported
#

use strict;
use Getopt::Long;
use Scalar::Util qw(blessed reftype);
use Data::Dumper;
use File::Path qw(make_path);

$|=1;

local $/;

# hello message
printf "Hi there, I'm %s\n", $0;

my $usage = <<EOT;
Generates Xcode assets folders for animation frames

Usage:
  <me> [option ..]
  
  Options:
    --help              - this help screen
    --out-name <name>   - output assets basename
    --out-scale <scale> - output assets scale (defaults to 2)
    --in-regex          - input PNGs filename regex
                          should contain (\\d+) 
                          should match the whole filename (defaults to \\D*(\\d+).*\\.png)
    --in-dir <path>     - input directory (defaults to .)
    --out-dir <path>    - output directory (defaults to assets)

EOT

if ( scalar( @ARGV ) <= 0 ) # no arguments
{
    printf $usage;
    exit( 0 );
}

my $printHelp;
my $optOutName;
my $optOutScale = 2;
my $optInRegex = "\\D*(\\d+).*\\.png";
my $optInDir = ".";
my $optOutDir = "assets";

my $optResult = GetOptions( 
    "help"          => \$printHelp,
    "out-name=s"    => \$optOutName,
    "out-scale=i"   => \$optOutScale,
    "in-regex=s"    => \$optInRegex,
    "in-dir=s"      => \$optInDir,
    "out-dir=s"     => \$optOutDir,
    );

if ( !$optResult || $printHelp )
{
    printf $usage;
    exit( 0 );
}

# check output scale
if ( $optOutScale != 1 && $optOutScale != 2 && $optOutScale != 3 )
{
    printf "Error: invalid output scale[%s]\n", $optOutScale;
    exit( 1 );
}

# check input regex
if ( !( $optInRegex =~ /\(\\d\+\)/i ) )
{
    printf "Error: invalid input regex[%s]\n", $optInRegex;
    exit( 1 );
}

my $inRegex = $optInRegex;

$inRegex =~ s/^([^^])/^$1/;
$inRegex =~ s/([^\$])$/$1\$/;

# check input directory
my $inDir = ToStraightSlash( $optInDir );

if ( $inDir eq "/" )
{
    printf "Error: invalid input directory[%s]\n", $optInDir;
    exit( 1 );
}

# remove trailing slash
$inDir =~ s/\/$//;

if ( ! -d $inDir )
{
  printf "Error: input directory doesn't exist[%s]\n", $optInDir;
  exit( 1 );
}

# check input directory
my $outDir = ToStraightSlash( $optOutDir );

if ( $outDir eq "/" )
{
    printf "Error: invalid output directory[%s]\n", $optOutDir;
    exit( 1 );
}

# remove trailing slash
$outDir =~ s/\/$//;

if ( -d $outDir )
{
    printf "Error: output directory already exists[%s]\n", $optOutDir;
    exit( 1 );
}

# dump operation parameters
printf "Input directory : %s\n", $optInDir;
printf "Input regex     : %s -> %s\n", $optInRegex, $inRegex;
printf "Output directory: %s\n", $optOutDir;
printf "Output name     : %s\n", $optOutName;
printf "Output scale    : %s\n", $optOutScale;
    
# prepare contents

my $contentsGeneric = "\n      \"filename\" : \"\%s\",";
my $contents1x = $optOutScale == 1 ? $contentsGeneric : "";
my $contents2x = $optOutScale == 2 ? $contentsGeneric : "";
my $contents3x = $optOutScale == 3 ? $contentsGeneric : "";


my $contents = <<EOT;
{
  "images" : [
    {
      "idiom" : "universal",
      "scale" : "1x",$contents1x
    },
    {
      "idiom" : "universal",$contents2x
      "scale" : "2x"
    },
    {
      "idiom" : "universal",$contents3x
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}

EOT

my $outFileNameFmt = $optOutName."%d\@${optOutScale}x.png";

# look for input files
my %pngs;

{
    my $dirH;

    if ( !opendir( $dirH, $inDir ) )
    {
        printf "Error: opendir[%s] failed [%s]\n", $optInDir, $!;
        exit( 1 );
    }

    my @files = grep( /$inRegex/i, readdir( $dirH ) );

    closedir( $dirH );
    
    if ( scalar( @files ) <= 0 )
    {
        printf "Error: no input file found in [%s]\n", $optInDir, $!;
        exit( 1 );
    }
    
    for my $cur ( @files )
    {
        if ( $cur =~ /$inRegex/i )
        {
            my $ofs = $1;
    printf "matches[%s]: %s -> %s\n", $inRegex, $cur, $ofs;
            $pngs{$ofs} = $cur;
        }
    }
}

# write output
{
    my $ok = 1;
    my $ofs = 0;

    for my $idx ( sort { $a <=> $b } keys %pngs )
    {
        my $curName = "${optOutName}${ofs}";
        my $curPath = "${outDir}/${curName}.imageset";
        
        my $outPngName = sprintf( $outFileNameFmt, $ofs );
        
        make_path( $curPath );
        
        {
            my $contentsName = "${curPath}/Contents.json";
            
            my $h;
            
            if ( !open( $h, ">$contentsName" ) )
            {
                printf "Error: open[%s] failed [%s]\n", $contentsName, $!;
                $ok = 0;
                last;
            }

            printf $h $contents, $outPngName;

            close( $h );
        }
        
        link( "$inDir/".$pngs{$idx}, "${curPath}/${outPngName}" );
        
        $ofs++;
    }
    
    if ( ! $ok )
    {
        exit( 1 );
    }
    
    printf "Assets written  : %s\n", $ofs;
}


printf "\n.Done.\n";
exit( 0 );

sub TrimStr
{
  my $str = shift( @_ );
  
  $str =~ s/^\s+([^\s].*)$/$1/g;
  $str =~ s/^(.*[^\s])\s+$/$1/g;
  
  return $str;
}

sub ToStraightSlash
{
  my $src = shift( @_ );
  
  $src =~ s/\\/\//g;
  
  return $src;
}
