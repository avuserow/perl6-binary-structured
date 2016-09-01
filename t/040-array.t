use v6;
use lib 'lib';

use Test;

use BinaryScanner;

class InnerStruct is Constructed {
	has uint8 $.a is rw;
	has uint8 $.b is rw;
}

class OuterStruct is Constructed {
	has uint8 $.count is rw;

	has Array[InnerStruct] $.items is read(method {self.pull-elements($!count)}) is rw;

	has uint8 $.after is rw;
}

subtest 'no elements', {
	my $buf = Buf.new: 0, 4;
	my $parser = OuterStruct.new;
	$parser.parse($buf);

	is $parser.count, 0;
	is $parser.items.elems, 0;
	is $parser.after, 4;
};

subtest 'basic parse (count = 1)', {
	my $buf = Buf.new: 1, 2, 3, 4;
	my $parser = OuterStruct.new;
	$parser.parse($buf);

	is $parser.count, 1;
	is $parser.items[0].a, 2;
	is $parser.items[0].b, 3;
	is $parser.after, 4;
};

subtest 'basic parse (count = 2)', {
	my $buf = Buf.new: 2, 1, 10, 2, 20, 100;
	my $parser = OuterStruct.new;
	$parser.parse($buf);

	is $parser.count, 2;
	is $parser.items.elems, 2;
	is $parser.items[0].a, 1;
	is $parser.items[0].b, 10;
	is $parser.items[1].a, 2;
	is $parser.items[1].b, 20;
	is $parser.after, 100;
};

#subtest 'basic build', {
#	my $parser = OuterStruct.new;
#	$parser.inner .= new;
#
#	$parser.before = 1;
#	$parser.inner.a = 2;
#	$parser.inner.b = 3;
#	$parser.after = 4;
#
#	my $res = $parser.build;
#	is $res, Buf.new(1, 2, 3, 4);
#};

done-testing;
