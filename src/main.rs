use holographic_memory::{
    bind_role_filler, circular_convolution, circular_correlation, cosine_similarity,
    make_symbol_codebook, Memory, Vector,
};

fn make_symbol_vectors(dim: usize) -> Vec<Vector> {
    let names = [
        "alice", "manager", "paris", "coffee", "teacher", "math", "book", "chair", "bread",
        "engineer", "office", "goverment", "runner", "forest", "molecule", "planet",
    ];
    make_symbol_codebook(names.iter().map(|s| s.to_string()).collect(), dim)
}

fn main() {
    let dim = 64;
    let symbols = make_symbol_vectors(dim);

    println!("=== HRR experiment: binding, unbinding, cleanup ===");
    println!("Dimensionality: {}", dim);

    let role = symbols[0].clone();
    let filler = symbols[1].clone();
    let bound = circular_convolution(&role.values, &filler.values);
    let recovered = circular_correlation(&role.values, &bound);
    let similarity = cosine_similarity(&recovered, &filler.values);

    println!("Binding/unbinding similarity: {:.4}", similarity);

    let mut memory = Memory::new(dim);
    memory.store_role_filler(&role, &filler);
    memory.store_role_filler(&symbols[2].clone(), &symbols[3].clone());
    memory.store_role_filler(&symbols[4].clone(), &symbols[5].clone());

    let recovered_from_role = memory.recover_filler(&role, &symbols);
    println!(
        "Recovered filler for role {:?}: {:?} cosine={:.4}",
        role,
        recovered_from_role.0,
        recovered_from_role.1
    );

    let frame = bind_role_filler(&symbols[0], &symbols[1]);
    println!("Role-filler frame norm: {:.4}", frame.norm());

    let sequence = vec![symbols[6].clone(), symbols[7].clone(), symbols[8].clone()];
    let encoded = holographic_memory::encode_sequence(&sequence);
    println!("Encoded sequence length: {}", encoded.len());

    let noisy = Vector::from_values((0..dim).map(|i| (i as f64) * 0.01).collect());
    let best = holographic_memory::cleanup_nearest_neighbor(&noisy, &symbols);
    println!("Cleanup candidate: {:?} similarity={:.4}", best.0, best.1);

    println!("\nDemo complete.");
}
