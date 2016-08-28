use v6;
use v6.c;

use experimental :pack;

# sub bytes-to-int($value) {
# 	$value.encode('latin-1').unpack('N');
# }
# 
# grammar ParamFile {
# 	token TOP {
# 		<preamble>
# 
# 		(\x20 (. ** 4) (<data>)+)+
# 	}
# 
# 	token preamble {
# 		. ** 8
# 	}
# 
# 	token data {
# 		| \x01 (.)
# 		| \x02 (.)
# 		| \x03 (. ** 2)
# 		| \x04 (. ** 2)
# 		| \x05 (. ** 4)
# 		| \x06 (. ** 4)
# 		| \x07 (. ** 4)
# 		| \x08 (. ** 4) (. ** {bytes-to-int(~$0)})
# 	}
# }

my %readers;
multi sub trait_mod:<is>(Attribute:D $a, :$read!) {
	%readers{$a} = $read;
}

my %indirect-type;
multi sub trait_mod:<is>(Attribute:D $a, :$indirect-type!) {
	%indirect-type{$a} = $indirect-type;
}

subset StaticData of Blob;
subset AutoData of Any;

class X::Constructed::StaticMismatch is Exception {
	has $.got;
	has $.expected;

	method message {
		"Static data mismatch:\n\tGot: $.got.gist()\n\tExpected: $.expected.gist()";
	}
}

class Constructed {
	has Int $.pos is rw = 0;
	has Blob $.data;
	has Constructed $.parent is rw;

	method new(Blob $data) {
		self.bless(:$data);
	}

	submethod BUILD(:$data) {
		# Hmm. Interesting.
		$!data = $data;
	}

	method peek-one {
		return $!data[$!pos];
	}

	method peek(Int $count) {
		my $subbuf = $!data.subbuf($!pos, $count);
		return $subbuf;
	}

	method !pull(Int $count) {
		my $subbuf = $!data.subbuf($!pos, $count);
		$!pos += $count;
		return $subbuf;
	}

	method !inline-parse($attr, $inner-type is copy) {
		if %indirect-type{$attr}:exists {
			$inner-type = %indirect-type{$attr}(self);
		}
		my $inner = $inner-type.new($!data);
		$inner.pos = $!pos;
		# $inner.parent = self;
		$inner.parse;
		CATCH {
			when X::Assignment {
				note "LAST1";
				return;
			}
			when X::Constructed::StaticMismatch {
				note "LAST2";
				return;
			}
		}
		$!pos = $inner.pos;
		return $inner;
	}

	method gist {
		my $s = '{ ';
		my @attrs = self.^attributes(:local);
		for @attrs -> $attr {
			$s ~= "$attr.name() => $attr.get_value(self).gist() ";
		}
		return $s ~ '}';
	}

	method parse() {
		my @attrs = self.^attributes(:local);
		die "{self} has no attributes!" unless @attrs;
		for @attrs -> $attr {
			given $attr.type {
				# note $attr;
				when StaticData {
					my $e = $attr.get_value(self);
					my $g = self!pull($e.bytes);

					if $g ne $e {
						X::Constructed::StaticMismatch.new(got => $g, expected => $e).throw;
					}
				}
				when Constructed {
					my $inner-type = $attr.type;
					my $inner = self!inline-parse($attr, $inner-type);
					die "Mismatch!" unless $inner;

					$attr.set_value(self, $inner);
				}
				when Array {
					if $attr.type.of !~~ Constructed {
						die "whoa, can't handle a $attr.type.gist() yet :(";
					}
					my @array = $attr.type.new;

					# This attr must know when to stop somehow...
					my $inner-type = $attr.type.of;
					while True {
						# prevent out of bounds...
						last if $!pos >= $!data.bytes;
						my $inner = self!inline-parse($attr, $inner-type);
						last unless $inner;
						@array.push($inner);
					}

					$attr.set_value(self, @array);
				}
				when uint8 {
					$attr.set_value(self, self!pull(1)[0]);
				}
				when uint16 {
					$attr.set_value(self, self!pull(2).unpack('S'));
				}
				when uint32 {
					$attr.set_value(self, self!pull(4).unpack('L'));
				}
				when int8 {
					$attr.set_value(self, self!pull(1)[0]);
				}
				when int16 {
					$attr.set_value(self, self!pull(2).unpack('n'));
				}
				when int32 {
					$attr.set_value(self, self!pull(4).unpack('N'));
				}
				when Buf {
					my $len = %readers{$attr}(self);
					$attr.set_value(self, self!pull($len));
				}
				when AutoData {
					my $len = %readers{$attr}(self);
					$attr.set_value(self, self!pull($len));
				}
				default {
					die "Cannot handle an attribute of type $_.gist() yet!";
				}
			}
		}
	}
}

class ParamValue is Constructed {}

class ParamValueUint8 is ParamValue {
	has StaticData $.type = Buf.new(0x1);
	has uint8 $.value;
}

class ParamValueInt8 is ParamValue {
	has StaticData $.type = Buf.new(0x2);
	has int8 $.value;
}

class ParamValueUint16 is ParamValue {
	has StaticData $.type = Buf.new(0x3);
	has uint16 $.value;
}

class ParamValueInt16 is ParamValue {
	has StaticData $.type = Buf.new(0x4);
	has int16 $.value;
}

class ParamValueUint32 is ParamValue {
	has StaticData $.type = Buf.new(0x5);
	has uint32 $.value;
}

class ParamValueInt32 is ParamValue {
	has StaticData $.type = Buf.new(0x6);
	has int32 $.value;
}

class ParamValueFloat32 is ParamValue {
	has StaticData $.type = Buf.new(0x7);
	has Buf $.value is read(method {4});
}

class ParamValueStr is ParamValue {
	has StaticData $.type = Buf.new(0x8);
	has uint32 $.length;
	has Buf $.value is read(method {$.length});
}

my %TAG_MAPPING := :{
	0x1 => ParamValueUint8,
	0x2 => ParamValueInt8,
	0x3 => ParamValueUint16,
	0x4 => ParamValueInt16,
	0x5 => ParamValueUint32,
	0x6 => ParamValueInt32,
	0x7 => ParamValueFloat32,
	0x8 => ParamValueStr,
};

class ParamGroup is Constructed {
	has StaticData $.type = Buf.new(0x20);
	has uint32 $.entries;

	has Array[ParamValue] $.values is indirect-type(method {
		my $peek = self.peek-one;
		die "Value $peek not a known type tag!" unless %TAG_MAPPING{$peek}:exists;
		return %TAG_MAPPING{$peek};
	});
}

class Parameters is Constructed {
	has StaticData $.static = Buf.new(0xff, 0xff, 0 xx 6);

	has Array[ParamGroup] $.groups;
}

#sub MAIN(IO() $file) {
##	my $b = Parameters.new(Buf.new(
##		0 xx 8, # static
##		0x20, 0, 0, 0, 1, # begin group with one entry
##		0x1, 0xa,
##		0x6, 0, 0, 0, 0xa,
##	));
#
#	my $data = $file.slurp(:bin);
#
#	my $b = Parameters.new($data);
#	$b.parse;
#	say $b;
#}
