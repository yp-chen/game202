#!/bin/bash
cd build
cmake .. -G "MinGW Makefiles"
mingw32-make
./lut-Emu-MC
# ./lut-Eavg-MC
# ./lut-Emu-IS
# ./lut-Eavg-IS
cd ..