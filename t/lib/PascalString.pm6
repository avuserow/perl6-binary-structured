use BinaryScanner;

class PascalString is Constructed {
	has uint8 $.length is written(method {$.string.bytes});
	has Buf $.string is read(method {self.pull($.length)}) is rw;
}
