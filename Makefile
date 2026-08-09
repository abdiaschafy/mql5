CXX := g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Wpedantic -Werror
CORE_TEST_BINARY ?= /tmp/mql5_silver_bullet_core_tests

.PHONY: test verify test-core test-contracts test-mql5

test: test-core test-contracts

verify: test test-mql5

test-core:
	$(CXX) $(CXXFLAGS) tests/silver_bullet_core_tests.cpp -o $(CORE_TEST_BINARY)
	$(CORE_TEST_BINARY)

test-contracts:
	python3 tests/source_contract_tests.py

test-mql5:
	bash tests/compile_mql5.sh
