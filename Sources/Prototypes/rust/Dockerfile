FROM rust:1.39.0-buster AS avbuild
WORKDIR /usr/src

RUN rustup default nightly

RUN rustup target add x86_64-unknown-linux-gnu
# Use musl instead of gnu for redistributable statically linked binaries.
# Otherwise, we need to copy over dynamically linked system libraries to the runtime container
# RUN apt-get update && apt-get install -y musl-tools
# RUN rustup target add x86_64-unknown-linux-musl

RUN USER=root cargo new --lib avs
RUN USER=root cargo new --lib runtime
RUN USER=root cargo new site

# Create a sub-project for avs dependencies
COPY avs/Cargo.toml ./avs
COPY runtime/Cargo.toml ./runtime
COPY site/Cargo.toml ./site

# Copy source code
COPY avs/src /usr/src/avs/src
WORKDIR /usr/src/avs
RUN cargo build --release


COPY runtime/src /usr/src/runtime/src
WORKDIR /usr/src/runtime
RUN cargo build --release


COPY site/src /usr/src/site/src
WORKDIR /usr/src/site
RUN cargo install --path .
RUN cargo build --release


WORKDIR /usr/src/site/target/release
CMD ["./site"]


# RUN cargo install --target x86_64-unknown-linux-gnu --path .
# RUN cargo install --target x86_64-unknown-linux-musl --path .

# Copy just the compiled binary into a smaller runtime container

# FROM scratch
# # COPY --from=avbuild /usr/local/cargo/bin/site /


# # USER 1000
# CMD ["./site"]