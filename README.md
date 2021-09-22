# min-httpd

A minimal Linux HTTP server written in x86_64 assembly.

## "Features"

* Listens on port 80/tcp and responds to requests by serving files 
* Doesn't use libc
* Super small binary! (8.8K as of Sep 15, 2021)
* Statically linked
* Supports "Content-Type: text/html"
* Supports HTTP status

## Limitations

* Somewhere in between HTTP/0.9 and HTTP/1.0 (only sort of)
* No spaces in filenames
* No protection against filesystem traversal
* Only GET allowed
* No keepalives

## Build

### Requirements

* 64 bit Linux OS

### Build Dependencies

* nasm assembler
* make
* clang (only to build tests)

### Building

To build simply run `make` to build the `httpd` binary. Run `make test` to build and run the tests. `make debug` to build the server with debug level logging and symbols.
