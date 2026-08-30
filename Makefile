.PHONY: all build clean

all: build

build:
	zig build

clean:
	rm -r zig-out
