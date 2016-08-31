use BinaryScanner;

class PascalString is Constructed {
	has uint8 $.length;
	has Buf $.string is read(method {self.pull($.length)});
}

