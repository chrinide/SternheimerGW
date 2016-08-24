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
program gw
!-----------------------------------------------------------------------
!... This is the main driver of the Sternheimer-GW code.
!-----------------------------------------------------------------------
  USE check_stop,        ONLY : check_stop_init
  USE control_gw,        ONLY : do_sigma_exx, do_sigma_matel, do_coulomb,&
                                do_green, multishift, do_sigma_c, do_q0_only,&
                                do_imag, lgamma, output
  USE disp,              ONLY : num_k_pts, w_of_k_start, w_of_k_stop
  USE environment,       ONLY : environment_start
  USE exchange_module,   ONLY : exchange_wrapper
  USE freq_gw,           ONLY : nwsigma, nwsigwin, wsigmamin, wsigmamax, wcoulmax, nwcoul,&
                                wsig_wind_min, wsig_wind_max, nwsigwin
  USE freqbins_module,   ONLY : freqbins, freqbins_type
  USE gwsigma,           ONLY : sigma_x_st, sigma_c_st, nbnd_sig
  USE io_files,          ONLY : diropn
  USE io_global,         ONLY : meta_ionode
  USE mp_global,         ONLY : mp_startup
  USE pp_output_mod,     ONLY : pp_output_open_all
  USE input_parameters,  ONLY : max_seconds, force_symmorphic
  USE sigma_grid_module, ONLY : sigma_grid
  USE sigma_io_module,   ONLY : sigma_io_close_write
  USE timing_module,     ONLY : time_setup
  USE units_gw,          ONLY : iunresid, lrresid, iunalphabeta, lralphabeta
  USE wvfct,             ONLY : nbnd

  IMPLICIT NONE

  integer             :: iq, ik, ierr
  character (LEN=9)   :: codepw = 'PW'
  character (LEN=9)   :: code   = 'SGW'
  character (LEN=256) :: auxdyn
  logical             :: do_band, exst, do_matel

  !> stores the frequencies uses for the calculation
  TYPE(freqbins_type) freq

! Initialize MPI, clocks, print initial messages
  call mp_startup ( start_images=.true. )
  call environment_start ( code )
  call start_clock(time_setup)
  call sgw_opening_message () 
! Initialize GW calculation, Read Ground state information.
  
  call gwq_readin(freq)
  call check_stop_init()
  call check_initial_status(auxdyn)
! Initialize frequency grids, FFT grids for correlation
! and exchange operators, open relevant GW-files.
  call freqbins(do_imag, wsigmamin, wsigmamax, nwsigma, wcoulmax, nwcoul, &
                wsig_wind_min, wsig_wind_max, nwsigwin, freq)
  call sigma_grid(freq)
  call opengwfil()
  call stop_clock(time_setup)
! Calculation W
  if(do_coulomb) call do_stern()
  ik = 1
  do_band  = .TRUE.
  do_matel = .TRUE.
  if (do_q0_only) goto 127
! Calculation of CORRELATION energy \Sigma^{c}_{k}=\sum_{q}G_{k-q}{W_{q}-v_{q}}:
  if (do_imag) then
      do ik = w_of_k_start, w_of_k_stop
         call start_clock(time_setup)
         call run_nscf(do_band, do_matel, ik)
         call initialize_gw(.FALSE.)
         if (do_sigma_c.and.multishift) call diropn(iunresid, 'resid', lrresid, exst)
         if (do_sigma_c.and.multishift) call diropn(iunalphabeta, 'alphbet', lralphabeta, exst)
         call stop_clock(time_setup)
         if (do_sigma_c) call sigma_c_im(ik, freq)
         if (do_sigma_c.and.multishift) then
            close(unit = iunresid, status = 'DELETE')
            close(unit = iunalphabeta, status = 'DELETE')
         endif
! Calculation of EXCHANGE energy \Sigma^{x}_{k}= \sum_{q}G_{k}{v_{k-S^{-1}q}}:
         if (do_sigma_exx) call exchange_wrapper(ik)
! Calculation of Matrix Elements <n\k| V^{xc}, \Sigma^{x}, \Sigma^{c}(iw) |n\k>:
         if (do_sigma_matel) then
           if (meta_ionode .AND. ik == w_of_k_start) then         
             call pp_output_open_all(num_k_pts, nbnd_sig, nwsigwin, nwsigma, output)
           end if
           call sigma_matel(ik, freq)
         end if
         call clean_pw_gw(ik, .TRUE.)
      enddo
  else
      do ik = w_of_k_start, w_of_k_stop
         call start_clock(time_setup)
         call run_nscf(do_band, do_matel, ik)
         call initialize_gw()
         if(do_sigma_c.and.multishift) call diropn(iunresid, 'resid', lrresid, exst)
         if(do_sigma_c.and.multishift) call diropn(iunalphabeta, 'alphbet',lralphabeta, exst)
         call stop_clock(time_setup)
         if(do_sigma_c) call sigma_c_re(ik, freq)
         if (do_sigma_c.and.multishift) then
            close(unit = iunresid, status = 'DELETE')
            close(unit = iunalphabeta, status = 'DELETE')
         endif
         if (do_sigma_exx .and. .not.do_sigma_exxG) then   
             call sigma_exch(ik)
         else if(do_sigma_exx .and. do_sigma_exxG) then
             call sigma_exchg(ik)
         endif
         if (do_sigma_matel) call sigma_matel(ik, freq)
         call clean_pw_gw(ik, .TRUE.)
      enddo
  endif
  127 continue
  call close_gwq(.TRUE.)
  IF (meta_ionode) CALL sigma_io_close_write(output%unit_sigma)
  call stop_gw( .TRUE. )
end program gw
