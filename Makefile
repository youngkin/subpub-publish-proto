.PHONY: all clean compile release

PREFIX:=../
DEST:=$(PREFIX)$(PROJECT)
ERLANG_BIN=$(shell dirname $(shell which erl))
REBAR=./rebar
RELX=./relx

$(if $(ERLANG_BIN),,$(warning "Warning: No Erlang found in your path, this will probably fail"))

all:	clean get_deps compile release

clean:
	rm -rf _rel
	$(REBAR) clean

get_deps:
	$(REBAR) get-deps

compile:
	$(REBAR) compile

release:
	$(RELX) release tar
