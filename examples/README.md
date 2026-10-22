# Examples

`assoc_memory.rs` is a runnable example against the crate API: it
stores three role/filler facts (capital_of_france -> paris,
capital_of_japan -> tokyo, capital_of_peru -> lima) as
circular-convolution bindings in one Memory trace of dimension
1024, queries each role, then zeroes 25% of the trace and measures
the raw unbound cosine to the true filler before cleanup.

```bash
cargo run --release --example assoc_memory
```

Measured output (also in `results/example_run.txt`):

```text
stored 3 facts in one trace of dim 1024
query  capital_of_france ->  paris  (cosine 0.4996) correct
query   capital_of_japan ->  tokyo  (cosine 0.4856) correct
query    capital_of_peru ->   lima  (cosine 0.5228) correct
retrieval: 3/3 correct
after zeroing 25% of the trace: raw unbound cosine to paris = 0.4507
```

The main binary (`cargo run --release`) runs the broader
experiment harness; its measured output is in
`results/engine_run.txt`.
