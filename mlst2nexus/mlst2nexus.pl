#!/usr/bin/perl
#Converts MLST TSV files to Nexus for loading into SplitsTree
#Written by Keith Jolley, 2015
#
#Usage:
#Output to STDOUT:     mlst2nexus.pl --file <TSV file>
#Output to FASTA file: mlst2nexus.pl --file <TSV file> > <NEXUS file>

use strict;
use warnings;
use 5.010;
die "No filename entered.\n" if !$ARGV[0];
my $filename = $ARGV[0];
die "File $filename does not exist.\n" if !-e $filename;
open( my $fh, '<:encoding(utf8)', $filename ) || die "Can't open $filename for reading.\n";
my $data = do { local $/ = undef; <$fh> };
close $fh;
my $badentry = 0;
my $i        = 0;
my $lastcols;
my @profilelist = split /\n/x, $data;
my @taxa;
my @cleanedprofiles;

foreach my $line (@profilelist) {
	$line =~ s/[\r\n]//gx;
	if ($line) {
		push @cleanedprofiles, $line;
		$i++;
		my @data = split /\s+/x, $line;
		if ( $i > 1 && scalar @data != $lastcols ) {
			$badentry = 1;
		}
		$lastcols = scalar @data;
		if ( $data[0] ) {
			push @taxa, $data[0];
		}
	}
}
if ( !@taxa ) {
	die "You don't seem to have any identifiers.\n";
}
if ($badentry) {
	die "Your rows must have equal numbers of columns.\n";
}
local $" = "\n   ";
say << "HEADER";
#NEXUS
BEGIN taxa;
   DIMENSIONS ntax=$i;
TAXLABELS
   @taxa
;
END;

BEGIN distances;
   DIMENSIONS ntax=$i;
     FORMAT
     triangle=LOWER
     diagonal
     labels
     missing=?
;

MATRIX

HEADER
my $matrix;
for my $i ( 0 .. @cleanedprofiles - 1 ) {
	my @profile = split /\s+/x, $cleanedprofiles[$i];
	$matrix .= "$profile[0]";
	for my $j ( 0 .. $i - 1 ) {
		my $matches = profile_match( $cleanedprofiles[$i], $cleanedprofiles[$j] );
		my $dist = decimal_place( 1 - ($matches) / ( scalar @profile - 1 ), 3 );
		$matrix .= "\t$dist";
	}
	$matrix .= "\t0\n";
}
say $matrix;
say ';';
say 'END;';

#returns number of matches between two profiles
#first field is identifier
sub profile_match {
	my ( $prof1, $prof2 ) = @_;
	my @profile1 = split /\s+/x, $prof1;
	my @profile2 = split /\s+/x, $prof2;
	shift @profile1;
	shift @profile2;
	my $match = 0;
	for my $i ( 0 .. @profile1 - 1 ) {
		if ( $profile1[$i] eq $profile2[$i] ) {
			$match++;
		}
	}
	return $match;
}

sub decimal_place {
	my ( $number, $decimals ) = @_;
	return substr( $number + ( "0." . "0" x $decimals . "5" ),
		0, $decimals + length( int($number) ) + 1 );
}
