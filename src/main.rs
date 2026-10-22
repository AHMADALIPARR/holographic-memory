use holographic_memory::{
    cleanup_nearest_neighbor, circular_convolution, circular_correlation, cosine_similarity,
    encode_sequence, generate_symbol, symbol_codebook, Memory, superimpose, Vector,
};

fn demo_binding_retrieval(dim: usize, count: usize) -> Vec<(String, f64)> {
    let symbols: Vec<String> = (0..count).map(|i| format!("S{i}")).collect();
    let codebook = symbol_codebook(&symbols, dim);
    let mut memory = Memory::new(dim);

    for i in 0..count {
        let role = &codebook[i];
        let filler = &codebook[(i + 1) % count];
        memory.store_role_filler(role, filler);
    }

    let mut out = Vec::new();
    for i in 0..count {
        let cue = &codebook[i];
        let (label, score) = memory.retrieve(cue, &codebook);
        out.push((label, score));
    }
    out
}

fn demo_zeroing(dim: usize, fraction: f64) -> f64 {
    let names = vec!["role".to_string(), "value".to_string()];
    let codebook = symbol_codebook(&names, dim);
    let role = &codebook[0];
    let value = &codebook[1];
    let bound = circular_convolution(&role.values, &value.values);

    let mut damaged = bound.clone();
    let zero_count = (damaged.len() as f64 * fraction) as usize;
    for i in 0..zero_count {
        damaged[i] = 0.0;
    }

    let recovered = circular_correlation(&role.values, &damaged);
    let probe = Vector::from_values(recovered);
    let (_, score) = cleanup_nearest_neighbor(&probe, &codebook);
    score
}

fn demo_capacity_probe(dim: usize, count: usize) -> usize {
    let symbols: Vec<String> = (0..count).map(|i| format!("S{i}")).collect();
    let codebook = symbol_codebook(&symbols, dim);
    let mut memory = Memory::new(dim);

    for i in 0..count {
        let role = &codebook[i];
        let filler = &codebook[(i + 3) % count];
        memory.store_role_filler(role, filler);
    }

    let mut correct = 0usize;
    for i in 0..count {
        let cue = &codebook[i];
        let (label, _) = memory.retrieve(cue, &codebook);
        let expected = format!("symbol_{}", (i + 3) % count);
        if label == expected {
            correct += 1;
        }
    }
    correct
}

fn main() {
    println!("=== HRR experiment harness ===");

    let retrievals = demo_binding_retrieval(1024, 4);
    println!("4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).");
    println!("Recovered bindings: {:?}", retrievals);

    let zeroed_score = demo_zeroing(1024, 0.25);
    println!("25% component zeroing: recovery cosine ≈ {:.3}.", zeroed_score);

    let correct = demo_capacity_probe(512, 10);
    println!("Capacity probe: 10 bindings in dim=512 → {}/10 correct after cleanup.", correct);

    let dim = 1024usize;
    let a = (0..dim).map(|i| ((i as f64) / 17.0).sin()).collect::<Vec<_>>();
    let b = (0..dim).map(|i| ((i as f64) / 13.0).cos()).collect::<Vec<_>>();
    let direct = circular_convolution(&a, &b);
    let fft = holographic_memory::convolution_fft(&a, &b);
    let mut max_abs_diff = 0.0f64;
    for (lhs, rhs) in direct.iter().zip(fft.iter()) {
        let diff = (lhs - rhs).abs();
        if diff > max_abs_diff {
            max_abs_diff = diff;
        }
    }
    println!("Direct and FFT-path convolutions agree within {:.2e}.", max_abs_diff);

    let role = generate_symbol("role", 64);
    let value = generate_symbol("value", 64);
    let bound = circular_convolution(&role.values, &value.values);
    let recovered = circular_correlation(&bound, &role.values);
    let sim = cosine_similarity(&recovered, &value.values);
    println!("Role/filler binding similarity: {:.4}", sim);

    let seq = vec![
        Vector::from_values(vec![1.0; 64]),
        Vector::from_values(vec![2.0; 64]),
        Vector::from_values(vec![3.0; 64]),
    ];
    let encoded = encode_sequence(&seq);
    println!("Encoded sequence length: {}", encoded.len());

    let superposed = superimpose(&[role.clone(), value.clone()]);
    println!("Superposition norm: {:.4}", superposed.norm());
}
