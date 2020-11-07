DEST := /usr/local/bin/vapor

EXECUTABLES = swiftc
K := $(foreach exec,$(EXECUTABLES),\
        $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))

build:
	swiftc ./scripts/build.swift
	./build
	rm ./build
install: build
ifeq (, $(shell which sudo))
		mv .build/release/vapor ${DEST}
		chmod 755 ${DEST}
else
		sudo mv .build/release/vapor ${DEST}
		sudo chmod 755 ${DEST}
endif
uninstall:
	sudo rm ${DEST}
clean:
	rm -rf .build
