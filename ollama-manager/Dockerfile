# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy all source files
COPY go.mod ./
COPY *.go ./

# Download dependencies and build for Windows
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o ollama-manager.exe .

# Final stage - minimal image with just the binary
FROM alpine:latest
COPY --from=builder /app/ollama-manager.exe /ollama-manager.exe
CMD ["echo", "Use: docker/podman cp <container>:/ollama-manager.exe ."]
