program hrr_reference
  implicit none
  integer, parameter :: d = 64
  real :: a(d), b(d), c(d)
  integer :: i, j, k

  do i = 1, d
     a(i) = sin(real(i))
     b(i) = cos(real(i))
     c(i) = 0.0
  end do

  do k = 1, d
     c(k) = 0.0
     do j = 1, d
        i = modulo(k - j, d) + 1
        c(k) = c(k) + a(j) * b(i)
     end do
  end do

  print *, 'reference circular convolution ready'
  print *, 'max_abs', maxval(abs(c))
end program hrr_reference
