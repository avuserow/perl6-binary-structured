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

done-testing;
