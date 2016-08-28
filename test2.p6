#!/usr/bin/env perl6

use v6;
use v6.c;

use lib 'lib';
use BinaryScanner;

sub MAIN(IO() $file) {
	my $data = $file.slurp(:bin);

	my $b = Parameters.new($data);
	$b.parse;
	# say $b;
}

