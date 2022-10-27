# ZBasic

This project provides a very basic version of a working
[ZipCPU](https://github.com/ZipCPU/zipcpu) system.  It is designed so that
others (you perhaps?) can then build off of it and design with it.
ZBasic has three primary goals:

- To provide a usable beginning system to allow users to get *something* up and running quickly

- To provide a very basic system that can then be matched with an emulator, and used to test library and compiler functionality apart from actual hardware.

- To demonstrate the utility of [autofpga](https://github.com/ZipCPU/autofpga), and its ability to quickly, easily, and seemlessly add components to a design

If you'd like to give this a spin, consider the instructions
[in this article](http://zipcpu.com/zipcpu/2018/02/12/zbasic-intro.html)
describing how to do so.

# Status

The ZBasic system can now be made using [autofpga](https://github.com/ZipCPU/autofpga), all the way from zero to Hello World successfully in Verilator testing.  Other tests have been added as well:

- [sw/board/cputest.c](Bare CPU test)
- [sw/board/lockcheck.c](Atomic access check)
- [sw/board/hellostep.c](Stepping through hello world)

That said, current ZipCPU development now supports a simulation checking
environment that allows the CPU to be checked in multiple environments, with
multiple different configurations.  This repository only tends to check a
single configuration at a time.  It's still a useful testbed, but it is no
longer the definitive one for the ZipCPU.

# License

Gisselquist Technology, LLC, is pleased to provide you access to this entire
project under the GPLv3 license.  If this license will not work for you, please
contact me.

