#!/usr/bin/env perl6

use v6;
use v6.c;

use lib 'lib';
use BinaryScanner;

class PascalString is Constructed {
	has uint8 $.length is readonly;
	has Buf $!strdata is read(method {$!length});

	method strdata {
		return Proxy.new(
			FETCH => sub ($) {return $!strdata},
			STORE => sub ($, $v) {$!strdata = $v; $!length = $v.bytes;}
		);
	}
}

sub MAIN(IO() $file) {
	my $b = PascalString.new(Buf.new(0x5, "hello".ords));
	$b.parse;
	$b.strdata = Buf.new("hello world".ords);
	say $b;
	say $b.build;
}

