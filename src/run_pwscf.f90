!
! Copyright (C) 2009 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-----------------------------------------------------------------------
SUBROUTINE run_pwscf(do_band)
!-----------------------------------------------------------------------
!
! This is the driver for when gw calls pwscf.
!
!
  USE control_flags,   ONLY : conv_ions, twfcollect
  USE basis,           ONLY : starting_wfc, starting_pot, startingconfig
  USE io_files,        ONLY : prefix, tmp_dir
  USE lsda_mod,        ONLY : nspin
  USE input_parameters,ONLY : pseudo_dir
  USE control_flags,   ONLY : restart
  USE qpoint,          ONLY : xq
  USE control_gw,      ONLY : done_bands, reduce_io, recover, tmp_dir_gw, &
                              ext_restart, bands_computed
  USE save_gw,         ONLY : tmp_dir_save
  USE control_flags,   ONLY: iprint
  USE gvect,           ONlY: ecutwfc, g
  USE gwsigma,         ONLY: ecutsco, ecutsex, ngmpol
  USE cell_base,       ONLY: tpiba
  USE symm_base,     ONLY : nsym, s, time_reversal, t_rev, ftau, invs
  !
  IMPLICIT NONE
  !
  CHARACTER(LEN=256) :: dirname, file_base_in, file_base_out
  !
  LOGICAL, INTENT(IN) :: do_band
  !
  LOGICAL :: exst
  !
  INTEGER :: ig, isym
  !
  CALL start_clock( 'PWSCF' )
  !
  CALL clean_pw( .FALSE. )
  !
  CALL close_files()
  !

  !From now on, work only on the _gw virtual directory
  !Somehow this statement got deleted.

  wfc_dir=tmp_dir_gw
  tmp_dir=tmp_dir_gw

  ! ... Setting the values for the nscf run

  startingconfig    = 'input'
  starting_pot      = 'file'
  starting_wfc      = 'atomic'
  restart = ext_restart

  CALL restart_from_file()
  conv_ions=.true.
!
  CALL setup_nscf (xq)
  CALL init_run()

  IF (do_band) write(6,'("Calling PW electrons")')
  IF (do_band) CALL electrons()
  !
  IF (.NOT.reduce_io.and.do_band) THEN
     twfcollect=.FALSE. 
     CALL punch( 'all' )
     done_bands=.TRUE.
  ENDIF
  !
  !CALL seqopn( 4, 'restart', 'UNFORMATTED', exst )
  !CLOSE( UNIT = 4, STATUS = 'DELETE' )
  ext_restart=.FALSE.
  !
  CALL close_files()
  !
  bands_computed=.TRUE.
  !
  CALL stop_clock( 'PWSCF' )
  !
  RETURN
END SUBROUTINE run_pwscf