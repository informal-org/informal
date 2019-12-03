FROM rust:1.39.0 AS avbuild
WORKDIR /usr/src

RUN rustup default nightly
RUN rustup target add x86_64-unknown-linux-gnu
RUN USER=root cargo new --lib avs
RUN USER=root cargo new --lib runtime
RUN USER=root cargo new site

# Create a sub-project for avs dependencies
COPY avs/Cargo.toml ./avs
COPY runtime/Cargo.toml ./runtime
COPY site/Cargo.toml ./site

# Install all the dependencies
WORKDIR /usr/src/avs
RUN cargo build --release

WORKDIR /usr/src/runtime
RUN cargo build --release

WORKDIR /usr/src/site
RUN cargo build --release

# Copy source code
COPY avs/src /usr/src/avs/src
COPY runtime/src /usr/src/runtime/src
COPY site/src /usr/src/site/src


WORKDIR /usr/src/site

# Copy avs src
RUN cargo install --target x86_64-unknown-linux-gnu --path .

