# Test Structure

The Rust test suite covers the core numerical and associative-memory behaviors.

## Tests included

- convolution match against the mathematical definition
- binding/unbinding produce positive similarity
- cleanup chooses the correct nearest symbol
- sequence encoding preserves fixed vector length
- memory retrieval returns a valid recovery result

## Command

```bash
cargo test -- --nocapture
```

The tests are deterministic and should pass without flaky numerical assumptions.
