use v6;
use v6.c;

=begin pod

=head1 NAME

BinaryScanner - read and write binary formats with class definitions

=head1 SYNOPSIS

	use BinaryScanner;

	class PascalString is Constructed {
		has uint8 $!length is written(method {$!string.bytes});
		has Buf $.string is read(method {self.pull($!length)}) is rw;
	}

	my $parser = PascalString.new;
	$parser.parse(Buf.new("\x05hello world".ords));
	say $parser.string; # "hello"

=end pod

use experimental :pack;

my role ConstructedAttributeHelper {
	has Routine $.reader is rw;
	has Routine $.writer is rw;
	has Routine $.indirect-type is rw;
}

multi sub trait_mod:<is>(Attribute:D $a, :$read!) is export {
	$a does ConstructedAttributeHelper;
	$a.reader = $read;
}

multi sub trait_mod:<is>(Attribute:D $a, :$written!) is export {
	$a does ConstructedAttributeHelper;
	$a.writer = $written;
}

multi sub trait_mod:<is>(Attribute:D $a, :$indirect-type!) is export {
	$a does ConstructedAttributeHelper;
	$a.indirect-type = $indirect-type;
}

# XXX: maybe these should be subclasses
subset StaticData of Blob;
subset AutoData of Any;

class ElementCount is Int {}

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

	method peek-one {
		return $!data[$!pos];
	}

	method peek(Int $count) {
		my $subbuf = $!data.subbuf($!pos, $count);
		return $subbuf;
	}

	method pull(Int $count) {
		my $subbuf = $!data.subbuf($!pos, $count);
		$!pos += $count;
		return $subbuf;
	}

	#= Helper method for reader methods to indicate a certain number of
	# elements rather than a certain number of bytes
	method pull-elements(Int $count) returns ElementCount {
		return ElementCount.new($count);
	}

	method !inline-parse($attr, $inner-type is copy) {
#		if %indirect-type{$attr}:exists {
#			$inner-type = %indirect-type{$attr}(self);
#		}
		my $inner = $inner-type.new;
		$inner.parse($!data, :$!pos, :parent(self));
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

	# Since Attribute.set_value apparently binds, we need to give it a
	# container. Handle that icky step here.
	method !set-attr-value-rw($attr, $value) {
		$attr.set_value(self, (my $ = $value));
	}

	method parse(Blob $data, Int :$pos=0, Constructed :$parent) {
		$!data = $data;
		$!pos = $pos;
		$!parent = $parent;

		my @attrs = self.^attributes(:local);
		die "{self} has no attributes!" unless @attrs;
		for @attrs -> $attr {
			given $attr.type {
				when Constructed {
					my $inner-type = $attr.type;
					my $inner = self!inline-parse($attr, $inner-type);
					die "Mismatch!" unless $inner;

					$attr.set_value(self, $inner);
				}

				when Array {
					unless $attr.type.of ~~ Constructed {
						die "whoa, can't handle a $attr.type.gist() yet :(";
					}
					die "no reader for $attr.gist()" unless $attr.reader;
					my $limit = $attr.reader.(self);
					my $limit-type = 'bytes';
					if $limit ~~ Buf {
						die "XXX: Bufs for readers for arrays NYI";
					}

					my @array = $attr.type.new;

					# This attr must know when to stop somehow...
					my $inner-type = $attr.type.of;

					if $limit ~~ ElementCount {
						for ^$limit {
							# prevent out of bounds...
							die "$attr.gist(): read past end of buffer!" if $!pos >= $!data.bytes;
							my $inner = self!inline-parse($attr, $inner-type);
							@array.push($inner);
						}
					} else {
						my $initial-pos = $!pos;
						while $!pos - $initial-pos < $limit {
							die "$attr.gist(): read past end of buffer!" if $!pos >= $!data.bytes;
							my $inner = self!inline-parse($attr, $inner-type);
							@array.push($inner);
						}

						# XXX: maybe this should be a warning
						die "$attr.gist(): read too many bytes!" if $limit < $!pos - $initial-pos;
					}

					$attr.set_value(self, @array);
				}

				when uint | int {
					die "Unsupported type: $attr.gist(): cannot use native types without length";
				}
				when uint8 {
					# manual cast to uint8 is needed to handle bounds
					self!set-attr-value-rw($attr, (my uint8 $ = self.pull(1)[0]));
				}
				when uint16 {
					# manual cast to uint16 is needed to handle bounds
					self!set-attr-value-rw($attr, (my uint16 $ = self.pull(2).unpack('v')));
				}
				when uint32 {
					# manual cast to uint32 is needed to handle bounds
					self!set-attr-value-rw($attr, (my uint32 $ = self.pull(4).unpack('V')));
				}
				when int8 {
					self!set-attr-value-rw($attr, self.pull(1)[0]);
				}
				when int16 {
					self!set-attr-value-rw($attr, self.pull(2).unpack('v'));
				}
				when int32 {
					self!set-attr-value-rw($attr, self.pull(4).unpack('V'));
				}
				when Int {
					die "Unsupported type: $attr.gist(): cannot use object Int types without length";
				}

				when Buf {
					die "no reader for $attr.gist()" unless $attr.reader;
					my $data = $attr.reader.(self);
					self!set-attr-value-rw($attr, $data);
				}

				when StaticData {
					my $e = $attr.get_value(self);
					my $g = self.pull($e.bytes);

					if $g ne $e {
						die X::Constructed::StaticMismatch.new(got => $g, expected => $e);
					}
				}

				when AutoData {
					# XXX: factor into Buf above?
					die "no reader for $attr.gist()" unless $attr.reader;
					my $data = $attr.reader.(self);
					self!set-attr-value-rw($attr, $data);
				}

				default {
					die "Cannot read an attribute of type $_.gist() yet!";
				}
			}
		}
	}

	method !get-attr-value($attr) {
		if $attr ~~ ConstructedAttributeHelper && $attr.writer {
			return $attr.writer.(self);
		}
		return $attr.get_value(self);
	}

	method build() returns Blob {
		my Buf $buf .= new;

		my @attrs = self.^attributes(:local);
		die "{self} has no attributes!" unless @attrs;
		for @attrs -> $attr {
			given $attr.type {
				when uint8 {
					$buf.push: self!get-attr-value($attr);
				}
				when uint16 {
					$buf.push: pack('v', self!get-attr-value($attr));
				}
				when uint32 {
					$buf.push: pack('V', self!get-attr-value($attr));
				}
				when int8 {
					$buf.push: self!get-attr-value($attr);
				}
				when int16 {
					$buf.push: pack('v', self!get-attr-value($attr));
				}
				when int32 {
					$buf.push: pack('V', self!get-attr-value($attr));
				}
				when Buf | StaticData {
					$buf.push: |self!get-attr-value($attr);
				}
				when Array | Constructed {
					my $inner = self!get-attr-value($attr);
					$buf.push: .build for $inner.list;
				}
				default {
					die "Cannot write an attribute of type $_.gist() yet!";
				}
			}
		}

		return $buf;
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

class AnyFile is Constructed {
	has Buf $.stuff is read(method {
		note "got here already? {self}";
		return $.data.bytes;
	});
}
