DefinitionBlock("", "SSDT", 2, "hack", "XH57", 0)
{
    ///////////////////////////////////////////////////////////////////////
    // SSDT-HDEF : Automatic injection of HDEF properties
    ///////////////////////////////////////////////////////////////////////
    
    External(_SB.PCI0.HDEF, DeviceObj)
    External(RMCF.AUDL, IntObj)
    
    // inject properties for audio
    Method(_SB.PCI0.HDEF._DSM, 4)
    {
        If (CondRefOf(\RMCF.AUDL)) { If (Ones == \RMCF.AUDL) { Return(0) } }
        If (!Arg2) { Return (Buffer() { 0x03 } ) }
        Local0 = Package()
        {
            "layout-id", Buffer(4) { 3, 0, 0, 0 },
            "hda-gfx", Buffer() { "onboard-1" },
            "PinConfigurations", Buffer() { },
        }
        If (CondRefOf(\RMCF.AUDL))
        {
            CreateDWordField(DerefOf(Local0[1]), 0, AUDL)
            AUDL = \RMCF.AUDL
        }
        Return(Local0)
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-IGPU : Automatic injection of IGPU properties
    ///////////////////////////////////////////////////////////////////////
    
    External(_SB.PCI0.IGPU, DeviceObj)
    
    External(RMCF.TYPE, IntObj)
    External(RMCF.HIGH, IntObj)
    
    Scope(_SB.PCI0.IGPU)
    {
        // need the device-id from PCI_config to inject correct properties
        OperationRegion(RMP1, PCI_Config, 0, 0x14)
        Field(RMP1, AnyAcc, NoLock, Preserve)
        {
            Offset(0x02), GDID,16,
            Offset(0x10), BAR1,32,
        }
        // Injection tables for laptops
        Name(LAPL, Package() // low resolution
        {
            // Kaby Lake/HD630
            0x5912, 0, Package()
            {
                "AAPL,ig-platform-id", Buffer() { 0x00, 0x00, 0x16, 0x19 },
                "model", Buffer() { "Intel HD Graphics 630" },
                "device-id", Buffer() { 0x16, 0x19, 0x00, 0x00 },
                "hda-gfx", Buffer() { "onboard-1" },
            },
        })
        Name(LAPH, Package() // high resolution
        {
            // Kaby Lake/HD630
            0x5912, 0, Package()
            {
                "AAPL,ig-platform-id", Buffer() { 0x00, 0x00, 0x16, 0x19 },
                "model", Buffer() { "Intel HD Graphics 630" },
                "device-id", Buffer() { 0x16, 0x19, 0x00, 0x00 },
                "hda-gfx", Buffer() { "onboard-1" },
            },
        })
        
        // Injection tables for desktops
        Name(DESK, Package()
        {
            // Kaby Lake/HD630
            0x5912, 0, Package()
            {
                "AAPL,ig-platform-id", Buffer() { 0x00, 0x00, 0x12, 0x19 },
                "model", Buffer() { "Intel HD Graphics 630" },
                "device-id", Buffer() { 0x12, 0x19, 0x00, 0x00 },
                "hda-gfx", Buffer() { "onboard-1" },
            },
        })
        
        // inject properties for integrated graphics on IGPU
        Method(_DSM, 4)
        {
            If (!Arg2) { Return (Buffer() { 0x03 } ) }
            // determine correct injection table to use based on graphics config in SSDT-Config.aml
            Local0 = LAPL
            if (CondRefOf(\RMCF.TYPE))
            {
                If (0 == \RMCF.TYPE)
                    { Local0 = DESK }
                ElseIf (1 == \RMCF.TYPE)
                {
                    If (CondRefOf(\RMCF.HIGH))
                    {
                        If (0 == \RMCF.HIGH)
                            { Local0 = LAPL }
                        ElseIf (1 == \RMCF.HIGH)
                            { Local0 = LAPH }
                    }
                }
            }
            // search for matching device-id in device-id list
            Local1 = Match(Local0, MEQ, GDID, MTR, 0, 0)
            If (Ones != Local1)
            {
                // start search for zero-terminator (prefix to injection package)
                Local1 = Match(Local0, MEQ, 0, MTR, 0, Local1+1)
                Return (DerefOf(Local0[Local1+1]))
            }
            // should never happen, but inject nothing in this case
            Return (Package() { })
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-LPC : To fix unsupported 100-series LPC devices
    ///////////////////////////////////////////////////////////////////////
    
    External(_SB.PCI0.LPCB, DeviceObj)
    
    Scope(_SB.PCI0.LPCB)
    {
        OperationRegion(RMP2, PCI_Config, 2, 2)
        Field(RMP2, AnyAcc, NoLock, Preserve)
        {
            LDID,16
        }
        Name(LPDL, Package()
        {
            // list of 100-series LPC device-ids not natively supported (partial list)
            0xa144, 0,
            Package()
            {
                "device-id", Buffer() { 0xc1, 0x9c, 0, 0 },
                "compatible", Buffer() { "pci8086,9cc1" },
            },
        })
        Method(_DSM, 4)
        {
            If (!Arg2) { Return (Buffer() { 0x03 } ) }
            // search for matching device-id in device-id list, LPDL
            Local0 = Match(LPDL, MEQ, LDID, MTR, 0, 0)
            If (Ones != Local0)
            {
                // start search for zero-terminator (prefix to injection package)
                Local0 = Match(LPDL, MEQ, 0, MTR, 0, Local0+1)
                Return (DerefOf(LPDL[Local0+1]))
            }
            // if no match, assume it is supported natively... no inject
            Return (Package() { })
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-PluginType1 : Inject plugin-type=1 on _PR.CPU0
    ///////////////////////////////////////////////////////////////////////
    
    External(\_PR.CPU0, DeviceObj)
    Method (\_PR.CPU0._DSM, 4)
    {
        If (!Arg2) { Return (Buffer() { 0x03 } ) }
        Return (Package()
        {
            "plugin-type", 1
        })
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-PNLF : Adding PNLF device for IntelBacklight.kext or
    //             AppleBacklight.kext+AppleBacklightInjector.kext
    ///////////////////////////////////////////////////////////////////////

    #define SANDYIVY_PWMMAX 0x710
    #define HASWELL_PWMMAX 0xad9
    #define SKYLAKE_PWMMAX 0x56c

    External(RMCF.BKLT, IntObj)
    External(RMCF.LMAX, IntObj)

    External(_SB.PCI0.IGPU, DeviceObj)
    Scope(_SB.PCI0.IGPU)
    {
        // need the device-id from PCI_config to inject correct properties
        OperationRegion(IGD5, PCI_Config, 0, 0x14)
    }

    // For backlight control
    Device(_SB.PCI0.IGPU.PNLF)
    {
        Name(_ADR, Zero)
        Name(_HID, EisaId ("APP0002"))
        Name(_CID, "backlight")
        // _UID is set depending on PWMMax
        // 10: Sandy/Ivy 0x710
        // 11: Haswell/Broadwell 0xad9
        // 12: Skylake/KabyLake 0x56c (and some Haswell, example 0xa2e0008)
        // 99: Other
        Name(_UID, 0)
        Name(_STA, 0x0B)

        Field(^IGD5, AnyAcc, NoLock, Preserve)
        {
            Offset(0x02), GDID,16,
            Offset(0x10), BAR1,32,
        }

        OperationRegion(RMB1, SystemMemory, BAR1 & ~0xF, 0xe1184)
        Field(RMB1, AnyAcc, Lock, Preserve)
        {
            Offset(0x48250),
            LEV2, 32,
            LEVL, 32,
            Offset(0x70040),
            P0BL, 32,
            Offset(0xc8250),
            LEVW, 32,
            LEVX, 32,
            Offset(0xe1180),
            PCHL, 32,
        }

        Method(_INI)
        {
            // IntelBacklight.kext takes care of this at load time...
            // If RMCF.BKLT does not exist, it is assumed you want to use AppleBacklight.kext...
            If (CondRefOf(\RMCF.BKLT)) { If (1 != \RMCF.BKLT) { Return } }

            // Adjustment required when using AppleBacklight.kext
            Local0 = GDID
            Local2 = Ones
            if (CondRefOf(\RMCF.LMAX)) { Local2 = \RMCF.LMAX }

            If (Ones != Match(Package()
                {
                    // Sandy
                    0x0116, 0x0126, 0x0112, 0x0122,
                    // Ivy
                    0x0166, 0x016a,
                    // Arrandale
                    0x42, 0x46
                }, MEQ, Local0, MTR, 0, 0))
            {
                // Sandy/Ivy
                if (Ones == Local2) { Local2 = SANDYIVY_PWMMAX }

                // change/scale only if different than current...
                Local1 = LEVX >> 16
                If (!Local1) { Local1 = Local2 }
                If (Local2 != Local1)
                {
                    // set new backlight PWMMax but retain current backlight level by scaling
                    Local0 = (LEVL * Local2) / Local1
                    //REVIEW: wait for vblank before setting new PWM config
                    //For (Local7 = P0BL, P0BL == Local7, ) { }
                    Local3 = Local2 << 16
                    If (Local2 > Local1)
                    {
                        // PWMMax is getting larger... store new PWMMax first
                        LEVX = Local3
                        LEVL = Local0
                    }
                    Else
                    {
                        // otherwise, store new brightness level, followed by new PWMMax
                        LEVL = Local0
                        LEVX = Local3
                    }
                }
            }
            Else
            {
                // otherwise... Assume Haswell/Broadwell/Skylake
                if (Ones == Local2)
                {
                    // check Haswell and Broadwell, as they are both 0xad9 (for most common ig-platform-id values)
                    If (Ones != Match(Package()
                        {
                            // Haswell
                            0x0d26, 0x0a26, 0x0d22, 0x0412, 0x0416, 0x0a16, 0x0a1e, 0x0a1e, 0x0a2e, 0x041e, 0x041a,
                            // Broadwell
                            0x0BD1, 0x0BD2, 0x0BD3, 0x1606, 0x160e, 0x1616, 0x161e, 0x1626, 0x1622, 0x1612, 0x162b,
                        }, MEQ, Local0, MTR, 0, 0))
                    {
                        Local2 = HASWELL_PWMMAX
                    }
                    Else
                    {
                        // assume Skylake/KabyLake, both 0x56c
                        // 0x1916, 0x191E, 0x1926, 0x1927, 0x1912, 0x1932, 0x1902, 0x1917, 0x191b,
                        // 0x5916, 0x5912, 0x591b, others...
                        Local2 = SKYLAKE_PWMMAX
                    }
                }

                // This 0xC value comes from looking what OS X initializes this\n
                // register to after display sleep (using ACPIDebug/ACPIPoller)\n
                LEVW = 0xC0000000

                // change/scale only if different than current...
                Local1 = LEVX >> 16
                If (!Local1) { Local1 = Local2 }
                If (Local2 != Local1)
                {
                    // set new backlight PWMAX but retain current backlight level by scaling
                    Local0 = (((LEVX & 0xFFFF) * Local2) / Local1) | (Local2 << 16)
                    //REVIEW: wait for vblank before setting new PWM config
                    //For (Local7 = P0BL, P0BL == Local7, ) { }
                    LEVX = Local0
                }
            }

            // Now Local2 is the new PWMMax, set _UID accordingly
            // The _UID selects the correct entry in AppleBacklightInjector.kext
            If (Local2 == SANDYIVY_PWMMAX) { _UID = 14 }
            ElseIf (Local2 == HASWELL_PWMMAX) { _UID = 15 }
            ElseIf (Local2 == SKYLAKE_PWMMAX) { _UID = 16 }
            Else { _UID = 99 }
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-PRW : For solving instant wake by hooking GPRW or UPRW
    ///////////////////////////////////////////////////////////////////////

    External(XPRW, MethodObj)

    // In DSDT, native GPRW is renamed to XPRW with Clover binpatch.
    // (or UPRW to XPRW)
    // As a result, calls to GPRW (or UPRW) land here.
    // The purpose of this implementation is to avoid "instant wake"
    // by returning 0 in the second position (sleep state supported)
    // of the return package.
    Method(GPRW, 2)
    {
        If (0x6d == Arg0) { Return (Package() { 0x6d, 0, }) }
        If (0x0d == Arg0) { Return (Package() { 0x0d, 0, }) }
        Return (XPRW(Arg0, Arg1))
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-SMBUS : Adding SMBUS device
    ///////////////////////////////////////////////////////////////////////

    Device(_SB.PCI0.SBUS.BUS0)
    {
        Name(_CID, "smbus")
        Name(_ADR, Zero)
        Device(DVL0)
        {
            Name(_ADR, 0x57)
            Name(_CID, "diagsvault")
            Method(_DSM, 4)
            {
                If (!Arg2) { Return (Buffer() { 0x03 } ) }
                Return (Package() { "address", 0x57 })
            }
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-XHC : Automatic injection of XHC properties
    ///////////////////////////////////////////////////////////////////////
    
    External(_SB.PCI0.XHC, DeviceObj)

    // inject properties for XHCI
    If (CondRefOf(_SB.PCI0.XHC))
    {
        Method(_SB.PCI0.XHC._DSM, 4)
        {
            If (!Arg2) { Return (Buffer() { 0x03 } ) }
            Local0 = Package()
            {
                "RM,pr2-force", Buffer() { 0, 0, 0, 0 },
                "subsystem-id", Buffer() { 0x70, 0x72, 0x00, 0x00 },
                "subsystem-vendor-id", Buffer() { 0x86, 0x80, 0x00, 0x00 },
                "AAPL,current-available", Buffer() { 0x34, 0x08, 0, 0 },
                "AAPL,current-extra", Buffer() { 0x98, 0x08, 0, 0, },
                "AAPL,current-extra-in-sleep", Buffer() { 0x40, 0x06, 0, 0, },
                "AAPL,max-port-current-in-sleep", Buffer() { 0x34, 0x08, 0, 0 },
            }
            // force USB2 on XHC if EHCI is disabled
            If (CondRefOf(\_SB.PCI0.RMD2) || CondRefOf(\_SB.PCI0.RMD3) || CondRefOf(\_SB.PCI0.RMD4))
            {
                CreateDWordField(DerefOf(Local0[1]), 0, PR2F)
                PR2F = 0x3fff
            }
            Return(Local0)
        }
    }


    ///////////////////////////////////////////////////////////////////////
    // SSDT-XOSI : Override for host defined _OSI to handle "Darwin"...
    ///////////////////////////////////////////////////////////////////////
    
    // All _OSI calls in DSDT are routed to XOSI...
    // XOSI simulates "Windows 2009" (which is Windows 7)
    // Note: According to ACPI spec, _OSI("Windows") must also return true
    //  Also, it should return true for all previous versions of Windows.
    Method(XOSI, 1)
    {
        // simulation targets
        // source: (google 'Microsoft Windows _OSI')
        //  http://download.microsoft.com/download/7/E/7/7E7662CF-CBEA-470B-A97E-CE7CE0D98DC2/WinACPI_OSI.docx
        Local0 = Package()
        {
            "Windows",              // generic Windows query
            "Windows 2001",         // Windows XP
            "Windows 2001 SP2",     // Windows XP SP2
            //"Windows 2001.1",     // Windows Server 2003
            //"Windows 2001.1 SP1", // Windows Server 2003 SP1
            "Windows 2006",         // Windows Vista
            "Windows 2006 SP1",     // Windows Vista SP1
            "Windows 2006.1",       // Windows Server 2008
            "Windows 2009",         // Windows 7/Windows Server 2008 R2
            "Windows 2012",         // Windows 8/Windows Server 2012
            "Windows 2013",         // Windows 8.1/Windows Server 2012 R2
            "Windows 2015",         // Windows 10/Windows Server TP
        }
        Return (Ones != Match(Local0, MEQ, Arg0, MTR, 0, 0))
    }
    
    
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


    ///////////////////////////////////////////////////////////////////////
    // SSDT-ARPT : Make use of ARPT device
    ///////////////////////////////////////////////////////////////////////

    External (_SB.PCI0.RP04.PXSX, DeviceObj)
    Scope (_SB.PCI0.RP04.PXSX)
    {
        Name (_STA, Zero)
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


    Scope (\_SB)
    {
        Device (USBX)
        {
            Name (_ADR, Zero)
            Method (_DSM, 4, NotSerialized)
            {
                If (!Arg2) { Return (Buffer() { 0x03 } ) }
                Return (Package ()
                {
                    // From : /S/L/E/IOUSBHostFamily.kext/C/Info.plist - MacBookPro12,1
                    "kUSBSleepPortCurrentLimit", 2100,
                    "kUSBSleepPowerSupply", 2600,
                    "kUSBWakePortCurrentLimit", 2100,
                    "kUSBWakePowerSupply", 3200,
                })
            }
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
        Device (ALS0)
        {
            Name (_HID, "ACPI0008")
            Name (_CID, "smc-als")
            Name (BUFF, Buffer (0x02) {})
            CreateByteField (BUFF, Zero, OB0)
            CreateByteField (BUFF, One, OB1)
            CreateWordField (BUFF, Zero, ALSI)
            Method (_STA, 0, NotSerialized) { Return (0x0F) }
            Method (_ALI, 0, NotSerialized)
            {
                OB0 = 0x0A
                OB1 = Zero
                Local0 = ALSI
                Return (Local0)
            }
            Name (_ALR, Package (0x05)
            {
                Package (0x02) { 0x0A, Zero },
                Package (0x02) { 0x14, 0x0A },
                Package (0x02) { 0x32, 0x50 },
                Package (0x02) { 0x5A, 0x012C },
                Package (0x02) { 0x64, 0x03E8 },
            })
        }
    }
}
//EOF
