.PHONY: build run test app install icon clean

build:
	swift build

run:
	swift run Quitter

test:
	swift test

app:
	./scripts/build-app.sh

install:
	./scripts/build-app.sh --install

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
