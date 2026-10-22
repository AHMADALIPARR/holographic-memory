use crate::Vector;

pub fn approximate_unbind(memory: &Vector, cue: &Vector) -> Vector {
    let recovered = crate::circular_correlation(&cue.values, &memory.values);
    Vector::from_values(recovered)
}
