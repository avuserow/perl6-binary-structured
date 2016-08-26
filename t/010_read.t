use v6;
use lib 'lib';

use Test;
use File::Temp;

use IO::Binary;

subtest 'int8 tests', {
	my %data = map {$_ => (my int8 $ = $_)}, (0, 255, 0, 1, 254, 127, 128);
	my ($filename, $fh) = tempfile;
	$fh.write(Buf.new(%data.keys>>.Int));

	my $binh = IO::Binary.new(file => open($filename, :bin));
	my @found;
	push @found, $binh.read-int8 until $binh.file.eof;

	is @found, %data.values;
};

done-testing;
