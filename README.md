# Project Costanza

![The beauty](www/screenshot.png?raw=true)

* [Silly academic poster](www/poster.jpg)
* [Demo video of some silly game](http://www.youtube.com/watch?v=Eu8VyIQWxYs)

Project Costanza is a video game console built from the ground up centered around the **DE0-Nano**. It includes the following features:

* Video output (VGA monitor)
* Audio output (mono speaker)
* Storage input (SD card)
* Joypad input (Super Nintendo controller)
* Custom CPU architecture with homemade assembler
* Homemade memory controller for SDRAM communication

The goal of Project Costanza was to fit all of these feature on a single chip in order to run fully capable homemade video games.

It's buggy right now. I need to dig up the adapter board that interfaced all of the external hardware with the FPGA and document it. One day.

## Goals

* Utilize an FPGA chip to represent complex electronic logic to communicate with video, audio, human input, and external storage
* Design a fully independent software toolkit for developing applications
* Test the integrity of the system through the creation and execution of small tech demo video games.

## The Future

This thing was written towards the end of some deadlines. It needs a complete rewrite and some serious love.

* More advanced toolkit with C language compiler
* Support for multiple games on one SD card with the usage of the FAT32 file system
* Bootloader menu for selecting a game from the SD card
* Ability to write to SD card for saving game information
