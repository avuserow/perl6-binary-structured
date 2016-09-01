use v6;
use lib 'lib';

use Test;

use BinaryScanner;

class InnerStruct is Constructed {
	has uint8 $.a is rw;
	has uint8 $.b is rw;
}

class OuterStruct is Constructed {
	has uint8 $.before is rw;

	has InnerStruct $.inner is rw;

	has uint8 $.after is rw;
}

subtest 'basic parse', {
	my $buf = Buf.new: 1, 2, 3, 4;
	my $parser = OuterStruct.new;
	$parser.parse($buf);

	is $parser.before, 1;
	is $parser.inner.a, 2;
	is $parser.inner.b, 3;
	is $parser.after, 4;
};

subtest 'basic build', {
	my $parser = OuterStruct.new;
	$parser.inner .= new;

	$parser.before = 1;
	$parser.inner.a = 2;
	$parser.inner.b = 3;
	$parser.after = 4;

	my $res = $parser.build;
	is $res, Buf.new(1, 2, 3, 4);
};

done-testing;
