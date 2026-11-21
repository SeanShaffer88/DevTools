def greet(name: str) -> str:
    """Return a greeting; empty names fall back to 'world'."""
    return f"Hello, {name.strip() or 'world'}!"
