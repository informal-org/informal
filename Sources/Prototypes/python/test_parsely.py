from parsely import Choice, Literal, Builder, parse


def test_choice_patterns():
    pattern = Choice([
        Literal("hello"),
        Literal("informal"),
        Literal("world")
    ])
    builder = Builder()
    builder.build(pattern)
    builder.print_states()
    print("Start: ", pattern.start.id)
    print("Success: ", pattern.success.id)
    print("Failure: ", pattern.failure.id)

    # Test valid matches
    assert parse(pattern, "hello")[0] == True, "Should match 'hello'"
    assert parse(pattern, "informal")[0] == True, "Should match 'informal'"
    assert parse(pattern, "world")[0] == True, "Should match 'world'"

    # Test invalid matches
    assert parse(pattern, "goodbye")[0] == False, "Should not match 'goodbye'"
    assert parse(pattern, "info")[0] == False, "Should not match partial 'info'"
    assert parse(pattern, "")[0] == False, "Should not match empty string"

    print("All tests passed!")

if __name__ == '__main__':
    test_choice_patterns()