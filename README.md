# WASI wheels

This repository contains build files to produce WASI builds of a set of Python packages which do not have [official WASI builds](https://pypi.org/search/?c=Environment+%3A%3A+WebAssembly+%3A%3A+WASI).

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

