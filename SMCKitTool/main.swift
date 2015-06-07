//
// OS X SMC Tool
//
// SMCKitTool/main.swift
// SMCKit
//
// The MIT License
//
// Copyright (C) 2015  beltex <http://beltex.github.io>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import IOKit

// Not using the following as frameworks, but as source files. See README.md for
// more
//import CommandLine
//import SMCKit

//------------------------------------------------------------------------------
// MARK: GLOBALS
//------------------------------------------------------------------------------

let SMCKitToolVersion = "0.0.1"
let argCount = Process.arguments.count
let displaySMCKeys: Bool

//------------------------------------------------------------------------------
// MARK: COMMAND LINE INTERFACE
//------------------------------------------------------------------------------

let CLITemperatureFlag = BoolOption(shortFlag: "t", longFlag: "temperature",
                                    helpMessage: "Show temperature sensors.")
let CLIFanFlag         = BoolOption(shortFlag: "f", longFlag: "fan",
                                    helpMessage: "Show fan speeds.")
let CLIPowerFlag       = BoolOption(shortFlag: "p", longFlag: "power",
                                    helpMessage: "Show power information.")
let CLIMiscFlag        = BoolOption(shortFlag: "m", longFlag: "misc",
                                    helpMessage: "Show misc. information.")
let CLICheckKey        = StringOption(shortFlag: "k", longFlag: "check-key",
                                      required: false,
             helpMessage: "Check if FourCC is a valid SMC key on this machine.")
let CLIDisplayKeysFlag = BoolOption(shortFlag: "d", longFlag: "display-keys",
                helpMessage: "Show SMC keys when printing temperature sensors.")
let CLIFanNumberFlag   = IntOption(shortFlag: "n", longFlag: "fan-number",
                  required: false, helpMessage: "The number of the fan to set.")
let CLIFanSpeedFlag    = IntOption(shortFlag: "s", longFlag: "fan-speed",
         required: false, helpMessage: "The min speed (RPM) of the fan to set.")
let CLIHelpFlag        = BoolOption(shortFlag: "h", longFlag: "help",
               helpMessage: "Show the help message (list of options) and exit.")
let CLIVersionFlag     = BoolOption(shortFlag: "v", longFlag: "version",
                                   helpMessage: "Show smckit version and exit.")

let CLIOptions = [CLITemperatureFlag, CLIFanFlag, CLIPowerFlag,
                                                  CLIMiscFlag,
                                                  CLICheckKey,
                                                  CLIDisplayKeysFlag,
                                                  CLIFanNumberFlag,
                                                  CLIFanSpeedFlag,
                                                  CLIHelpFlag,
                                                  CLIVersionFlag]

let CLI = CommandLine()
CLI.addOptions(CLIOptions)

let (success, error) = CLI.parse()
if !success {
    println(error!)
    CLI.printUsage()
    exit(EX_USAGE)
}

// Give precedence to help flag
if CLIHelpFlag.value {
    CLI.printUsage()
    exit(EX_USAGE)
}
else if CLIVersionFlag.value {
    println(SMCKitToolVersion)
    exit(EX_USAGE)
}

if CLIDisplayKeysFlag.value { displaySMCKeys = true  }
else                        { displaySMCKeys = false }

let isSetNonBoolOptions = CLIOptions.filter({ $0.isSet == true &&
                                              $0 as? BoolOption == nil})
let isSetBoolOptions = CLIOptions.filter({ $0 as? BoolOption != nil })
                                 .map({$0 as! BoolOption})
                                 .filter({ $0.value == true})

//------------------------------------------------------------------------------
// MARK: FUNCTIONS
//------------------------------------------------------------------------------

func printTemperatureInformation() {
    println("-- TEMPERATURE --")
    let temperatureSensors = smc.getAllValidTemperatureKeys()

    for key in temperatureSensors {
        let temperatureSensorName = SMC.Temperature.allValues[key]!
        let temperature           = smc.getTemperature(key).tmp

        let smcKey = displaySMCKeys ? String("(" + key.rawValue + ")") : ""

        println("\(temperatureSensorName) \(smcKey)")
        println("\t\(temperature)°C")
    }
}

func printFanInformation() {
    println("-- FAN --")
    let fanCount = smc.getNumFans().numFans

    if fanCount == 0 { println("** Fanless **") }
    else {
        for var i: UInt = 0; i < fanCount; ++i {
            let name    = smc.getFanName(i).name
            let current = smc.getFanRPM(i).rpm
            let min     = smc.getFanMinRPM(i).rpm
            let max     = smc.getFanMaxRPM(i).rpm

            println("[\(i)] \(name)")
            println("\tCurrent:  \(current) RPM")
            println("\tMin:      \(min) RPM")
            println("\tMax:      \(max) RPM")
        }
    }
}

func printPowerInformation() {
    println("-- POWER --")
    println("AC Present:          \(smc.isACPresent().flag)")
    println("Battery Powered:     \(smc.isBatteryPowered().flag)")
    println("Charging:            \(smc.isCharging().flag)")
    println("Battery Ok:          \(smc.isBatteryOk().flag)")
    println("Max Batteries:       \(smc.maxNumberBatteries().count)")
}

func printMiscInformation() {
    println("-- MISC --")
    println("Disc in ODD:         \(smc.isOpticalDiskDriveFull().flag)")
}

func printAll() {
    printTemperatureInformation()
    printFanInformation()
    printPowerInformation()
    printMiscInformation()
}

func checkKey(key: String) {
    if smc.isKeyValid(key).valid { println("VALID") }
    else                         { println("INVALID") }
}

func setMinFanSpeed(fanNumber: Int, fanSpeed: Int) {
    let result = smc.setFanMinRPM(UInt(fanNumber), RPM: UInt(fanSpeed))

    if result.result { println("SUCCESS") }
    else if result.IOReturn == kIOReturnNotPrivileged {
        println("This operation must be invoked as the superuser")
    }
    else if result.IOReturn == kIOReturnBadArgument {
        let maxSpeed = smc.getFanMaxRPM(UInt(fanNumber)).rpm
        println("Invalid fan speed. Must be <= max fan speed (\(maxSpeed))")
    }
    else if result.kSMC == SMC.kSMC.kSMCKeyNotFound.rawValue {
        println("This machine has no fan #\(fanNumber)")
    }
    else {
        println("FAILED: IOKit(\(result.IOReturn)), SMC(\(result.kSMC))")
    }
}

//------------------------------------------------------------------------------
// MARK: MAIN
//------------------------------------------------------------------------------

var smc = SMC()
if smc.open() != kIOReturnSuccess {
    println("ERROR: Failed to open connection to SMC")
    exit(EX_UNAVAILABLE)
}


if argCount == 1 || (isSetNonBoolOptions.count == 0 &&
                     isSetBoolOptions.count == 1 &&
                     isSetBoolOptions[0].shortFlag == "d") {
    printAll()
}


if CLIFanNumberFlag.isSet && CLIFanSpeedFlag.isSet {
    setMinFanSpeed(CLIFanNumberFlag.value!, CLIFanSpeedFlag.value!)
}
else if CLIFanSpeedFlag.isSet != CLIFanNumberFlag.isSet {   // XOR
    println("Usage: Must set fan number (-n) AND fan speed (-s)")
}

if let key = CLICheckKey.value { checkKey(key) }

if CLITemperatureFlag.value { printTemperatureInformation() }
if CLIFanFlag.value         { printFanInformation()         }
if CLIPowerFlag.value       { printPowerInformation()       }
if CLIMiscFlag.value        { printMiscInformation()        }

smc.close()
