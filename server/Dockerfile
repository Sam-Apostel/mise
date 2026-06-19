# ==== Build image ====
FROM swift:6.1-noble AS build

# jemalloc dev headers are required for the `-ljemalloc` link below.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get update -q \
    && apt-get install -q -y libjemalloc-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# The server depends on the sibling ../Shared package, so copy both into the
# build context. (Railway uses the repo root as the build context — see
# railway.json / README.)
COPY ./Shared /Shared
COPY ./server /build

RUN swift package resolve
RUN swift build -c release --product App \
    --static-swift-stdlib \
    -Xlinker -ljemalloc

# Stage the run-time bits into a clean tree.
RUN mkdir -p /staging \
    && cp "$(swift build --package-path /build -c release --show-bin-path)/App" /staging/

# ==== Run image ====
FROM ubuntu:noble

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates tzdata libjemalloc2 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /staging /app

# Run as a non-root user.
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
USER vapor:vapor

# Railway sets $PORT; configure.swift binds to it (defaults to 8080).
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
