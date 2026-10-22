use crate::Vector;

pub fn approximate_unbind(memory: &Vector, cue: &Vector) -> Vector {
    // ASSISTANT REPAIR (2026-10-22, labeled): argument order swapped
    // to (memory, cue) to match the corrected circular_correlation
    // convention; the composed computation is identical to the
    // previous library behavior (see convolution.rs repair note).
    let recovered = crate::circular_correlation(&memory.values, &cue.values);
    Vector::from_values(recovered)
}
