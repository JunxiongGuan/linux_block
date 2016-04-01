all:

TEST_PROGS := nvmf_loop.sh
TEST_PROGS += 001.sh
TEST_PROGS += 002.sh
TEST_PROGS += 003.sh

include ../lib.mk

check:
	./nvmf_loop.sh
	./nvmf_loop.sh -d -s
	./nvmf_loop.sh -b 4k

clean:

