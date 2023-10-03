golang
======

This is a container to build golang static binaries with cgo musl for amd64, glibc for freebsd, and windows

[![microbadger][1]][2] [![docker hub][3]][4]

[1]: https://images.microbadger.com/badges/image/storjlabs/golang.svg
[2]: https://microbadger.com/images/storjlabs/golang
[3]: https://img.shields.io/docker/automated/storjlabs/golang.svg
[4]: https://hub.docker.com/r/storjlabs/golang


Usage
-----

Check out your source files to a GOPATH compatible directory:

```bash
mkdir -p src/github.com/user
git clone https://github.com/user/repo.git src/github.com/user/repo
```

Then build!

```bash
docker run --rm -it -v "$PWD:/go" -u "$UID:$GID" storjlabs/golang github.com/user/repo
```

Alternate build
---------------

For when another repo is included in a `src` directory, for instance, a submodule:
```bash
tar c src \
| docker run --rm -i -e TAR=1 storjlabs/golang github.com/user/repo \
| tar -x ./main
```

For when there's just source files in a diretory:
```bash
tar c . \
| docker run --rm -i -e TAR=1 storjlabs/golang -o main \
| tar -x ./main
```


Environment Variables
---------------------

`VERBOSE` This makes the loader script more verbose

ONBUILD
-------

This image supports docker multistage builds. Simply use this as template for your Dockerfile:
```
ARG REPOSITORY=github.com/storjlabs/example
FROM storjlabs/golang as builder

FROM scratch
ENV ADDRESS=
EXPOSE 80
ENTRYPOINT ["/repo", "serve"]
COPY --from=builder /app /repo
```

Then build with this:
```
docker build -t user/repo --build-arg PACKAGE=github.com/user/repo .
```

References
----------

http://dominik.honnef.co/posts/2015/06/statically_compiled_go_programs__always__even_with_cgo__using_musl/

