!------------------------------------------------------------------------------
!
! This file is part of the Sternheimer-GW code.
! Parts of this file are taken from the Quantum ESPRESSO software
! P. Giannozzi, et al, J. Phys.: Condens. Matter, 21, 395502 (2009)
!
! Copyright (C) 2010 - 2016 Quantum ESPRESSO group,
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
SUBROUTINE run_nscf(do_band, do_matel, ik)
!-----------------------------------------------------------------------
!
! This is the driver for when gw calls pwscf.
!
!
  USE kinds,              ONLY : DP
  USE control_flags,   ONLY : io_level, conv_ions, twfcollect
  USE basis,           ONLY : starting_wfc, starting_pot, startingconfig
  USE io_files,        ONLY : prefix, tmp_dir, wfc_dir, seqopn, iunwfc
  USE io_global,      ONLY : stdout
  USE lsda_mod,        ONLY : nspin
  USE input_parameters,ONLY : pseudo_dir, force_symmorphic
  USE control_flags,   ONLY : restart
  USE fft_base,        ONLY : dffts
  USE qpoint,          ONLY : xq
  USE check_stop,      ONLY : check_stop_now
  USE control_gw,      ONLY : done_bands, reduce_io, recover, tmp_dir_gw, &
                              ext_restart, bands_computed, lgamma
  USE save_gw,         ONLY : tmp_dir_save
  USE control_flags,   ONLY : iprint, io_level
  USE mp_bands,        ONLY : ntask_groups
  USE disp,            ONLY : xk_kpoints, nqs
  USE klist,           ONLY : xk, wk, nks, nkstot
  USE gwsigma,         ONLY : sigma_x_st, sigma_c_st, nbnd_sig
  USE wvfct,           ONLY : nbnd
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=256) :: dirname, file_base_in, file_base_out
  !
  INTEGER   :: ik
  !
  LOGICAL, INTENT(IN) :: do_band, do_matel
  !
  LOGICAL :: exst, opend
  !
  CALL start_clock( 'PWSCF' )
  !
  CALL clean_pw( .FALSE. )
  !
  CALL close_files( .true. )
  !
  if(do_matel) xq(:) = xk_kpoints(:, ik)
  lgamma = ( (ABS(xq(1))<1.D-8).AND.(ABS(xq(2))<1.D-8).AND.(ABS(xq(3))<1.D-8) )
 !From now on, work only on the _gw virtual directory
  wfc_dir=tmp_dir_gw
  tmp_dir=tmp_dir_gw
 !
 !...Setting the values for the nscf run
  startingconfig    = 'input'
  starting_pot      = 'file'
  starting_wfc      = 'atomic'
  restart = ext_restart
  conv_ions=.true.
! Generate all eigenvectors in IBZ_{k} for Green's function or IBZ_{q} otherwise.
  if(do_matel) nbnd = nbnd_sig
  CALL setup_nscf_green (xq, do_matel)
  CALL init_run()
  WRITE( stdout, '(/,5X,"Calculation of q = ",3F12.7)') xq
  IF (do_band) CALL non_scf ( )
  IF (.NOT.reduce_io.and.do_band) THEN
     IF (nks == 1 .and. io_level < 1) THEN
       ! punch opens the wavefunction file, so we need to close them if they are open
       INQUIRE(UNIT=iunwfc,OPENED=opend)
       IF (opend) CLOSE (UNIT=iunwfc, STATUS='keep')
     END IF
     twfcollect=.FALSE.
     CALL punch( 'all' )
  ENDIF


  IF(do_matel.and.nkstot.ne.nqs) THEN
    WRITE(stdout,'("WARNING: You have given a kpoint not in original BZ.'// &
                   'This could mean full symmetry is not exploited.")') 
  ENDIF

  CALL seqopn( 4, 'restart', 'UNFORMATTED', exst )
  CLOSE( UNIT = 4, STATUS = 'DELETE' )
  ext_restart=.FALSE.
  !
  CALL close_files(.true.)
  !
  bands_computed=.TRUE.
  !
  !  PWscf has run with task groups if available, but in the phonon 
  !  they are not used, apart in particular points, where they are
  !  activated.
  !
  IF (ntask_groups > 1) dffts%have_task_groups=.FALSE.
  !
  CALL stop_clock( 'PWSCF' )
  !
  RETURN
END SUBROUTINE run_nscf
