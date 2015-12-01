#!/usr/bin/perl
# Perl port of TwiddlerCfgConverter:
# https://github.com/MarkoMarjamaa/TwiddlerCfgConverter
use strict;
use File::BOM qw(:all);

my %buttonMap = ();
$buttonMap{'O'}=0;
$buttonMap{"R"}=2;
$buttonMap{"M"}=4;
$buttonMap{"L"}=8;

my %thumbMap = ();
$thumbMap{"O"}=(0b0000000000000000);
$thumbMap{"S"}=(0b0001000000000000);
$thumbMap{"C"}=(0b0000000100000000);
$thumbMap{"A"}=(0b0000000000010000);
$thumbMap{"N"}=(0b0000000000000001);

my @chordMap = ();
my @stringTable = ();
my $stringIndex = 0;
my %used = ();

my $OPT_UNKNOWN = 1;     # TODO errata: keyrepeat + mass = 5?
my $OPT_KEY_REPEAT = 2;
my $OPT_MASS_STORAGE = 4;

sub pushb {
    my $arr = shift;
    my $b = shift;
    if ($b != ($b & 255)) {
        print STDERR "Cannot push $b\n";
        return 0;
    }
    push(@$arr, $b);
    return -1;
}

open_bom(FH, $ARGV[0], ":utf8");

while (<FH>) {
    chomp;
   #  Ignore comments, and leading/trailing whitespace
    s/#.*//; s/^\s*//; s/\s*$//;
    if ($_ eq ""){
        # Ignore empty lines
        next;
    } elsif ($_ eq "-- Chords --") {
        next;
    } else {
        my $chordRepresentation = 0;
        my ($mods, $chords, $keys, $text)  = split(/ /);
        # Chord Modifiers
        foreach my $mod (split(//, $mods)) {
            $chordRepresentation |= $thumbMap{$mod};
        }
        my $shift = 0;
        foreach my $chord (split(//, $chords)) {
            $chordRepresentation |= ($buttonMap{$chord} << $shift);
            $shift += 4;
        }
        if ($used{$chordRepresentation}) {
            print STDERR "WARNING: remapping $_ at $.\n";
        }
        $used{$chordRepresentation} = 1;
        pushb(\@chordMap, $chordRepresentation & 0xff) or die;
        pushb(\@chordMap, $chordRepresentation >> 8) or die;;
        if ($keys =~ /,/) {
            pushb(\@chordMap, 0xff) or die;
            pushb(\@chordMap, $stringIndex++) or die;
            my @keyList = split(/,/, $keys);
            my $len = 2 * (scalar @keyList) + 2;
            pushb(\@stringTable, $len & 0xff) or die;
            pushb(\@stringTable, $len >> 8) or die;
            foreach my $key (@keyList) {
                pushb(\@stringTable, hex(substr($key, 0, 2))) or die;
                pushb(\@stringTable, hex(substr($key, 2, 2))) or die;
            }
        } else {
            pushb(\@chordMap, hex(substr($keys, 0, 2))) or die;
            pushb(\@chordMap, hex(substr($keys, 2, 2))) or die;
        }
    }
}

 # ERRATA: PDF claims delimeter length 4, but actually it's 2
push(@stringTable, 0, 0);
push(@chordMap, 0, 0, 0, 0);

#TODO
my @mouseMap = (8,0,2,4,0,4,2,0,1,128,0,130,64,0,132,32,0,129,0,8,33,0,4,17,0,2,65,0,128,161,0,64,10,0,32,9,0,0,0);

my $headerSize = 16;

my $chordMapOffset = $headerSize;
my $mouseMapOffset = $chordMapOffset + scalar @chordMap;
my $stringTableOffset = $mouseMapOffset + scalar @mouseMap;

#ConfigFormatVersion
print chr(0x4);

sub printTwoByteLsb {
    my $n = shift;
    
    print chr($n & 0xff);
    print chr($n >> 8);
}

#ChordMapOffset 
printTwoByteLsb($chordMapOffset);
printTwoByteLsb($mouseMapOffset);  # unused
printTwoByteLsb($stringTableOffset);

# unused by twiddlerv3
print chr(0) x 8;

# options
print chr($OPT_MASS_STORAGE);

foreach my $b ((@chordMap, @mouseMap, @stringTable)) {
    print chr($b);
}


