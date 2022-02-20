This is a patched fatcat.cpp source file, compatible with version 1.1.0. 

The original version had issues with OSX due to a different implementation of getopt() on Linux vs. OSX. The patch should fix both, however I have not tested this on Linux.

To use, clone the fatcat git repo https://github.com/Gregwar/fatcat.git and overlay the original src/fatcat.cpp with the one provided here.

Alternatively:
- unzip the full source (fatcat_110_src.zip) and make clean; make; make install
- on a Intel Mac, use the precompiled fatcat binary (/bin/osx/fatcat) 
