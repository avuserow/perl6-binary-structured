use v6;
use lib 'lib', 't/lib';

use Test;

use BinaryScanner;

subtest 'pascal string', {
	use PascalString;

	subtest 'zero length', {
		my $buf = Buf.new: 0;
		my $parser = PascalString.new;
		$parser.parse($buf);
		is $parser.length, 0, 'length';
		is $parser.string.bytes, 0, 'bytes read';
	};

	subtest 'correct length', {
		my $str = 'hello world';
		my $buf = Buf.new: $str.chars, $str.ords;
		my $parser = PascalString.new;
		$parser.parse($buf);

		isnt $parser.length, 0, 'non-zero length read';
		is $parser.length, $str.chars, 'length read';
		isnt $parser.string.bytes, 0, 'non-zero bytes read';
		is $parser.string.bytes, $str.chars, 'correct bytes count read';
		is $parser.string.list, $str.ords, 'bytes are correct';
	};

	subtest 'trailing garbage', {
		my $str = 'hello world';
		my $length = 5;
		my $buf = Buf.new: $length, $str.ords;
		my $parser = PascalString.new;
		$parser.parse($buf);

		isnt $parser.length, 0, 'non-zero length read';
		is $parser.length, $length, 'length read';
		isnt $parser.string.bytes, 0, 'non-zero bytes read';
		is $parser.string.bytes, $length, 'correct bytes count read';
		is $parser.string.list, $str.ords[^$length], 'bytes are correct';
	};
};

subtest 'cstring', {
	use CString;

	subtest 'zero length', {
		my $buf = Buf.new: 0;
		my $parser = CString.new;
		$parser.parse($buf);
		is $parser.string.bytes, 0, 'bytes read';
		is $parser.terminator.list, [0], 'terminator is valid';
	};

	subtest 'correct length', {
		my $str = 'hello world';
		my $buf = Buf.new: $str.ords, 0;
		my $parser = CString.new;
		$parser.parse($buf);
		isnt $parser.string.bytes, 0, 'non-zero bytes read';
		is $parser.string.bytes, $str.chars, 'correct bytes count read';
		is $parser.string.list, $str.ords, 'bytes are correct';
		is $parser.terminator.list, [0], 'terminator is valid';
	};

	subtest 'trailing garbage', {
		my $str = "hello\0world";
		my $length = 5;
		my $buf = Buf.new: $str.ords;
		my $parser = CString.new;
		$parser.parse($buf);

		isnt $parser.string.bytes, 0, 'non-zero bytes read';
		is $parser.string.bytes, $length, 'correct bytes count read';
		is $parser.string.list, $str.ords[^$length], 'bytes are correct';
	};
};

done-testing;
