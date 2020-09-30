FROM golang:latest

# Install Elm
RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz
RUN gunzip elm.gz
RUN chmod +x elm
RUN mv elm /usr/local/bin/

# Copy project
USER root
RUN mkdir $GOPATH/src/elmgo-api
COPY src $GOPATH/src/elmgo-api/src
COPY elm.json $GOPATH/src/elmgo-api/
WORKDIR $GOPATH/src/elmgo-api/src

# Fetch imported Go packages
RUN cd backend && go get -d

# Build Elm project
RUN elm make frontend/Main.elm --output frontend/Main.js

# When container is started, build & run Go server 
CMD go run backend/api.go
