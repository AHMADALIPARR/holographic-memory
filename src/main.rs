use holographic_memory::{
    cleanup_nearest_neighbor, circular_convolution, circular_correlation, cosine_similarity,
    encode_sequence, generate_symbol, symbol_codebook, Memory, superimpose, Vector,
};

fn print_experiment_a() {
    let dim = 1024usize;
    let symbols: Vec<String> = (0..6).map(|i| format!("S{i}")).collect();
    let codebook = symbol_codebook(&symbols, dim);
    let mut memory = Memory::new(dim);

    for i in 0..4 {
        let role = &codebook[i];
        let filler = &codebook[(i + 1) % symbols.len()];
        memory.store_role_filler(role, filler);
    }

    let mut recovered = Vec::new();
    for i in 0..4 {
        let cue = &codebook[i];
        let (label, score) = memory.retrieve(cue, &codebook);
        recovered.push((label, score));
    }

    println!("4 bindings stored in dim=1024; cleaned retrievals return the highest-similarity symbols (interference visible, as expected).");
    println!("Recovered bindings: {:?}", recovered);
}

fn print_experiment_b() {
    let dim = 1024usize;
    let names = vec!["role".to_string(), "value".to_string()];
    let codebook = symbol_codebook(&names, dim);
    let role = &codebook[0];
    let value = &codebook[1];
    let bound = circular_convolution(&role.values, &value.values);

    let mut damaged = bound.clone();
    let zero_count = damaged.values.len() / 4;
    for i in 0..zero_count {
        damaged.values[i] = 0.0;
    }

    let recovered = circular_correlation(&role.values, &damaged.values);
    let probe = Vector::from_values(recovered);
    let (_, score) = cleanup_nearest_neighbor(&probe, &codebook);
    println!("25% component zeroing: recovery cosine ≈ {:.3}.", score);
}

fn print_experiment_c() {
    let dim = 512usize;
    let symbols: Vec<String> = (0..10).map(|i| format!("S{i}")).collect();
    let codebook = symbol_codebook(&symbols, dim);
    let mut memory = Memory::new(dim);

    for i in 0..10 {
        let role = &codebook[i];
        let filler = &codebook[(i + 3) % symbols.len()];
        memory.store_role_filler(role, filler);
    }

    let mut correct = 0usize;
    for i in 0..10 {
        let cue = &codebook[i];
        let (label, _) = memory.retrieve(cue, &codebook);
        if label == format!("symbol_{}", (i + 3) % symbols.len()) {
            correct += 1;
        }
    }

    println!("Capacity probe: 10 bindings in dim=512 → {}/10 correct after cleanup.", correct);
}

fn print_fft_agreement() {
    let dim = 1024usize;
    let a = (0..dim)
        .map(|i| ((i as f64) / 17.0).sin())
        .collect::<Vec<_>>();
    let b = (0..dim)
        .map(|i| ((i as f64) / 13.0).cos())
        .collect::<Vec<_>>();

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
}

fn main() {
    print_experiment_a();
    print_experiment_b();
    print_experiment_c();
    print_fft_agreement();

    let dim = 64usize;
    let role = generate_symbol("role", dim);
    let value = generate_symbol("value", dim);
    let bound = circular_convolution(&role.values, &value.values);
    let recovered = circular_correlation(&bound, &role.values);
    let sim = cosine_similarity(&recovered, &value.values);
    let sequence = vec![generate_symbol("A", dim), generate_symbol("B", dim), generate_symbol("C", dim)];
    let encoded = encode_sequence(&sequence);
    println!("Role/filler binding similarity: {:.4}", sim);
    println!("Sequence encoding length: {}", encoded.len());

    let memory = Memory::new(dim);
    let combined = superimpose(&[role.clone(), value.clone()]);
    println!("Superposition norm: {:.4}", combined.norm());
    let _ = memory;
}
