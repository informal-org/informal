import logging
from parsely import Choice, Literal, Builder, Sequence, parse, logger


def test_choice_patterns():
    pattern = Choice([
        Literal("hello"),
        Literal("informal"),
        Literal("world")
    ])
    builder = Builder()
    builder.build(pattern)
    # builder.print_states(pattern)


    # Test valid matches
    # logger.setLevel(logging.DEBUG)
    assert parse(pattern, "hello")[0] == True, "Should match 'hello'"
    # logger.setLevel(logging.INFO)
    assert parse(pattern, "informal")[0] == True, "Should match 'informal'"
    assert parse(pattern, "world")[0] == True, "Should match 'world'"

    # Test invalid matches
    assert parse(pattern, "goodbye")[0] == False, "Should not match 'goodbye'"
    assert parse(pattern, "info")[0] == False, "Should not match partial 'info'"
    assert parse(pattern, "")[0] == False, "Should not match empty string"

    print("All tests passed!")


def test_sequence_patterns():
    pattern = Sequence([
        Literal("hello"),
        Literal("world")
    ])
    builder = Builder()
    builder.build(pattern)
    builder.print_states(pattern)
    logger.setLevel(logging.DEBUG)

    # Test valid matches
    assert parse(pattern, "helloworld")[0] == True, "Should match 'hello world'"

    # Test invalid matches
    assert parse(pattern, "hello")[0] == False, "Should not match 'hello'"
    assert parse(pattern, "goodbye")[0] == False, "Should not match 'goodbye'"

if __name__ == '__main__':
    # test_choice_patterns()
    test_sequence_patterns()