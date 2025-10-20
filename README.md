# WASI wheels

**Please note**: This project is an experimental proof-of-concept that Python packages containing native extensions can be cross-compiled for WASI and used with [componentize-py](https://github.com/bytecodealliance/componentize-py).  It is not being actively maintained; the packages are out-of-date with respect to their upstream versions, and might not even build anymore.  Do not rely on these builds for anything serious.

This repository contains build files to produce WASI builds of a set of Python packages which do not have official WASI builds.

## Building the Packages

Before building, the submodules need to be intialized:

```bash
git submodule update --init --recursive
```

Build all the pacakge using

```bash
make
```

Once the build process is complete, the wheels can be found in the `build` directory. The packages can be used in your code by extracting the `tar.gz` directory in your project root. 

