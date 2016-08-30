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

class MultiPascalString is Constructed {
	has StaticData $.header = Buf.new: "MStr".ords;
	has uint8 $.elems is readonly;
	has Array[PascalString] $!strs;

	method strs {
		return Proxy.new(
			FETCH => sub ($) {return $!strs},
			STORE => sub ($, $v) {$!strs = $v; $!elems = $v.elems;}
		);
	}
}

sub MAIN(IO() $file) {
	my $i = PascalString.new(Buf.new(0x5, "hello".ords));
	$i.parse;
	my $b = MultiPascalString.new(Buf.new("MStr".ords, 0));
	$b.parse;
	$b.strs.push: $i;
	say $b;
	say $b.build;
}

