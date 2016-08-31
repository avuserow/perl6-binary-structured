use v6;
use lib 'lib', 't/lib';

use Test;

use BinaryScanner;

subtest 'pascal string', {
	use PascalString;

	subtest 'zero length', {
		my $parser = PascalString.new;
		$parser.string = Buf.new;
		my $buf = $parser.build;
		is $buf, Buf.new(0);
	};

	subtest 'regular', {
		my $parser = PascalString.new;
		my $buf = Buf.new: "hello world".ords;
		$parser.string = $buf;
		my $res = $parser.build;
		is $res, Buf.new($buf.bytes, $buf.list);
	};
};

subtest 'cstring', {
	use CString;

	subtest 'zero length', {
		my $parser = CString.new;
		$parser.string = Buf.new;
		my $buf = $parser.build;
		is $buf, Buf.new(0);
	};

	subtest 'regular', {
		my $parser = CString.new;
		$parser.string = Buf.new: "hello world".ords;
		my $buf = $parser.build;
		is $buf, Buf.new("hello world".ords, 0);
	};
};

subtest 'numeric data', {
	use NumericData;

	subtest 'basic', {
		my $buf = Buf.new: 1 .. 14;
		my $parser = NumericData.new;

		# NOTE: little endian assumed by default
		$parser.a = 0x01;
		$parser.b = 0x0302;
		$parser.c = 0x07060504;
		$parser.d = 0x08;
		$parser.e = 0x0a09;
		$parser.f = 0x0e0d0c0b;

		my $res = $parser.build;
		is $res, $buf;
	};

	subtest 'overflow', {
		my $buf = Buf.new: 1 .. 14;
		my $parser = NumericData.new;

		# NOTE: little endian assumed by default
		$parser.a = 0xf01;
		$parser.b = 0xf0302;
		$parser.c = 0xf07060504;
		$parser.d = 0xf08;
		$parser.e = 0xf0a09;
		$parser.f = 0xf0e0d0c0b;

		my $res = $parser.build;
		is $res, $buf;
	};
};

done-testing;
