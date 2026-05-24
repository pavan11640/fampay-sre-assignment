# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/hodr main.go

# Stage 2: Runtime
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /app/hodr /hodr

EXPOSE 8888

USER nonroot:nonroot

ENTRYPOINT ["/hodr"]
