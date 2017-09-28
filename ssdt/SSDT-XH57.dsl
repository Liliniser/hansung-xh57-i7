DefinitionBlock("", "SSDT", 2, "hack", "XH57", 0)
{    
    ///////////////////////////////////////////////////////////////////////
    // SSDT-NVMe-Pcc
    ///////////////////////////////////////////////////////////////////////
    
    External(_SB.PCI0.RP09.PXSX, DeviceObj)
    Method(_SB.PCI0.RP09.PXSX._DSM, 4)
    {
        If (!Arg2) { Return (Buffer() { 0x03 } ) }
        Return(Package()
        {
            "class-code", Buffer() { 0xff, 0x08, 0x01, 0x00 },
            "built-in", Buffer() { 0 },
        })
    }
    
    External(_SB.PCI0.RP13.PXSX, DeviceObj)
    Method(_SB.PCI0.RP13.PXSX._DSM, 4)
    {
        If (!Arg2) { Return (Buffer() { 0x03 } ) }
        Return(Package()
        {
            "class-code", Buffer() { 0xff, 0x08, 0x01, 0x00 },
            "built-in", Buffer() { 0 },
        })
    }
    
    
    ///////////////////////////////////////////////////////////////////////
    // SSDT-MCHC
    ///////////////////////////////////////////////////////////////////////
    
    Device (_SB.PCI0.MCHC)
    {
        Name (_ADR, Zero)  // _ADR: Address
    }
    
    
    ///////////////////////////////////////////////////////////////////////
    // SSDT-PS2K
    ///////////////////////////////////////////////////////////////////////
    
    External (_SB.PCI0.LPCB.PS2K, DeviceObj)
    Scope (_SB.PCI0.LPCB.PS2K)
    {
        // overrides for VoodooPS2 configuration...
        Name (RMCF, Package ()
        {
            "Controller", Package()
            {
                "WakeDelay", 0,
            },
            "Sentelic FSP", Package()
            {
                "DisableDevice", ">y",
            },
            "ALPS GlidePoint", Package()
            {
                "DisableDevice", ">y",
            },
            "Mouse", Package()
            {
                "DisableDevice", ">y",
            },
            "Synaptics TouchPad", Package()
            {
                "DynamicEWMode", ">y",
                "MultiFingerVerticalDivisor", 9,
                "MultiFingerHorizontalDivisor", 9,
                "MomentumScrollThreshY", 12,
            },
            "Keyboard", Package()
            {
                "Breakless PS2", Package()
                {
                    Package(){}, // indicates array
                    "e06a",
                },
                "MaximumMacroTime", 25000000,
                "Macro Inversion", Package()
                {
                    Package(){},
                    // Fn+F7
                    Buffer() { 0xff, 0xff, 0x02, 0x6a, 0x00, 0x00, 0x00, 0x00, 0x02, 0x5b, 0x01, 0x19 },
                    Buffer() { 0xff, 0xff, 0x02, 0xea, 0x00, 0x00, 0x00, 0x00, 0x01, 0x99, 0x02, 0xdb },
                },
                "Custom ADB Map", Package()
                {
                    Package(){},
                    "e06a=70", // video mirror
                },
                "Custom PS2 Map", Package()
                {
                    Package(){},
                    "e037=64", // PrtScr=F13
                    "e045=68", // PauseBreak=F18
                },
            },
        })
    }

    External (_SB.PCI0.LPCB.EC, DeviceObj)
    Scope (_SB.PCI0.LPCB.EC)
    {
        // Fn + F1 : Toggle touchpad
        Method (_Q0A, 0, NotSerialized)
        {
            // e028 : Toggle touchpad (via VoodooPS2Controller)
            Notify (\_SB.PCI0.LPCB.PS2K, 0x0428)
        }
        // Fn + F8 : Brightness down
        Method (_Q11, 0, NotSerialized)
        {
            // e005 : Brightness down
            Notify (\_SB.PCI0.LPCB.PS2K, 0x0405)
        }
        // Fn + F9 : Brightness up
        Method (_Q12, 0, NotSerialized)
        {
            // e006 : Brightness up
            Notify (\_SB.PCI0.LPCB.PS2K, 0x0406)
        }
    }
    
    
    ///////////////////////////////////////////////////////////////////////
    // SSDT-UIAC : UsbInjectAll properties customization
    ///////////////////////////////////////////////////////////////////////
    
    Device (UIAC)
    {
        Name (_HID, "UIA00000")
        Name (RMCF, Package ()
        {
            "8086_a12f", Package ()
            {
                "port-count", Buffer() { 26, 0, 0, 0 },
                "ports", Package ()
                {
                    "HS01", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 1, 0, 0, 0 },
                    },
                    "HS02", Package()
                    {
                        "UsbConnector", 255, // Internal : Webcam
                        "port", Buffer() { 2, 0, 0, 0 },
                    },
                    "HS03", Package()
                    {
                        "UsbConnector", 255, // Internal : Bluetooth
                        "port", Buffer() { 3, 0, 0, 0 },
                    },
                    "HS06", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 6, 0, 0, 0 },
                    },
                    "HS09", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 9, 0, 0, 0 },
                    },
                    "HS11", Package()
                    {
                        "UsbConnector", 0, // USB 2 port
                        "port", Buffer() { 11, 0, 0, 0 },
                    },
                    "SS01", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 17, 0, 0, 0 },
                    },
                    "SS02", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 18, 0, 0, 0 },
                    },
                    "SS06", Package()
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 22, 0, 0, 0 },
                    },
                },
            },
        })
    }

    // Copied from MacBookPro14,1 DSDT.aml
    Device(_SB.USBX)
    {
        Name(_ADR, 0)
        Method (_DSM, 4)
        {
            If (!Arg2) { Return (Buffer() { 0x03 } ) }
            Return (Package()
            {
                "kUSBSleepPortCurrentLimit", 3000,
                "kUSBWakePortCurrentLimit", 3000,
            })
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-ARPT : Make use of ARPT device
    ///////////////////////////////////////////////////////////////////////

    External (_SB.PCI0.RP04.PXSX, DeviceObj)
    Scope (_SB.PCI0.RP04.PXSX)
    {
        Name (_STA, Zero)
    }

    External(_SB.PCI0.RP04.ARPT, DeviceObj)
    Method(_SB.PCI0.RP04.ARPT._DSM, 4)
    {
        If (!Arg2) { Return (Buffer() { 0x03 } ) }
        Return(Package()
        {
            "compatible", "pci14e4,43a0",
        })
    }


    ///////////////////////////////////////////////////////////////////////
    // Experimental
    ///////////////////////////////////////////////////////////////////////

    External (_SB.AC, DeviceObj)

    // It seems like boot rarely fails with following errors
    //   ACPI Error: [\_PR_.CPU0._PSS] Namespace lookup failure. AE_NOT_FOUND
    //   ACPI Error: Method parse/execution failed [\_SB_.AC__.ADJP]
    //   ACPI Error: Method parse/execution failed [\_SB_.AC__.PSR]
    // It needs to be verified whether ignoring ADJP is helpful and doesn't harm. 
    Scope (_SB.AC)
    {
        // In DSDT, native ADJP is renamed to XDJP with Clover binpatch.
        Method (ADJP, 1)
        {
        }
    }


    // https://github.com/syscl/XPS9350-macOS/blob/master/DSDT/patches/syscl_SLPB.txt
    External (_SB.SLPB, DeviceObj)
    Scope (_SB.SLPB) { Name (_STA, 0x0B) }


    // https://github.com/syscl/XPS9350-macOS/blob/master/DSDT/patches/syscl_DMAC.txt
    External (_SB.PCI0.LPCB, DeviceObj)
    Scope (_SB.PCI0.LPCB)
    {
        Device (DMAC)
        {
            Name (_HID, EisaId ("PNP0200"))
            Name (_CRS, ResourceTemplate ()
            {
                IO (Decode16,
                    0x0000,
                    0x0000,
                    0x01,
                    0x20,
                    )
                IO (Decode16,
                    0x0081,
                    0x0081,
                    0x01,
                    0x11,
                    )
                IO (Decode16,
                    0x0093,
                    0x0093,
                    0x01,
                    0x0D,
                    )
                IO (Decode16,
                    0x00C0,
                    0x00C0,
                    0x01,
                    0x20,
                    )
                DMA (Compatibility, NotBusMaster, Transfer8_16, )
                    {4}
            })
        }
    }
}
//EOF
