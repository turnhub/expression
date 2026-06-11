Code.require_file("support/type_test_matrix.ex", __DIR__)
Code.require_file("support/fuzz_helpers.ex", __DIR__)

ExUnit.start(exclude: [:fuzz])
