#!/usr/bin/env perl6

use v6;
use v6.c;

use lib 'lib';
use BinaryScanner;

class PascalString is Constructed {
	has uint8 $.length;
	has Buf $.value is read(method {$.length}) = Proxy.new(
		FETCH => method {$!value},
		STORE => method ($value) {
			$!value = $value;
			$.length = $value.bytes;
		},
	);
}

sub MAIN(IO() $file) {
	my $buf = Buf.new(0x5, "hello world".ords);
	my $b = PascalString.new($buf);
	$b.parse;
	say $b.build;

#	my $data = $file.slurp(:bin);
#
#	my $b = Parameters.new($data);
#	$b.parse;
#	say $b;
}

