FROM rust:1.36.0-stretch as build

# create a new empty shell project
RUN USER=root cargo new --bin arevel
WORKDIR /app

# copy over your manifests
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml


# this build step will cache your dependencies
RUN cargo build --release


RUN cargo build
ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm
