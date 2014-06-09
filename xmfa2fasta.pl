#!/usr/bin/perl
#Converts XMFA files to FASTA
#Use the --align option to align individual locus blocks if an unaligned XMFA file is the source.
#Written by Keith Jolley, 2010-2014
#
#Usage:
#Output to STDOUT:     xmfa2fasta.pl [--align] --file <XMFA file>
#Output to FASTA file: xmfa2fasta.pl [--align] --file <XMFA file> > <FASTA file>
use strict;
use warnings;
use 5.010;
use Getopt::Long qw(:config no_ignore_case);
my $mafft  = '/usr/bin/mafft';
my $prefix = int( rand(99999) );
my %opts;
GetOptions( 'a|align' => \$opts{'a'}, 'h|help' => \$opts{'h'}, 'f|file=s' => \$opts{'f'} )
  or die("Error in command line arguments\n");
my $infile = $opts{'f'};

if ( $opts{'h'} ) {
	show_help();
	exit;
}
if ( !$infile ) {
	say "Usage: xmfa2fasta --file <XMFA filename>";
	exit 1;
}
my $seqs = {};
my @ids;
my $temp_seq;
my $current_id = '';
open( my $fh, '<', $infile ) or die "Cannot open file $infile\n";
my $locus = 0;
while ( my $line = <$fh> ) {

	if ( $line =~ /^=/ ) {
		$seqs->{$current_id}->{$locus} = $temp_seq if defined $current_id;
		$locus++;
		next;
	}
	if ( $line =~ /^>\s*([\d\w\s\|\-\\\/\.\(\)]+):/ ) {
		$seqs->{$current_id}->{$locus} = $temp_seq if defined $current_id;
		$current_id = $1;
		if ( !$seqs->{$current_id} ) {
			push @ids, $current_id;
		}
		undef $temp_seq;
	} else {
		$line =~ s/[\r\n]//g;
		$temp_seq .= $line;
	}
}
close $fh;
my $locus_count = $locus;
if ( $opts{'a'} ) {
	my $in_file      = "$prefix.fas";
	my $aligned_file = "$prefix\_aligned.fas";
	my $aligned_seqs = {};
	foreach my $locus ( 0 .. $locus_count - 1 ) {
		open( my $fh, '>', $in_file ) || die "Can't write temp file.\n";
		foreach my $id (@ids) {
			say $fh ">$id";
			say $fh $seqs->{$id}->{$locus};
		}
		close $fh;
		system("$mafft --quiet --preservecase $in_file > $aligned_file");
		my $id;
		my $seq;
		open( my $fh_in, '<', $aligned_file ) || die "Can't open aligned file.\n";
		while ( my $line = <$fh_in> ) {
			if ( $line =~ /^>\s*([\d\w\s\|\-\\\/\.\(\)]+)$/ ) {
				my $new_id = $1;
				chomp $new_id;
				if ($seq) {
					$seq =~ s/[\r\n]//g;
					$aligned_seqs->{$id}->{$locus} = $seq;
					undef $seq;
				}
				$id = $new_id;
			} else {
				$seq .= $line;
			}
		}
		$seq =~ s/[\r\n]//g;
		$aligned_seqs->{$id}->{$locus} = $seq;
		close $fh_in;
	}
	$seqs = $aligned_seqs;
	unlink $in_file;
	unlink $aligned_file;
}
foreach my $id (@ids) {
	say ">$id";
	my $seq;
	foreach my $locus ( 0 .. $locus_count - 1 ) {
		$seq .= $seqs->{$id}->{$locus};
	}
	$seq = line_split($seq);
	say $seq;
}

sub line_split {
	my ($string) = @_;
	my $newseq = '';
	my $s;
	$newseq .= "$s\n" while $s = substr $string, 0, 60, '';
	$newseq =~ s/\n$//;
	return $newseq;
}

sub show_help {
	say << "HELP";

Usage xmfa2fasta --file <XMFA file>

Options
-------
-a             Align locus blocks before concatenating.
--align

-f <file>      XMFA file.
--file

-h             This help page.
--help
HELP
	return;
}
