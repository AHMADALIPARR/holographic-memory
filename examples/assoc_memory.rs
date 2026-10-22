// Runnable example against the crate API: a small associative
// memory of role/filler facts, queried by role, then probed under
// damage. Run with: cargo run --release --example assoc_memory
//
// Facts stored (role -> filler):
//   capital_of_france -> paris
//   capital_of_japan  -> tokyo
//   capital_of_peru   -> lima
// Each fact is one circular-convolution binding; all three live in a
// single Memory trace of dimension 1024. Queries unbind with the
// role vector and clean up against the shared codebook. Following
// the crate's convention, cleanup reports the winning codebook
// index as "symbol_<i>", which this example maps back to names.

use holographic_memory::{
    bind_role_filler, circular_correlation, cosine_similarity, superimpose, symbol_codebook,
    Memory, Vector,
};

fn main() {
    let dim = 1024usize;
    let names: Vec<String> = [
        "capital_of_france",
        "capital_of_japan",
        "capital_of_peru",
        "paris",
        "tokyo",
        "lima",
    ]
    .iter()
    .map(|s| s.to_string())
    .collect();
    let codebook = symbol_codebook(&names, dim);
    let fact_pairs = [(0usize, 3usize), (1, 4), (2, 5)];

    let mut memory = Memory::new(dim);
    for &(r, f) in &fact_pairs {
        memory.store_role_filler(&codebook[r], &codebook[f]);
    }
    println!("stored {} facts in one trace of dim {}", fact_pairs.len(), dim);

    let mut correct = 0usize;
    for &(r, f) in &fact_pairs {
        let (label, sim) = memory.retrieve(&codebook[r], &codebook);
        let idx: usize = label
            .strip_prefix("symbol_")
            .and_then(|s| s.parse().ok())
            .unwrap_or(usize::MAX);
        let ok = idx == f;
        if ok {
            correct += 1;
        }
        println!(
            "query {:>18} -> {:>6}  (cosine {:.4}) {}",
            names[r],
            names.get(idx).map(|s| s.as_str()).unwrap_or("?"),
            sim,
            if ok { "correct" } else { "WRONG" }
        );
    }
    println!("retrieval: {}/{} correct", correct, fact_pairs.len());

    // Damage probe: superpose the same bindings into one trace, zero
    // 25% of its components, unbind by hand, and measure the raw
    // cosine to the true filler before cleanup. Holographic storage
    // degrades gracefully because every component carries part of
    // every fact.
    let bindings: Vec<Vector> = fact_pairs
        .iter()
        .map(|&(r, f)| bind_role_filler(&codebook[r], &codebook[f]))
        .collect();
    let trace = superimpose(&bindings);
    let damaged: Vec<f64> = trace
        .values
        .iter()
        .enumerate()
        .map(|(k, v)| if k % 4 == 0 { 0.0 } else { *v })
        .collect();
    let unbound = circular_correlation(&damaged, &codebook[0].values);
    let sim = cosine_similarity(&unbound, &codebook[3].values);
    println!(
        "after zeroing 25% of the trace: raw unbound cosine to {} = {:.4}",
        names[3], sim
    );
}
