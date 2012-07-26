SUBROUTINE sigma_matel (ik0)
  USE io_global,            ONLY : stdout, ionode_id, ionode
  USE io_files,             ONLY : prefix, iunigk
  USE kinds,                ONLY : DP
  USE gvect,                ONLY : ngm, nrxx, g, nr1, nr2, nr3, nrx1, nrx2, nrx3, nl
  USE gsmooth,              ONLY : nrxxs, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, nls, ngms
  USE constants,            ONLY : e2, fpi, RYTOEV, tpi, pi
  USE freq_gw,              ONLY : fpol, fiu, nfs, nwsigma, wsigma
  USE klist,                ONLY : xk, wk, nkstot
  USE wvfct,                ONLY : nbnd, npw, npwx, igk, g2kin, et
  USE qpoint,               ONLY : xq, npwq, igkq, nksq, ikks, ikqs
  USE units_gw,             ONLY : iunsigma, iuwfc, lrwfc, lrsigma,lrsex, iunsex
  USE control_gw,           ONLY : nbnd_occ, lgamma
  USE wavefunctions_module, ONLY : evc
  USE gwsigma,              ONLY : ngmsig, nbnd_sig, sigma_g_ex, ngmsco, ngmsex
  USE disp,                 ONLY : xk_kpoints
  USE noncollin_module,     ONLY : nspin_mag
  USE eqv,                  ONLY : dmuxc
  USE scf,                  ONLY : rho, rho_core, rhog_core, scf_type, v
  USE fft_scalar,           ONLY : cfft3ds, cfft3d
  USE fft_base,             ONLY : dffts
  USE fft_parallel,         ONLY : tg_cft3s

IMPLICIT NONE
INTEGER                   ::   ig, igp, nw, iw, ibnd, jbnd, ios, ipol, ik0, ir, counter
REAL(DP)                  ::   w_ryd(nwsigma)
REAL(DP)                  ::   resig_diag(nwsigma,nbnd_sig), imsig_diag(nwsigma,nbnd_sig),&
                               et_qp(nbnd_sig), a_diag(nwsigma,nbnd_sig)
REAL(DP)                  ::   dresig_diag(nwsigma,nbnd_sig), vxc_tr, vxc_diag(nbnd_sig),&
                               sigma_ex_tr, sigma_ex_diag(nbnd_sig)
REAL(DP)                  ::   resig_diag_tr(nwsigma), imsig_diag_tr(nwsigma), a_diag_tr(nwsigma),&
                               et_qp_tr, z_tr, z(nbnd_sig)
REAL(DP)                  ::   one
COMPLEX(DP)               ::   czero
COMPLEX(DP)               ::   aux(ngmsex), psic(nrxx), vpsi(ngm),auxsco(ngmsco)
COMPLEX(DP)               ::   ZDOTC, sigma_band_c(nbnd_sig, nbnd_sig, nwsigma),&
                               sigma_band_ex(nbnd_sig, nbnd_sig), vxc(nbnd_sig,nbnd_sig)
LOGICAL                   ::   do_band, do_iq, setup_pw, exst
INTEGER                   ::   iman, nman, ndeg(nbnd_sig), ideg, iq, ikq
COMPLEX(DP), ALLOCATABLE  ::   sigma(:,:,:)
COMPLEX(DP), ALLOCATABLE  ::   evc_tmp_j(:), evc_tmp_i(:)
INTEGER, ALLOCATABLE      ::   igkq_ig(:) 
INTEGER, ALLOCATABLE      ::   igkq_tmp(:) 

!For VXC matrix elements:
REAL(DP) :: vtxc, etxc, ehart, eth, charge

ALLOCATE (igkq_tmp(npwx))
ALLOCATE (igkq_ig(npwx))


     one   = 1.0d0 
     czero = (0.0d0, 0.0d0)
     w_ryd = wsigma/RYTOEV

     nbnd = nbnd_sig 

     iq = 1 
     xq(:) = xk_kpoints(:, ik0)
     lgamma = ( xq(1) == 0.D0 .AND. xq(2) == 0.D0 .AND. xq(3) == 0.D0 )
     setup_pw = .TRUE.
     do_band = .TRUE.

     if (lgamma) then
           ikq = ik0
        else
           ikq = 2*ik0
     endif

     write(stdout,'(/4x,"k0(",i3," ) = (",3f7.3," )")') ikq, (xk (ipol,ikq) , ipol = 1, 3)
     WRITE(6,'("Running PWSCF")')
     CALL run_pwscf(do_band)
     CALL initialize_gw()

IF (ionode) THEN
     if (nksq.gt.1) rewind (unit = iunigk)
     if (nksq.gt.1) then
        read (iunigk, err = 100, iostat = ios) npw, igk
 100        call errore ('green_linsys', 'reading igk', abs (ios) )
     endif
  
     if(lgamma) npwq = npw

     if (.not.lgamma.and.nksq.gt.1) then
           read (iunigk, err = 100, iostat = ios) npwq, igkq
 200             call errore ('green_linsys', 'reading igkq', abs (ios) )
     endif

!if just gamma then psi_{\Gamma} should be first entry in list.
   if (lgamma) then
     CALL davcio (evc, lrwfc, iuwfc, 1, -1)
   else
!else then psi_{\k+\gamma = \psi_{k}} should be second entry in list.
     CALL davcio (evc, lrwfc, iuwfc, 2, -1)
   endif

  WRITE(6,'("NBND")')
  WRITE(6,*) nbnd_sig
! generate v_xc(r) in real space:
  v%of_r(:,:) = (0.0d0)
  CALL v_xc( rho, rho_core, rhog_core, etxc, vtxc, v%of_r )
  vxc(:,:) = (0.0d0, 0.0d0)
  WRITE(6,'("Taking Matels.")')
  WRITE(6,'("Taking NPWQ.", i4)')npwq

  do jbnd = 1, nbnd_sig
     psic = czero
     do ig = 1, npwq
        psic ( nls (igkq(ig)) ) = evc(ig, jbnd)
     enddo

!Need to do this fft according to igkq arrays and switching between serial/parallel routines. 
     call cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, +2)

     do ir = 1, nrxx
        psic (ir) = psic(ir) * v%of_r (ir,1)
     enddo

     call cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, -2)

     do ig = 1, npwq
        vpsi(ig) = psic(nls(igkq(ig)))
     enddo

     do ibnd = 1, nbnd_sig
        vxc(ibnd,jbnd) = ZDOTC (npwq, evc (1, ibnd), 1, vpsi, 1)
     enddo
  enddo

  write(stdout,'(4x,"VXC (eV)")')
  write(stdout,'(8(1x,f7.3))') real(vxc(:,:))*RYTOEV

  WRITE(6,'("Max number Plane Waves WFC ", i4)') npwx
  WRITE(6,'("Sigma_Ex Matrix Element")') 

!igkq_tmp is index of G-vector on gamma_centered grid.
!igkq_ig is the index of the g_vector evc(ig) on the k+G grid.
!counter is the total number which fall within some cutoff npwq,
!ngmsex, etc. 

 counter  = 0
 igkq_tmp(:) = 0
 igkq_ig(:)  = 0

 do ig = 1, npwq
      if((igkq(ig).le.ngmsex).and.((igkq(ig)).gt.0)) then
        counter = counter + 1
        igkq_tmp (counter) = igkq(ig)
        igkq_ig  (counter) = ig
    endif
 enddo

!WRITE(6,'("Number of G vectors for Sigma_ex", i4)') counter
!@10TION: only looping up to counter so need to watch that...

! setting these arrays to dim ngmsex lets us calculate all matrix elements with sigma as 
! a vector^{T}*matrix*vector product.
 ALLOCATE ( sigma_g_ex  (ngmsex, ngmsex))
 ALLOCATE (evc_tmp_i(ngmsex))
 ALLOCATE (evc_tmp_j(ngmsex))

 sigma_g_ex(:,:) = (0.0d0, 0.0d0)
 CALL davcio(sigma_g_ex, lrsex, iunsex, 1, -1)
 sigma_band_ex (:, :) = czero
 do ibnd = 1, nbnd_sig
     evc_tmp_i(:) = czero
  do jbnd = 1, nbnd_sig
     evc_tmp_j(:) = czero
     do ig = 1, counter
        evc_tmp_i(igkq_tmp(ig)) = evc(igkq_ig(ig), ibnd) 
     enddo
     do ig = 1, counter
        do igp = 1, counter
           aux(igp) = sigma_g_ex (igp, ig)
           evc_tmp_j(igkq_tmp(igp)) = evc(igkq_ig(igp), jbnd)
        enddo
           sigma_band_ex (ibnd, jbnd) = sigma_band_ex (ibnd, jbnd) + &
           evc_tmp_i (ig) * ZDOTC(ngmsex, evc_tmp_j (1:ngmsex), 1, aux, 1)
      enddo
  enddo
 enddo

 DEALLOCATE(sigma_g_ex)
 DEALLOCATE(evc_tmp_i)
 DEALLOCATE(evc_tmp_j)

 WRITE(6,*) 
 write(stdout,'(4x,"Sigma_ex (eV)")')
 write(stdout,'(8(1x,f7.3))') real(sigma_band_ex(:,:))*RYTOEV

!MATRIX ELEMENTS OF SIGMA_C:
 WRITE(6,*) 
 WRITE(6,'("Sigma_C Matrix Element")') 
 ALLOCATE (sigma(ngmsco,ngmsco,nwsigma)) 
 ALLOCATE (evc_tmp_i(ngmsco))
 ALLOCATE (evc_tmp_j(ngmsco))

 counter     = 0
 igkq_tmp(:) = 0
 igkq_ig(:)  = 0
 do ig = 1, npwq
    if((igkq(ig).le.ngmsco).and.((igkq(ig)).gt.0)) then
        counter = counter + 1
        igkq_tmp (counter) = igkq(ig)
        igkq_ig  (counter) = ig
    endif
 enddo

!do iw = 1, nwsigma
!CALL davcio (sigma, lrsigma, iunsigma, iw, -1)
 CALL davcio (sigma, lrsigma, iunsigma, 1, -1)

 WRITE(6,'("Number of G vectors for sigma_corr, npwq", 2i4)') counter, npwq
 WRITE(6,*) 

 sigma_band_c (:,:,:) = czero
 do ibnd = 1, nbnd_sig
     evc_tmp_i(:) = czero
  do jbnd = 1, nbnd_sig
     evc_tmp_j(:) = czero
   do iw = 1, nwsigma
      do ig = 1, counter
            evc_tmp_i(igkq_tmp(ig)) = evc(igkq_ig(ig), ibnd) 
      enddo
      do ig = 1, counter
            do igp = 1, counter
               auxsco(igp) = sigma (igp, ig, iw)
               evc_tmp_j(igkq_tmp(igp)) = evc(igkq_ig(igp), jbnd)
            enddo
            sigma_band_c (ibnd, jbnd, iw) = sigma_band_c (ibnd, jbnd, iw) + &
            evc_tmp_i(ig)*ZDOTC(counter, evc_tmp_j (1:counter), 1, auxsco, 1)
      enddo
   enddo
  enddo
 enddo

!enddo !iw nwsigma

 DEALLOCATE (sigma) 
 DEALLOCATE(evc_tmp_i)
 DEALLOCATE(evc_tmp_j)

 do ibnd = 1, nbnd_sig
    do iw = 1, nwsigma
      resig_diag (iw,ibnd) = real( sigma_band_c(ibnd, ibnd, iw)) + real(sigma_band_ex(ibnd, ibnd)) 
      dresig_diag (iw,ibnd) = resig_diag (iw,ibnd) - real( vxc(ibnd,ibnd) )
      imsig_diag (iw,ibnd) = aimag ( sigma_band_c (ibnd, ibnd, iw) )
      a_diag (iw,ibnd) = one/pi * abs ( imsig_diag (iw,ibnd) ) / &
          ( abs ( w_ryd(iw) - et(ibnd, ikq) - ( resig_diag (iw,ibnd) - vxc(ibnd,ibnd) ) )**2.d0 &
          + abs ( imsig_diag (iw,ibnd) )**2.d0 )
    enddo
      call qp_eigval ( nwsigma, w_ryd, dresig_diag(1,ibnd), et(ibnd,ikq), et_qp (ibnd), z(ibnd) )
 enddo

  ! Now take the trace (get rid of phase arbitrariness of the wfs)
  ! (alternative and more approrpiate: calculate non-diagonal, elements of
  ! degenerate subspaces and diagonalize)
  ! count degenerate manifolds and degeneracy...

   nman = 1
   ndeg = 1

   do ibnd = 2, nbnd_sig
     if ( abs( et (ibnd, ikq) - et (ibnd-1, ikq)  ) .lt. 1.d-5 ) then
       ndeg (nman) = ndeg(nman) + 1
     else
       nman = nman + 1
     endif
   enddo

   write(6,'(" Manifolds")')
   write (stdout, *) nman, (ndeg (iman) ,iman=1,nman)
   write(6,*)
  
  ! ...and take the trace over the manifold
  
  ibnd = 0
  jbnd = 0
  do iman = 1, nman
    resig_diag_tr = 0.d0
    imsig_diag_tr = 0.d0
    a_diag_tr = 0.d0
    et_qp_tr = 0.d0
    z_tr = 0.d0
    vxc_tr = 0.d0
    sigma_ex_tr = 0.0d0

    do ideg = 1, ndeg(iman)
       ibnd = ibnd + 1
       resig_diag_tr = resig_diag_tr + resig_diag (:,ibnd)
       imsig_diag_tr = imsig_diag_tr + imsig_diag (:,ibnd)
       a_diag_tr = a_diag_tr + a_diag (:,ibnd)
       et_qp_tr = et_qp_tr + et_qp (ibnd)
       z_tr = z_tr + z (ibnd)
       vxc_tr = vxc_tr + real(vxc(ibnd,ibnd))
       sigma_ex_tr = sigma_ex_tr + real(sigma_band_ex(ibnd,ibnd))
    enddo

    do ideg = 1, ndeg(iman)
      jbnd = jbnd + 1
      resig_diag (:,jbnd) = resig_diag_tr / float( ndeg(iman) )
      imsig_diag (:,jbnd) = imsig_diag_tr / float( ndeg(iman) )
      a_diag (:,jbnd) = a_diag_tr / float( ndeg(iman) )
      et_qp (jbnd) = et_qp_tr / float( ndeg(iman) )
      z (jbnd) = z_tr / float( ndeg(iman) )
      vxc_diag (jbnd) = vxc_tr / float( ndeg(iman) )
      sigma_ex_diag(jbnd) = sigma_ex_tr/float(ndeg(iman))
    enddo
  enddo

  write(stdout,*)
  write(stdout,'(/4x,"LDA eigenval (eV)",8(1x,f7.3))')     et(1:nbnd_sig, ikq)*RYTOEV
  write(stdout,'(4x,"Vxc expt val (eV)",8(1x,f7.3))')      vxc_diag(1:nbnd_sig)*RYTOEV
  write(stdout,'(4x,"Sigma_ex val (eV)",8(1x,f7.3))')      sigma_ex_diag(1:nbnd_sig)*RYTOEV
  write(stdout,'(4x,"GW qp energy (eV)",8(1x,f7.3))')      et_qp(1:nbnd_sig)*RYTOEV
  write(stdout,'(4x,"GW qp renorm     ",8(1x,f7.3)/)')     z(1:nbnd_sig)

  do iw = 1, nwsigma
    write(stdout,'(9f15.8)') wsigma(iw), (RYTOEV*resig_diag (iw,ibnd), ibnd=1,nbnd_sig)
  enddo

  write(stdout,*)
  do iw = 1, nwsigma
    write(stdout,'(9f15.8)') wsigma(iw), (RYTOEV*imsig_diag (iw,ibnd), ibnd=1,nbnd_sig)
  enddo

  write(stdout,*)
  do iw = 1, nwsigma
    write(stdout,'(9f15.8)') wsigma(iw), (a_diag (iw,ibnd)/RYTOEV, ibnd=1,nbnd_sig)
  enddo
ENDIF

    CALL clean_pw_gw(ikq)
RETURN
END SUBROUTINE sigma_matel


!----------------------------------------------------------------
  SUBROUTINE  qp_eigval ( nw, w, sig, et, et_qp, z )
!----------------------------------------------------------------
!
  USE kinds,         ONLY : DP

  IMPLICIT NONE

  integer :: nw, iw, iw1, iw2
  real(DP) :: w(nw), sig(nw), et, et_qp, dw, w1, w2, sig_et, sig1, sig2, z, sig_der, one
  
  one = 1.0d0
  dw = w(2)-w(1)

 if ((et.lt.w(1)+dw).or.(et.gt.w(nw)-dw)) then
 !call errore ('qp_eigval','original eigenvalues outside the frequency range of the self-energy',1)
 write(6,*)et, w(1)+dw, w(nw) - dw
 write(6,'("original eigenvalues outside the frequency range of the self-energy")')
 return
 endif

  iw = 1
  do while ((iw.lt.nw).and.(w(iw).lt.et))
    iw = iw + 1
    iw1 = iw-1
    iw2 = iw
  enddo

  w1 = w(iw1)
  w2 = w(iw2)
  sig1 = sig(iw1)
  sig2 = sig(iw2)
!
  sig_et = sig1 + ( sig2 - sig1 ) * (et-w1) / (w2-w1)
!
  sig_der = ( sig2 - sig1 ) / ( w2 - w1 )
  z = one / ( one - sig_der)
!
! temporary - until I do not have Vxc
!
  et_qp = et + z * sig_et
!
  END SUBROUTINE qp_eigval
!----------------------------------------------------------------
!
