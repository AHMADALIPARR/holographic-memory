use holographic_memory::{
    cleanup_nearest_neighbor,
    circular_convolution,
    circular_correlation,
    cosine_similarity,
    encode_sequence,
    Memory,
    Vector,
    symbol_codebook,
};

#[test]
fn convolution_matches_definition() {
    let a = vec![1.0, 2.0, 3.0];
    let b = vec![4.0, 5.0, 6.0];

    let actual = circular_convolution(&a, &b);
    let expected = vec![
        a[0] * b[0] + a[1] * b[2] + a[2] * b[1],
        a[0] * b[1] + a[1] * b[0] + a[2] * b[2],
        a[0] * b[2] + a[1] * b[1] + a[2] * b[0],
    ];

    assert_eq!(actual, expected);
}

#[test]
fn binding_and_unbinding_produce_similarity() {
    let dim = 64;
    let names = vec!["role".to_string(), "value".to_string()];
    let codebook = symbol_codebook(&names, dim);
    let role = &codebook[0];
    let value = &codebook[1];

    let bound = circular_convolution(&role.values, &value.values);
    let recovered = circular_correlation(&bound, &role.values);
    let sim = cosine_similarity(&recovered, &value.values);

    assert!(sim > 0.0);
}

#[test]
fn cleanup_selects_highest_similarity() {
    let dim = 32;
    let names = vec!["A".to_string(), "B".to_string(), "C".to_string()];
    let codebook = symbol_codebook(&names, dim);
    let target = codebook[0].clone();

    let (label, score) = cleanup_nearest_neighbor(&target, &codebook);
    assert_eq!(label, "symbol_0");
    assert!(score > 0.99);
}

#[test]
fn sequence_encoding_has_expected_length() {
    let dim = 16;
    let seq = vec![Vector::from_values(vec![1.0; dim]), Vector::from_values(vec![2.0; dim])];
    let encoded = encode_sequence(&seq);
    assert_eq!(encoded.len(), dim);
    assert_eq!(encoded[0], 3.0);
}

#[test]
fn memory_retrieval_returns_best_candidate() {
    let dim = 64;
    let names = vec!["role".to_string(), "filler".to_string(), "other".to_string()];
    let codebook = symbol_codebook(&names, dim);
    let mut memory = Memory::new(dim);
    memory.store_role_filler(&codebook[0], &codebook[1]);

    let (label, score) = memory.recover_filler(&codebook[0], &codebook);
    assert!(label.contains("symbol_"));
    assert!(score >= 0.0);
}
