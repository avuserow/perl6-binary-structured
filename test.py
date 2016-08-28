#!/usr/bin/env python

from construct import *
import sys

PARAMETERS = Struct("ParametersFile",
    Const(Bytes("magic", 8), b"\xff\xff\x00\x00\x00\x00\x00\x00"),
    Struct("Group",
        Const(Bytes("tag", 1), b"\x20"),
        UBInt32("length"),
        GreedyRange(
            Struct("Value",
                Enum(Byte("tag"),
                    ParamValueUint8   = 0x1,
                    ParamValueInt8    = 0x2,
                    ParamValueUint16  = 0x3,
                    ParamValueInt16   = 0x4,
                    ParamValueUint32  = 0x5,
                    ParamValueInt32   = 0x6,
                    ParamValueFloat32 = 0x7,
                    ParamValueStr     = 0x8,
                ),
                Switch("data", lambda ctx: ctx.tag, dict(
                    ParamValueUint8   = UBInt8("value"),
                    ParamValueInt8    = UBInt8("value"),
                    ParamValueUint16  = UBInt16("value"),
                    ParamValueInt16   = UBInt16("value"),
                    ParamValueUint32  = UBInt32("value"),
                    ParamValueInt32   = UBInt32("value"),
                    ParamValueFloat32 = UBInt32("value"),
                    # ParamValueStr     = 0x8,
                )),
            ),
        ),
    ),
    Terminator,
)

def main(args):
    with open(args[0], 'rb') as fh:
        data = fh.read()
    b = PARAMETERS.parse(data)
    print(b)

main(sys.argv[1:])
