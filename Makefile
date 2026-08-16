.PHONY: build test fmt vet clean

build:
	mkdir -p bin
	go build -trimpath -ldflags="-s -w" -o bin/epubzip ./cmd/epubzip

test:
	go test -race ./...

fmt:
	go fmt ./...

vet:
	go vet ./...

clean:
	rm -rf bin
