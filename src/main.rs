use holographic_memory::{
    bind_role_filler, circular_convolution, circular_correlation, cosine_similarity, Memory,
    Vector,
};

fn main() {
    let dim = 64;
    let names = vec![
        "alice".to_string(),
        "manager".to_string(),
        "paris".to_string(),
        "coffee".to_string(),
        "teacher".to_string(),
        "math".to_string(),
    ];
    let codebook = holographic_memory::make_symbol_codebook(names, dim);

    println!("=== HRR experiment: binding, unbinding, cleanup ===");
    println!("Dimensionality: {}", dim);

    let role = codebook[0].clone();
    let filler = codebook[1].clone();
    let bound = circular_convolution(&role.values, &filler.values);
    let recovered = circular_correlation(&bound, &role.values);
    let similarity = cosine_similarity(&recovered, &filler.values);

    println!("Binding/unbinding similarity: {:.4}", similarity);

    let mut memory = Memory::new(dim);
    memory.store_role_filler(&role, &filler);
    memory.store_role_filler(&codebook[2].clone(), &codebook[3].clone());
    memory.store_role_filler(&codebook[4].clone(), &codebook[5].clone());

    let recovered_value = memory.recover_filler(&role, &codebook);
    println!(
        "Recovered filler for role {}: {} cosine={:.4}",
        0,
        recovered_value.0,
        recovered_value.1
    );

    let frame = bind_role_filler(&role, &filler);
    println!("Role-filler frame norm: {:.4}", frame.norm());

    let sequence = vec![codebook[0].clone(), codebook[2].clone(), codebook[4].clone()];
    let encoded = holographic_memory::encode_sequence(&sequence);
    println!("Encoded sequence length: {}", encoded.len());

    let noisy = Vector::from_values((0..dim).map(|i| (i as f64) * 0.01).collect());
    let candidate = holographic_memory::cleanup_nearest_neighbor(&noisy, &codebook);
    println!("Cleanup candidate: {} similarity={:.4}", candidate.0, candidate.1);

    println!("\nDemo complete.");
}
