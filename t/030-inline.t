use v6;
use lib 'lib';

use Test;

use BinaryScanner;

class InnerStruct is Constructed {
	has uint8 $.a;
	has uint8 $.b;
}

class OuterStruct is Constructed {
	has uint8 $.before;

	has InnerStruct $.inner;

	has uint8 $.after;
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

done-testing;
