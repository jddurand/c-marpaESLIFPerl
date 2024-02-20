Usage:

cmake -S c-marpaESLIFPerl -B c-marpaESLIFPerl-build
cmake --build c-marpaESLIFPerl-build

tarballs of all dependents are then pushed to inc/marpaESLIF/tarballs, default rule is to produce a package MarpaX-ESLIF-<VERSION>.tar.gz in the source dir:

One can test the perl distribution with standard commands, i.e. (with your installed make):

cd c-marpaESLIFPerl/MarpaX-ESLIF-<VERSION>
perl Makefile.PL
make
make test
make xtest
