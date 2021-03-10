#!/usr/bin/env perl
#BLAST gyrB sequences against rMLST databases to determine species
#Copyright (c) Keith Jolley, 2021
#License: GPL3.
#
#Usage:
#Output to STDOUT:       lookup_gyrB.pl [FASTA file]
#Output to results file: lookup_gyrB.pl [FASTA file] > [OUTPUT file]
#Version 20210310
use strict;
use warnings;
use 5.010;
use REST::Client;
use JSON;
use MIME::Base64;
use constant URI => 'https://rest.pubmlst.org/db/pubmlst_gyrB_seqdef_kiosk/loci/BACT000102/sequence';
my $fasta_file = $ARGV[0];
die "No FASTA filename provided.\n" if !defined $fasta_file;
die "FASTA file '$fasta_file' does not exist.\n" if !-e $fasta_file;
main();

sub main {
	my $seqs   = read_fasta($fasta_file);
	my $client = REST::Client->new();
	say qq(id\tallele\t%identity\talignment\tmismatches\tgaps\tspecies);
	foreach my $id ( sort keys %$seqs ) {
		my $payload = encode_json(
			{
				base64              => JSON::true(),
				details             => JSON::true(),
				partial_linked_data => JSON::true(),
				sequence            => encode_base64( $seqs->{$id} )
			}
		);
		my $response = decode_json( $client->POST( URI, $payload )->responseContent );
		print qq($id);
		foreach my $field (qw(allele_id identity alignment mismatches gaps)) {
			my $value = $response->{'best_match'}->{$field} // q();
			print qq(\t$value);
		}
		my $species_list = $response->{'best_match'}->{'linked_data'}->{'rMLST genomes (uncurated)'}->{'species'};
		my @list;
		if ($species_list) {
			foreach my $species (@$species_list) {
				push @list, qq($species->{'value'} (n=$species->{'frequency'}));
			}
		}
		local $" = q(; );
		say qq(\t@list);
	}
	return;
}

sub read_fasta {
	my ($file_path) = @_;
	open( my $fh, '<:raw', $file_path )
	  || die "Cannot open $file_path for reading\n";
	my $contents = do { local $/ = undef; <$fh> };
	close $fh;
	my @lines = split /\r?\n/x, $contents;
	my $seqs = {};
	my $header;
	foreach my $line (@lines) {

		if ( substr( $line, 0, 1 ) eq '>' ) {
			$header = substr( $line, 1 );
			$header =~ s/\s.*$//x;    #Strip off anything after space
			next;
		}
		die "Not valid FASTA format.\n" if !defined $header || length $header == 0;
		$seqs->{$header} .= $line;
	}
	foreach my $id ( keys %$seqs ) {
		$seqs->{$id} =~ s/[^A-z\-\.]//gx;
		die "Not valid DNA - $id\n" if $seqs->{$id} =~ /[^GATCUBDHVRYKMSWN]/x;
	}
	return $seqs;
}
