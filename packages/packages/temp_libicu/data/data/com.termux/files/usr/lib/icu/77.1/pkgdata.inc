GENCCODE_ASSEMBLY_TYPE=-a gcc
SO=so
SOBJ=so
A=a
LIBPREFIX=lib
LIB_EXT_ORDER=.77.1
COMPILE=aarch64-linux-android-clang -isystem/data/data/com.termux/files/usr/include/c++/v1 -isystem/data/data/com.termux/files/usr/include -D_REENTRANT  -DU_HAVE_ELF_H=1 -DU_HAVE_STRTOD_L=0  -DU_ALL_IMPLEMENTATION -DU_ATTRIBUTE_DEPRECATED= -fstack-protector-strong -Oz -std=c11 -Wall -pedantic -Wshadow -Wpointer-arith -Wmissing-prototypes -Wwrite-strings   -c
LIBFLAGS=-I/data/data/com.termux/files/usr/include -DPIC -fPIC
GENLIB=aarch64-linux-android-clang -fstack-protector-strong -Oz -std=c11 -Wall -pedantic -Wshadow -Wpointer-arith -Wmissing-prototypes -Wwrite-strings   -L/data/data/com.termux/files/usr/lib -Wl,-rpath=/data/data/com.termux/files/usr/lib -Wl,--enable-new-dtags -Wl,--as-needed -Wl,-z,relro,-z,now  -shared -Wl,-Bsymbolic
LDICUDTFLAGS=-nodefaultlibs -nostdlib
LD_SONAME=-Wl,-soname -Wl,
RPATH_FLAGS=
BIR_LDFLAGS=-Wl,-Bsymbolic
AR=llvm-ar
ARFLAGS=r
RANLIB=llvm-ranlib
INSTALL_CMD=/usr/bin/install -c
