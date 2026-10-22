use holographic_memory::{
    cleanup_nearest_neighbor, circular_convolution, circular_correlation, cosine_similarity,
    Memory, Vector,
};
use holographic_memory::symbol_codebook;

fn main() {
    let dim = 1024;
    let names = vec![
        "A".to_string(),
        "B".to_string(),
        "C".to_string(),
        "D".to_string(),
        "E".to_string(),
        "F".to_string(),
    ];

    let codebook = symbol_codebook(&names, dim);

    let role = codebook[0].clone();
    let filler = codebook[1].clone();

    let bound = circular_convolution(&role.values, &filler.values);
    let recovered = circular_correlation(&bound, &role.values);
    let similarity = cosine_similarity(&recovered, &filler.values);

    println!("4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).");
    println!("Binding/unbinding similarity: {:.6}", similarity);

    let mut memory = Memory::new(dim);
    memory.store_role_filler(&codebook[0], &codebook[1]);
    memory.store_role_filler(&codebook[2], &codebook[3]);
    memory.store_role_filler(&codebook[4], &codebook[5]);

    let recovered_result = memory.recover_filler(&codebook[0], &codebook);
    println!("Recovered filler: {} cosine={:.6}", recovered_result.0, recovered_result.1);

    let sequence = vec![codebook[0].clone(), codebook[2].clone(), codebook[4].clone()];
    let encoded = holographic_memory::encode_sequence(&sequence);
    println!("Encoded sequence length: {}", encoded.len());

    let noisy = Vector::from_values((0..dim).map(|i| (i as f64) * 0.01).collect());
    let candidate = cleanup_nearest_neighbor(&noisy, &codebook);
    println!("Cleanup candidate: {} similarity={:.6}", candidate.0, candidate.1);
}
