use BinaryScanner;

class CString is Constructed {
	has Buf $.string is read(method {
		# TODO: read more efficiently
		my $c = Buf.new;
		$c ~= self.pull(1) while self.peek-one != 0;
		return $c;
	});

	has StaticData $.terminator = Buf.new: 0;
}

