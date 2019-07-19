FROM rust:1.36.0-stretch as build

# create a new empty shell project
RUN USER=root cargo new --bin arevel
WORKDIR /app

# copy over your manifests
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml


# copy your source tree
COPY ./ ./


FROM conanio/gcc49:1.17.0 as gcc

# build for release
# RUN rm ./target/release/deps/arevel*
RUN cargo build --release

#RUN cargo build
#ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm

# set the startup command to run your binary
CMD ["./target/release/site"]
