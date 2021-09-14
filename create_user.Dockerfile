FROM golang:alpine
LABEL maintainer="maxmunzel"
RUN mkdir /go/src/create_user
WORKDIR "/go/src/create_user"
RUN ["go", "mod", "init"]
RUN ["go", "get", "golang.org/x/crypto/sha3"]
CMD [ "go",  "run",  "create_user.go" ]
