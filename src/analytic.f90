!------------------------------------------------------------------------------
!
! This file is part of the SternheimerGW code.
! 
! Copyright (C) 2010 - 2017
! Henry Lambert, Martin Schlipf, and Feliciano Giustino
!
! SternheimerGW is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! SternheimerGW is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with SternheimerGW. If not, see
! http://www.gnu.org/licenses/gpl.html .
!
!------------------------------------------------------------------------------ 
!> Provides a wrapper around the various routines to perform an analytic continuation.
!!
!! Depending on the setting either a Godby-Needs PP model, a Pade approximant,
!! or the AAA algorithm is used to expand the given quantity from a few points
!! to the whole complex plane.
MODULE analytic_module

  IMPLICIT NONE

  !> Use the Godby-Needs plasmon pole model.
  INTEGER, PARAMETER :: godby_needs = 1

  !> Use the conventional Pade approximation.
  INTEGER, PARAMETER :: pade_approx = 2

  !> Use the robust Pade approximation.
  INTEGER, PARAMETER :: pade_robust = 3

  !> Use the AAA rational approximation.
  INTEGER, PARAMETER :: aaa_approx = 4

CONTAINS

!> Wrapper routine to evaluate the analytic continuation using different methods.
SUBROUTINE analytic_coeff(model_coul, thres, freq, scrcoul_g)

  USE aaa_module,         ONLY : aaa_coeff
  USE freqbins_module,    ONLY : freqbins_type, freqbins_symm
  USE godby_needs_module, ONLY : godby_needs_coeffs
  USE kinds,              ONLY : dp
  USE pade_module,        ONLY : pade_coeff_robust

  !> The selected screening model.
  INTEGER, INTENT(IN)  :: model_coul

  !> The threshold determining the accuracy of the calculation.
  REAL(dp), INTENT(IN) :: thres

  !> The frequency grid used for the calculation.
  TYPE(freqbins_type), INTENT(IN) :: freq

  !> *on input*: the screened Coulomb interaction on the frequency grid<br>
  !! *on output*: the coefficients used to evaluate the screened Coulomb
  !! interaction at an arbitrary frequency
  COMPLEX(dp), INTENT(INOUT) :: scrcoul_g(:,:,:)

  !> frequency used for Pade coefficient (will be extended if frequency
  !! symmetry is used)
  COMPLEX(dp), ALLOCATABLE :: z(:)

  !> value of the screened Coulomb interaction on input mesh
  COMPLEX(dp), ALLOCATABLE :: u(:)

  !> coefficients of the Pade approximation
  COMPLEX(dp), ALLOCATABLE :: a(:)

  !> coefficients of the AAA approximation
  COMPLEX(dp), ALLOCATABLE :: aaa(:,:)

  !> the number of G vectors in the correlation grid
  INTEGER :: num_g_corr

  !> loop variables for G and G'
  INTEGER :: ig, igp

  !> total number of frequencies
  INTEGER :: num_freq

  !> maximum number of polynomials generated by AAA
  INTEGER :: mmax

  !> actual number of polynomial generated by AAA
  INTEGER :: mm

  !> complex constant of zero
  COMPLEX(dp), PARAMETER :: zero = CMPLX(0.0_dp, 0.0_dp, KIND = dp)

  ! initialize helper variable
  num_freq = SIZE(freq%solver)
  num_g_corr = SIZE(scrcoul_g, 1)

  ! sanity check for the array size
  IF (SIZE(scrcoul_g, 2) /= num_g_corr) &
    CALL errore(__FILE__, "input array should have same dimension for G and G'", 1)
  IF (SIZE(scrcoul_g, 3) /= freq%num_freq()) &
    CALL errore(__FILE__, "frequency dimension of Coulomb inconsistent with frequency mesh", 1)

  !
  ! analytic continuation to the complex plane
  !
  SELECT CASE (model_coul)

  !! 1. Godby-Needs plasmon-pole model - assumes that the function can be accurately
  !!    represented by a single pole and uses the value of the function at two
  !!    frequencies \f$\omega = 0\f$ and \f$\omega = \omega_{\text{p}}\f$ to determine
  !!    the parameters.
  CASE (godby_needs)
    CALL godby_needs_coeffs(AIMAG(freq%solver(2)), scrcoul_g)

  !! 2. Pade expansion - evaluate Pade coefficients for a continued fraction expansion
  !!    using a given frequency grid; symmetry may be used to extend the frequency grid
  !!    to more points.
  CASE (pade_approx) 

    ! allocate helper arrays
    ALLOCATE(u(freq%num_freq()))
    ALLOCATE(a(freq%num_freq()))

    ! use symmetry to extend the frequency mesh
    CALL freqbins_symm(freq, z, scrcoul_g)

    ! evalute Pade approximation for all G and G'
    DO igp = 1, num_g_corr
      DO ig = 1, num_g_corr

        ! set frequency and value used to determine the Pade coefficients
        u = scrcoul_g(ig, igp, :)

        ! evaluate the coefficients
        CALL pade_coeff(freq%num_freq(), z, u, a)

        ! store the coefficients in the same array
        scrcoul_g(ig, igp, :) = a

      END DO ! ig
    END DO ! igp

  !! 3. robust Pade expansion - evaluate Pade coefficients using a circular frequency
  !!    mesh in the complex plane
  CASE (pade_robust) 
    CALL pade_coeff_robust(freq%solver, thres, scrcoul_g)

  !! 4. AAA rational approximation - evaluate coefficient for a given frequency mesh
  CASE (aaa_approx)

    ! use symmetry to extend the frequency mesh
    CALL freqbins_symm(freq, z, scrcoul_g)

    ! allocate helper array
    ALLOCATE(u(freq%num_freq()))

    ! note that AAA will generate 3 coefficients for every input point so
    ! that we can use at most 1/3 of the frequencies
    mmax = SIZE(u) / 3

    ! evalute AAA approximation for all G and G'
    DO igp = 1, num_g_corr
      DO ig = 1, num_g_corr

        ! set frequency and value used to determine the Pade coefficients
        u = scrcoul_g(ig, igp, :)

        ! evaluate the coefficients
        CALL aaa_coeff(z, u, aaa, tol = thres, mmax = mmax)

        ! determine number of polynomials generated
        mm = SIZE(aaa, 1)

        ! store the coefficients in the same array
        scrcoul_g(ig, igp, :) = zero
        scrcoul_g(ig, igp, 0 * mmax + 1 : 0 * mmax + mm) = aaa(:, 1)
        scrcoul_g(ig, igp, 1 * mmax + 1 : 1 * mmax + mm) = aaa(:, 2)
        scrcoul_g(ig, igp, 2 * mmax + 1 : 2 * mmax + mm) = aaa(:, 3)

      END DO ! ig
    END DO ! igp

  CASE DEFAULT
    CALL errore(__FILE__, "No screening model chosen!", 1)
  END SELECT

END SUBROUTINE analytic_coeff

!> Construct the screened Coulomb interaction for an arbitrary frequency.
SUBROUTINE analytic_eval(gmapsym, grid, freq_in, scrcoul_coeff, freq_out, scrcoul)

  USE aaa_module,         ONLY : aaa_eval
  USE control_gw,         ONLY : model_coul 
  USE freqbins_module,    ONLY : freqbins_type, freqbins_symm
  USE godby_needs_module, ONLY : godby_needs_model
  USE kinds,              ONLY : dp
  USE pade_module,        ONLY : pade_eval_robust
  USE sigma_grid_module,  ONLY : sigma_grid_type
  USE timing_module,      ONLY : time_construct_w

  !> The symmetry map from the irreducible point to the current one
  INTEGER,                  INTENT(IN)  :: gmapsym(:)

  !> the FFT grids on which the screened Coulomb interaction is evaluated
  TYPE(sigma_grid_type),    INTENT(IN)  :: grid

  !> the frequency grid on which W was evaluated
  TYPE(freqbins_type),      INTENT(IN)  :: freq_in

  !> the coefficients of the screened Coulomb potential used for the analytic continuation
  COMPLEX(dp),              INTENT(IN)  :: scrcoul_coeff(:,:,:)

  !> the frequency for which the screened Coulomb potential is evaluated
  COMPLEX(dp),              INTENT(IN)  :: freq_out

  !> The screened Coulomb interaction symmetry transformed and parallelized over images.
  !! The array is appropriately sized to do a FFT on the output.
  COMPLEX(dp), ALLOCATABLE, INTENT(OUT) :: scrcoul(:,:)

  !> Counter on the G and G' vector
  INTEGER ig, igp

  !> corresponding point to G' in global G list
  INTEGER igp_g

  !> allocation error flag
  INTEGER ierr

  !> maximum number of points for AAA approximation
  INTEGER mmax

  !> helper array to extract the current coefficients
  COMPLEX(dp), ALLOCATABLE :: coeff(:)

  !> helper array for AAA approximation
  COMPLEX(dp), ALLOCATABLE :: aaa(:,:)

  !> helper array for the frequencies
  COMPLEX(dp), ALLOCATABLE :: freq(:)

  !> complex constant of zero
  COMPLEX(dp), PARAMETER :: zero = CMPLX(0.0_dp, 0.0_dp, KIND = dp)

  CALL start_clock(time_construct_w)

  !
  ! create and initialize output array
  ! allocate space so that we can perform an in-place FFT on the array
  !
  ALLOCATE(scrcoul(grid%corr%dfftt%nnr, grid%corr_par%dfftt%nnr), STAT = ierr)
  IF (ierr /= 0) THEN
    CALL errore(__FILE__, "allocation of screened Coulomb potential failed", 1)
    RETURN
  END IF
  scrcoul = zero

  ! helper array for frequencies in case of symmetry
  IF (model_coul == pade_approx) THEN
    CALL freqbins_symm(freq_in, freq)
  END IF

  !
  ! construct screened Coulomb interaction
  !
  !! The screened Coulomb interaction is interpolated with either Pade or
  !! Godby-Needs analytic continuation. We only evaluate W at the irreducible
  !! mesh, but any other point may be obtained by
  !! \f{equation}{
  !!   W_{S q}(G, G') = W_{q}(S^{-1} G, S^{-1} G')~.
  !! \f}
  ALLOCATE(coeff(freq_in%num_freq()))

  ! allocate helper array for AAA approximation
  IF (model_coul == aaa_approx) THEN
    mmax = SIZE(coeff) / 3
    ALLOCATE(aaa(mmax, 3))
  END IF

  DO igp = 1, grid%corr_par%ngmt
    !
    ! get the global corresponding index
    igp_g = grid%corr_par%ig_l2gt(igp)

    DO ig = 1, grid%corr%ngmt

      ! symmetry transformation of the coefficients
      coeff = scrcoul_coeff(gmapsym(ig), gmapsym(igp_g), :)

      SELECT CASE (model_coul)

      CASE (pade_approx)
        !
        ! Pade analytic continuation
        CALL pade_eval(freq_in%num_freq(), freq, coeff, freq_out, scrcoul(ig, igp))

      CASE (pade_robust)
        !
        ! robust Pade analytic continuation
        CALL pade_eval_robust(coeff, freq_out, scrcoul(ig, igp))

      CASE (godby_needs)
        !
        ! Godby-Needs Pole model
        scrcoul(ig, igp) = godby_needs_model(freq_out, coeff)

      CASE (aaa_approx)
        !
        ! AAA approximation
        aaa = RESHAPE(coeff(:SIZE(aaa)), [mmax, 3])
        scrcoul(ig, igp) = aaa_eval(aaa, freq_out)

      CASE DEFAULT
        CALL errore(__FILE__, "No screening model chosen!", 1)

      END SELECT

    END DO ! ig
  END DO ! igp

  CALL stop_clock(time_construct_w)

END SUBROUTINE analytic_eval

END MODULE analytic_module
