// For disabling the discrete GPU

DefinitionBlock("", "SSDT", 2, "hack", "D-DGPU", 0)
{
    External (P80H, UnknownObj)
    External (_SB.PCI0.PGOF, MethodObj)

    External (_SB.PCI0.PEG0.PEGP, DeviceObj)
    External (_SB.PCI0.PEG0.PEGP.CTXT, UnknownObj)
    External (_SB.PCI0.PEG0.PEGP.GPRF, UnknownObj)
    External (_SB.PCI0.PEG0.PEGP.VGAB, UnknownObj)
    External (_SB.PCI0.PEG0.PEGP.VGAR, IntObj)

    Scope (_SB.PCI0.PEG0.PEGP)
    {
        // There's no _INI in PEGP
        Method (_INI, 0, NotSerialized)
        {
            _OFF()
        }
        // native _OFF in DSDT is renamed to XOFF by clover patch
        Method (_OFF, 0)
        {
            P80H = 0x8E
            // Below codes are moved to _REG (look at the bottom)
            // Local0 = \_SB.PCI0.LPCB.EC.AIRP
            // Local0 &= 0x7F
            // \_SB.PCI0.LPCB.EC.AIRP = Local0
            If ((CTXT == Zero))
            {
                If ((GPRF != One))
                {
                    VGAB = VGAR
                }
                CTXT = One
            }

            PGOF (Zero)
            P80H = 0x8F
        }
    }

    /*
       PNOT() is invoked from only two methods:
       One is ADJP() and the other is EC._REG()
       Codes accessing EC from PEGP._OFF() should be moved to _REG()
       but since ADJP() method is disabled, PNOT() can be used
       as a substitution of _REG().

       Actually, this might not be needed at all as AIRP seems to be zero anyway
       either with or without this method.

       Strangely, calling PEGP._OFF() directly from _INI() also seems to work,
       but still following the instruction just in case.

       NOTE: native PNOT in DSDT is renamed to XNOT by clover patch
    */
    External (_SB.PCI0.LPCB.EC.AIRP, IntObj)
    External (XNOT, MethodObj)
    Method (PNOT, 0)
    {
        Local0 = \_SB.PCI0.LPCB.EC.AIRP
        Local0 &= 0x7F
        \_SB.PCI0.LPCB.EC.AIRP = Local0
        XNOT()
    }
}
//EOF
