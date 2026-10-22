use crate::Vector;

pub fn correlation_inverse(left: &Vector, right: &Vector) -> Vector {
    let values = crate::circular_correlation(&left.values, &right.values);
    Vector::from_values(values)
}
