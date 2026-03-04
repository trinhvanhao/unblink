FROM ghcr.io/railwayapp/nixpacks:ubuntu-1745885067

ENTRYPOINT ["/bin/bash", "-l", "-c"]
WORKDIR /app/
RUN apt-get update && apt-get install -y golang-go




ARG CGO_ENABLED NIXPACKS_METADATA
ENV CGO_ENABLED=$CGO_ENABLED NIXPACKS_METADATA=$NIXPACKS_METADATA

# setup phase
# noop

# install phase
COPY . /app/.
RUN --mount=type=cache,id=0FQoiH47Zrw-/root/cache/go-build,target=/root/.cache/go-build go mod download

# build phase
COPY . /app/.
RUN --mount=type=cache,id=0FQoiH47Zrw-/root/cache/go-build,target=/root/.cache/go-build go build -o out ./cmd/bbox_test





# start
FROM ubuntu:noble
ENTRYPOINT ["/bin/bash", "-l", "-c"]
WORKDIR /app/
COPY --from=0 /etc/ssl/certs /etc/ssl/certs
RUN true
COPY --from=0 /app/ /app/

CMD ["./out"]