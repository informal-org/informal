FROM elixir:latest
WORKDIR /app
RUN mix local.rebar --force && mix local.hex --force
ENV MIX_ENV=prod REPLACE_OS_VARS=true TERM=xterm
CMD ["mix", "release", "--env=prod", "--executable", "--verbose"]
# docker build -t arevel-builder .