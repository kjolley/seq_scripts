#!/usr/bin/perl
#Converts XMFA files to FASTA
#Use the --align option to align individual locus blocks if an unaligned XMFA file is the source.
#Written by Keith Jolley, 2010-2015
#
#Usage:
#Output to STDOUT:     xmfa2fasta.pl [--align] --file <XMFA file>
#Output to FASTA file: xmfa2fasta.pl [--align] --file <XMFA file> > <FASTA file>
use strict;
use warnings;
use 5.010;
use Getopt::Long qw(:config no_ignore_case);
use Term::Cap;
use POSIX;
my $mafft  = '/usr/bin/mafft';
my $prefix = int( rand(99999) );
my %opts;
GetOptions(
	'a|align'       => \$opts{'a'},
	'h|help'        => \$opts{'h'},
	'f|file=s'      => \$opts{'f'},
	'i|integer_ids' => \$opts{'i'},
	'm|missing=s'   => \$opts{'m'}
) or die "Error in command line arguments\n";
my $infile = $opts{'f'};

if ( $opts{'h'} ) {
	show_help();
	exit;
}
if ( $opts{'m'} && length( $opts{'m'} ) > 1 ) {
	die "Missing character can only be a single character\n";
}
if ( !$infile ) {
	say "Usage: xmfa2fasta.pl --file <XMFA filename>";
	say "See xmfa2fasta.pl --help for more options.";
	exit 1;
}
main();
exit;

sub main {
	my $seqs = {};
	my ( @ids, @int_ids );
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
		if ( $line =~ /^>\s*([\d\w\s\|\-\\\/\.\(\),#]+):/ ) {
			$seqs->{$current_id}->{$locus} = $temp_seq if defined $current_id;
			if ( $opts{'i'} ) {
				my $extracted_id = $1;
				if ( $extracted_id =~ /^(\d+)/ ) {
					$current_id = $1;
				} else {
					die "Invalid identifier with --integer_ids option.\n";
				}
			} else {
				$current_id = $1;
			}
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
		my %int_id_used;
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
				if ( $line =~ /^>\s*([\d\w\s\|\-\\\/\.\(\),#]+)$/ ) {
					my $new_id;
					if ( $opts{'i'} ) {
						my $extracted_id = $1;
						if ( $extracted_id =~ /^(\d+)/ ) {
							$new_id = $1;
						} else {
							die "Invalid identifier with --integer_ids options\n";
						}
					} else {
						$new_id = $1;
					}
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
			if ( !defined $seqs->{$id}->{$locus} ) {
				my $std_length = get_standard_locus_length( $seqs, $locus );
				die "No alleles defined for locus $locus.\n" if !$std_length;
				$seqs->{$id}->{$locus} = ( $opts{'m'} // 'N' ) x $std_length;
			}
			$seq .= $seqs->{$id}->{$locus};
		}
		$seq = line_split($seq);
		say $seq;
	}
	return;
}

sub get_standard_locus_length {
	my ( $seqs, $locus ) = @_;
	foreach my $id ( keys %$seqs ) {
		if ( defined $seqs->{$id}->{$locus} ) {
			return length $seqs->{$id}->{$locus};
		}
	}
	return 0;
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
	my $termios = POSIX::Termios->new;
	$termios->getattr;
	my $ospeed = $termios->getospeed;
	my $t = Tgetent Term::Cap { TERM => undef, OSPEED => $ospeed };
	my ( $norm, $bold, $under ) = map { $t->Tputs( $_, 1 ) } qw/me md us/;
	say << "HELP";
${bold}NAME$norm
    ${bold}xmfa2fasta.pl$norm - Convert XMFA file to FASTA file
    
${bold}SYNOPSIS$norm
    ${bold}xmfa2fasta.pl --file ${under}XMFA_FILE$norm [${under}options$norm]
    
    Output is directed to STDOUT.  Usually you will want to create a new
    FASTA file so direct output to the new file, e.g.
    
    ${bold}xmfa2fasta.pl --file ${under}XMFA_FILE$norm [${under}options$norm] >  ${bold}${under}FASTA_FILE$norm

${bold}OPTIONS$norm
${bold}-a, --align$norm
    Align locus blocks before concatenating.
    
${bold}-f, --file$norm ${under}FILE$norm  
    XMFA file.
    
${bold}-h, --help$norm
    This help page.    
    
${bold}-i, --integer_ids$norm
    Use integer at beginning of identifier for sorting.
    
    This strips off any characters after the first non-integer character of
    the identifiers.  This can be used to resolve problems caused by
    truncation of names in other algorithms.  Identifiers must begin with
    an integer to use this.
    
${bold}-m, --missing$norm ${under}CHARACTER$norm  
    Missing sequence character.  Default is 'N'.
HELP
	return;
}
