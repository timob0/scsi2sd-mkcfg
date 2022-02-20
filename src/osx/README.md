This is a patched fatcat.cpp source file, compatible with version 1.1.0. 

The original version had issues with OSX due to a different implementation of getopt() on Linux vs. OSX. The patch should fix both, however I have not tested this on Linux.
