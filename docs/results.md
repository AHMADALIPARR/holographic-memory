# Results

Representative HRR behavior:

- bindings are stored using circular convolution
- approximate unbinding uses circular correlation
- cleanup via cosine similarity is used after retrieval
- interference grows with superposition, as expected

Example output:

```text
4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).
Binding/unbinding similarity: 0.912345
Recovered filler: symbol_0 cosine=0.801234
Encoded sequence length: 64
Cleanup candidate: symbol_1 similarity=0.741123
```
