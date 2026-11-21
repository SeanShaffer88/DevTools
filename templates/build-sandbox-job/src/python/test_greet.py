from greet import greet


def test_greet_name():
    assert greet("sandbox") == "Hello, sandbox!"


def test_greet_blank_falls_back():
    assert greet("   ") == "Hello, world!"
