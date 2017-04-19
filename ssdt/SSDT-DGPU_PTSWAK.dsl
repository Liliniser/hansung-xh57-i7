DefinitionBlock("", "SSDT", 2, "hack", "DGPU", 0)
{
    ///////////////////////////////////////////////////////////////////////
    // SSDT-Disable_DGPU : For disabling the discrete GPU
    ///////////////////////////////////////////////////////////////////////

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


    ///////////////////////////////////////////////////////////////////////
    // SSDT-PTSWAK : Overriding _PTS and _WAK
    ///////////////////////////////////////////////////////////////////////
    
    External(ZPTS, MethodObj)
    External(ZWAK, MethodObj)

    External(_SB.PCI0.PEG0.PEGP._ON, MethodObj)
    // Note: invoke the original _OFF() method this time
    External(_SB.PCI0.PEG0.PEGP.XOFF, MethodObj)

    External(RMCF.DPTS, IntObj)
    External(RMCF.SHUT, IntObj)

    // In DSDT, native _PTS and _WAK are renamed ZPTS/ZWAK
    // As a result, calls to these methods land here.
    Method(_PTS, 1)
    {
        // Shutdown fix, if enabled
        If (CondRefOf(\RMCF.SHUT)) { If (\RMCF.SHUT && 5 == Arg0) { Return } }

        If (CondRefOf(\RMCF.DPTS))
        {
            If (\RMCF.DPTS)
            {
                // enable discrete graphics
                If (CondRefOf(\_SB.PCI0.PEG0.PEGP._ON)) { \_SB.PCI0.PEG0.PEGP._ON() }
            }
        }

        // call into original _PTS method
        ZPTS(Arg0)
    }
    Method(_WAK, 1)
    {
        // Take care of bug regarding Arg0 in certain versions of OS X...
        // (starting at 10.8.5, confirmed fixed 10.10.2)
        If (Arg0 < 1 || Arg0 > 5) { Arg0 = 3 }

        // call into original _WAK method
        Local0 = ZWAK(Arg0)

        If (CondRefOf(\RMCF.DPTS))
        {
            If (\RMCF.DPTS)
            {
                // disable discrete graphics
                If (CondRefOf(\_SB.PCI0.PEG0.PEGP.XOFF)) { \_SB.PCI0.PEG0.PEGP.XOFF() }
            }
        }

        // return value from original _WAK
        Return (Local0)
    }
}
//EOF
