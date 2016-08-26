use v6;
use v6.c;

class IO::Binary {
	use experimental :pack;

	enum Endianness <LITTLE BIG>;

	has $.file;
	has Endianness $.endianness = LITTLE;

	my enum IsSigned (SIGNED => -1, UNSIGNED => 0);

	method !read-int-auto(Int $bytes, IsSigned $signed) {
		my $data = $.file.read($bytes);
		# note "read $data.gist()";

		$data .= reverse if $.endianness != LITTLE;

		my $value = 0;
		$value = $value * 256 + $_ for $data.list;
		if $signed == SIGNED {
			# Implement two's complement
			if $data[0].msb && $data[0].msb == 7 {
				# xor value with a bit-mask of 0xff....
				$value +^= 1 +< ($value.msb + 1) - 1;
				$value++;
				$value *= -1;
			}
		}
		return $value;
	}

	method read-int8()   returns Int {self!read-int-auto(1, SIGNED)}
	method read-uint8()  returns Int {self!read-int-auto(1, UNSIGNED)}
	method read-int16()  returns Int {self!read-int-auto(2, SIGNED)}
	method read-uint16() returns Int {self!read-int-auto(2, UNSIGNED)}
	method read-int32()  returns Int {self!read-int-auto(4, SIGNED)}
	method read-uint32() returns Int {self!read-int-auto(4, UNSIGNED)}
}

sub MAIN(IO() $file) {
	my $fh = open $file, :bin;
	my $bin = IO::Binary.new(file => $fh);
	say $bin.read-int32 until $fh.eof;
}
