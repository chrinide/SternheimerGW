  !-----------------------------------------------------------------------
  ! Copyright (C) 2010-2015 Henry Lambert, Feliciano Giustino
  ! This file is distributed under the terms of the GNU General Public         
  ! License. See the file `LICENSE' in the root directory of the               
  ! present distribution, or http://www.gnu.org/copyleft.gpl.txt .
  !-----------------------------------------------------------------------
SUBROUTINE invert_epsilon(scrcoul_g_in, iq)
USE kinds,         ONLY : DP
USE gwsigma,       ONLY : sigma_c_st
USE freq_gw,       ONLY : fpol, fiu, nfs, nfsmax, nwcoul, wcoul

IMPLICIT NONE    

COMPLEX(DP)       :: scrcoul_g_in(sigma_c_st%ngmt, sigma_c_st%ngmt, nfs, 1)
COMPLEX(DP)       :: work(sigma_c_st%ngmt)
INTEGER           :: ig, igp, npe, irr, icounter, ir, irp
INTEGER           :: isym, iwim, iq, iw
INTEGER           :: iwork(sigma_c_st%ngmt), info


!at Gamma wings of W are 0.
if(iq.eq.1) then
  do iw = 1, nfs
    do ig = 2, sigma_c_st%ngmt
       scrcoul_g_in(ig,1,iw,1)  = dcmplx(0.0d0,0.0d0)
    enddo
    do igp = 2, sigma_c_st%ngmt
       scrcoul_g_in(1,igp,iw,1) = dcmplx(0.0d0,0.0d0)
    enddo
  enddo
endif

!Need block inversion routine if iq is gamma.
do iw = 1, nfs
   call ZGETRF (sigma_c_st%ngmt, sigma_c_st%ngmt,&
   scrcoul_g_in(1:sigma_c_st%ngmt,1:sigma_c_st%ngmt,iw,1), sigma_c_st%ngmt, iwork, info)
   call errore ('invert epsilon', 'factorization', info)
   call ZGETRI (sigma_c_st%ngmt, scrcoul_g_in(1:sigma_c_st%ngmt,1:sigma_c_st%ngmt,iw,1),& 
   sigma_c_st%ngmt, iwork, work, sigma_c_st%ngmt, info)
   call errore ('invert epsilon', 'inversion', info)
enddo

write(6,*)
write(6,'(5x, "Done epsilon inversion.")') 
write(6,'(5x, "")') 

if(iq.eq.1) then
do iw = 1, nfs
    do ig = 2, sigma_c_st%ngmt
       scrcoul_g_in(ig,1,iw,1) = dcmplx(0.0d0,0.0d0)
    enddo
    do igp = 2, sigma_c_st%ngmt
       scrcoul_g_in(1,igp,iw,1) = dcmplx(0.0d0,0.0d0)
    enddo
enddo
endif

!do iw=1,nfs
!    write(6,'(15f12.7)') real(scrcoul_g_in(1:15,1:15,iw,1))
!    print*,""
!enddo

!We store epsilon-1 to disk:
do iw = 1, nfs
   do ig = 1, sigma_c_st%ngmt
      scrcoul_g_in(ig,ig,iw,1) = scrcoul_g_in(ig,ig,iw,1) - dcmplx(1.0d0,0.0d0)
   enddo
enddo

END SUBROUTINE invert_epsilon
