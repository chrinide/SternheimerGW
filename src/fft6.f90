subroutine fft6(f_g, f_r, fc, conv)
  USE kinds,          ONLY : DP
  USE cell_base,      ONLY : tpiba2, tpiba, omega, alat, at
  USE fft_base,       ONLY : dffts
  USE fft_interfaces, ONLY : invfft, fwfft
  USE fft_custom,     ONLY : fft_cus, set_custom_grid, ggent, gvec_init

IMPLICIT NONE

TYPE(fft_cus) fc 
COMPLEX(DP)  :: f_g(fc%ngmt, fc%ngmt)
COMPLEX(DP)  :: f_r(fc%dfftt%nnr, fc%dfftt%nnr)
COMPLEX(DP)  :: aux (fc%dfftt%nnr)
COMPLEX(DP)  :: ci, czero

INTEGER :: ig, igp, irr, icounter, ir, irp
INTEGER :: conv

ci = dcmplx(0.0d0, 1.d0)
czero = dcmplx(0.0d0, 0.0d0)

if(conv.eq.1) then
            do ig = 1, fc%ngmt
               aux(:) = czero
               do igp = 1, fc%ngmt
                  aux(fc%nlt(igp)) = f_g(ig,igp)
               enddo
               call invfft('Custom', aux, fc%dfftt)
               do irp = 1, fc%dfftt%nnr
                  f_r(ig, irp) = aux(irp) / omega
               enddo
            enddo
            do irp = 1, fc%dfftt%nnr 
               aux = czero
                    do ig = 1, fc%ngmt
                           aux(fc%nlt(ig)) = conjg(f_r(ig,irp))
                    enddo
               call invfft('Custom', aux, fc%dfftt)
               f_r(1:fc%dfftt%nnr,irp) = conjg ( aux )
            enddo
else if (conv.eq.-1) then
    do ir = 1, fc%dfftt%nnr
      aux = (0.0d0, 0.0d0)
      do irp = 1, fc%dfftt%nnr
         aux(irp) = f_r(ir,irp)
      enddo
!call cfft3d (aux, nr1sco, nr2sco, nr3sco, nr1sco, nr2sco, nr3sco, -1)
      call fwfft('Custom', aux, fc%dfftt)
      do igp = 1, fc%ngmt
         f_r (ir, igp) = aux(fc%nlt(igp))
      enddo
    enddo
    do igp = 1, fc%ngmt
      aux = czero
      do ir = 1, fc%dfftt%nnr
        aux(ir) = conjg (f_r(ir,igp))
      enddo
!call cfft3d (aux, nr1sco, nr2sco, nr3sco, nr1sco, nr2sco, nr3sco, -1)
      call fwfft ('Custom', aux, fc%dfftt)
      do ig = 1, fc%ngmt
         f_r(ig, igp) = conjg ( aux( fc%nlt( ig )) ) * omega
      enddo
    enddo

    f_g(1:fc%ngmt, 1:fc%ngmt) = f_r(1:fc%ngmt,1:fc%ngmt)

else 
    call errore (' FFT routines',' Wrong switch',1)
end if
end subroutine fft6