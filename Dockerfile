FROM crystallang/crystal:1.15.1-alpine AS builder

RUN apk add --no-cache \
  cmake \
  make \
  g++ \
  git \
  curl \
  libgomp \
  openblas-dev

WORKDIR /app

COPY Makefile .
RUN make

COPY shard.yml .
RUN shards install

COPY src/ src/
COPY spec/ spec/

RUN shards build --error-trace demo
