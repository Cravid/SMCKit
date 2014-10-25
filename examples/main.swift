/*
* Simple example client.
*
* main.swift
* SMCKit
*
* Copyright (C) 2014  beltex <https://github.com/beltex>
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program; if not, write to the Free Software Foundation, Inc.,
* 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

import IOKit

let smc = SMC()

if (smc.open() == kIOReturnSuccess) {
    println("CPU 0 Diode Temperature: \(smc.getTMP(SMC.TMP.CPU_0_DIODE).tmp)°C")
    println("Fan 0 Speed: \(smc.getFanRPM(0).rpm) RPM")
    smc.close()
}

