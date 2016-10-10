!------------------------------------------------------------------------------
!
! This file is part of the Sternheimer-GW code.
! 
! Copyright (C) 2010 - 2016 
! Henry Lambert, Martin Schlipf, and Feliciano Giustino
!
! Sternheimer-GW is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! Sternheimer-GW is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with Sternheimer-GW. If not, see
! http://www.gnu.org/licenses/gpl.html .
!
!------------------------------------------------------------------------------ 
!> Provide routines for 6 dimensional FFT.
!!
!! This module allows to do a Fourier transform of quantities that have to
!! spacial coordinates into reciprocal space and the reverse
!! \f{equation}{
!!   f(r, r') \underset{\text{fwfft6}}{\longrightarrow} f(G, G')
!!            \underset{\text{invfft6}}{\longrightarrow} f(r, r')~.
!! \f}
MODULE fft6_module

  IMPLICIT NONE

CONTAINS

  !> Transform an input array \f$f(r, r')\f$ from real to reciprocal space
  !! \f$f(G, G')\f$.
  !!
  !! This is done in the following steps:
  SUBROUTINE fwfft6(grid_type, f, dfft, map, omega)

    USE kinds,          ONLY: dp
    USE fft_interfaces, ONLY: fwfft
    USE fft_types,      ONLY: fft_type_descriptor

    !> grid type used for the Fourier transform, this is passed to fwfft;
    !! check the definition of fwfft for a list of options
    CHARACTER(*), INTENT(IN)    :: grid_type

    !> *on input*  the array in real space \f$f(r, r')\f$ <br>
    !! *on output* the array in reciprocal space \f$f(G, G')\f$
    COMPLEX(dp),  INTENT(INOUT) :: f(:,:)

    !> FFT descriptor - this defines the way the Fourier transform is
    !! executed, must be consistent with grid_type
    !! @note the code does not check explicitly if dfft and grid_type are compatible
    TYPE(fft_type_descriptor), INTENT(IN) :: dfft

    !> Because usually a sphere of G-vectors is used, not all points on the FFT
    !! grid are set. This map points from index of the G-points inside the
    !! sphere onto their index in the full G-mesh.
    INTEGER,      INTENT(IN)    :: map(:)

    !> volume of the unit cell
    REAL(dp),     INTENT(IN)    :: omega

    !> work array for the second index (which is not contigous in memory
    COMPLEX(dp), ALLOCATABLE    :: work(:)

    !> number of points in reciprocal space
    INTEGER num_g

    !> counter on reciprocal space points
    INTEGER ig

    !> number of points in real space
    INTEGER num_r

    !> counter on real space points
    INTEGER ir

    !> check for error in allocation
    INTEGER ierr

    ! initialize helper variables
    num_g = SIZE(map)
    num_r = dfft%nnr

    !
    ! sanity test of the input
    !
    ! reduced mesh must be within full mesh
    IF (ANY(map > num_r)) &
      CALL errore(__FILE__, "some G vector are outside the mesh of the Fourier transform", 1)
    !
    ! check that f has size compatible with dfft
    IF (SIZE(f, 1) /= num_r) &
      CALL errore(__FILE__, "size of array not compatible with Fourier transform", 1)
    IF (SIZE(f, 2) /= num_r) &
      CALL errore(__FILE__, "f must be a square matrix", 1)

    ! create work array
    ALLOCATE(work(num_r), STAT = ierr)
    IF (ierr /= 0) &
      CALL errore(__FILE__, "error allocating the work array", ierr)

    ! loop over second index
    DO ir = 1, num_r
      !!
      !! 1. we store the conjugate of a row in the work array \f$w(r) = f^\ast(r, r')\f$
      !!
      work = CONJG(f(:, ir))
      !!
      !! 2. we transform the work array \f$w(r) \rightarrow w(G)\f$
      !!
      CALL fwfft(grid_type, work, dfft)
      !!
      !! 3. we extract the G vectors inside of the sphere \f$f(G, r') = w^\ast(G)\f$
      !!
      f(:num_g, ir) = CONJG(work(map))
      !!
    END DO ! ir

    ! loop over first index (now in reciprocal space)
    DO ig = 1, num_g
      !!
      !! 4. we store a column in the work array \f$w(r') = f(G, r')\f$
      !!
      work = f(ig, :)
      !!
      !! 5. we tranform the work array \f$w(r') \rightarrow w(G')\f$
      !!
      CALL fwfft(grid_type, work, dfft)
      !!
      !! 6. extract the G vectors within the sphere \f$f(G, G') = w(G')\f$
      !!
      f(ig, :num_g) = work(map) * omega
      !!
    END DO ! ig

  END SUBROUTINE fwfft6

  !> Transform an input array \f$f(G, G')\f$ from reciprocal to real space
  !! \f$f(r, r')\f$.
  !!
  !! This is done in the following steps:
  SUBROUTINE invfft6(grid_type, f, dfft, map, omega)

    USE kinds,          ONLY: dp
    USE fft_interfaces, ONLY: invfft
    USE fft_types,      ONLY: fft_type_descriptor

    !> grid type used for the Fourier transform, this is passed to invfft;
    !! check the definition of invfft for a list of options
    CHARACTER(*), INTENT(IN)    :: grid_type

    !> *on input*  the array in reciprocal space \f$f(G, G')\f$ <br>
    !! *on output* the array in real space \f$f(r, r')\f$
    COMPLEX(dp),  INTENT(INOUT) :: f(:,:)

    !> FFT descriptor - this defines the way the Fourier transform is
    !! executed, must be consistent with grid_type
    !! @note the code does not check explicitly if dfft and grid_type are compatible
    TYPE(fft_type_descriptor), INTENT(IN) :: dfft

    !> Because usually a sphere of G-vectors is used, not all points on the FFT
    !! grid are set. This map points from index of the G-points inside the
    !! sphere onto their index in the full G-mesh.
    INTEGER,      INTENT(IN)    :: map(:)

    !> volume of the unit cell
    REAL(dp),     INTENT(IN)    :: omega

    !> complex constant of zero
    COMPLEX(dp),  PARAMETER     :: zero = CMPLX(0.0_dp, 0.0_dp, KIND = dp)

    !> work array for the second index (which is not contigous in memory
    COMPLEX(dp), ALLOCATABLE    :: work(:)

    !> number of points in reciprocal space
    INTEGER num_g

    !> counter on reciprocal space points
    INTEGER ig

    !> number of points in real space
    INTEGER num_r

    !> counter on real space points
    INTEGER ir

    !> check for error in allocation
    INTEGER ierr

    ! initialize helper variables
    num_g = SIZE(map)
    num_r = dfft%nnr

    !
    ! sanity test of the input
    !
    ! reduced mesh must be within full mesh
    IF (ANY(map > num_r)) &
      CALL errore(__FILE__, "some G vector are outside the mesh of the Fourier transform", 1)
    !
    ! check that f has size compatible with dfft
    IF (SIZE(f, 1) /= num_r) &
      CALL errore(__FILE__, "size of array not compatible with Fourier transform", 1)
    IF (SIZE(f, 2) /= num_r) &
      CALL errore(__FILE__, "f must be a square matrix", 1)

    ! create work array
    ALLOCATE(work(num_r), STAT = ierr)
    IF (ierr /= 0) &
      CALL errore(__FILE__, "error allocating the work array", ierr)

    ! loop over first index
    DO ig = 1, num_g
      !!
      !! 1. we store the conjugate of a column in the work array \f$w(G') = f(G, G')\f$
      !!
      ! note - we initialize work, because map only contains a subset of all entries
      work = zero
      work(map) = f(ig, :num_g) / omega
      !!
      !! 2. we transform the work array \f$w(G') \rightarrow w(r')\f$
      !!
      CALL invfft(grid_type, work, dfft)
      !!
      !! 3. we extract the values from the work array \f$f(G, r') = w(r')\f$
      !!
      f(ig, :) = work
      !!
    END DO ! ig

    ! loop over second index (now in real space)
    DO ir = 1, num_r
      !!
      !! 4. we store a row in the work array \f$w(G) = f^\ast(G, r')\f$
      !!
      ! note - we initialize work, because map only contains a subset of all entries
      work = zero
      work(map) = CONJG(f(:num_g, ir))
      !!
      !! 5. we tranform the work array \f$w(G) \rightarrow w(r')\f$
      !!
      CALL invfft(grid_type, work, dfft)
      !!
      !! 6. extract the values from the work array \f$f(r, r') = w^\ast(G')\f$
      !!
      f(:, ir) = CONJG(work)
      !!
    END DO ! ir

  END SUBROUTINE invfft6

END MODULE fft6_module
