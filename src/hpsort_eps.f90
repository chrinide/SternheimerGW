  !
  !----------------------------------------------------------------
  subroutine hpsort_eps (n, ra, ind, eps)
  !----------------------------------------------------------------
  !
  ! FG - from flib/sort.f90
  !
  ! sort an array ra(1:n) into ascending order using heapsort algorithm,
  ! and considering two elements being equal if their values differ
  ! for less than "eps".
  ! n is input, ra is replaced on output by its sorted rearrangement.
  ! create an index table (ind) by making an exchange in the index array
  ! whenever an exchange is made on the sorted data array (ra).
  ! in case of equal values in the data array (ra) the values in the
  ! index array (ind) are used to order the entries.
  ! if on input ind(1)  = 0 then indices are initialized in the routine,
  ! if on input ind(1) != 0 then indices are assumed to have been
  !                initialized before entering the routine and these
  !                indices are carried around during the sorting process
  !
  ! no work space needed !
  ! free us from machine-dependent sorting-routines !
  !
  ! adapted from Numerical Recipes pg. 329 (new edition)
  !
  implicit none  
  integer, parameter :: dbl = selected_real_kind(14,200)
  !-input/output variables
  integer, intent(in) :: n  
  integer, intent(inout) :: ind (n)  
  real(dbl), intent(inout) :: ra (n)
  real(dbl), intent(in) :: eps
  !-local variables
  integer :: i, ir, j, l, iind  
  real(dbl) :: rra  
  ! initialize index array
  if (ind (1) .eq.0) then  
     do i = 1, n  
        ind (i) = i  
     enddo
  endif
  ! nothing to order
  if (n.lt.2) return  
  ! initialize indices for hiring and retirement-promotion phase
  l = n / 2 + 1  
  !
  ir = n  
  !
  sorting: do 
    ! still in hiring phase
    if ( l .gt. 1 ) then  
       l    = l - 1  
       rra  = ra (l)  
       iind = ind (l)  
       ! in retirement-promotion phase.
    else  
       ! clear a space at the end of the array
       rra  = ra (ir)  
       !
       iind = ind (ir)  
       ! retire the top of the heap into it
       ra (ir) = ra (1)  
       !
       ind (ir) = ind (1)  
       ! decrease the size of the corporation
       ir = ir - 1  
       ! done with the last promotion
       if ( ir .eq. 1 ) then  
          ! the least competent worker at all !
          ra (1)  = rra  
          !
          ind (1) = iind  
          exit sorting  
       endif
    endif
    ! wheter in hiring or promotion phase, we
    i = l  
    ! set up to place rra in its proper level
    j = l + l  
    !
    do while ( j .le. ir )  
       if ( j .lt. ir ) then  
          ! compare to better underling
          if ( hslt( ra (j),  ra (j + 1) ) ) then  
             j = j + 1  
          endif
       endif
       ! demote rra
       if ( hslt( rra, ra (j) ) ) then  
          ra (i) = ra (j)  
          ind (i) = ind (j)  
          i = j  
          j = j + j  
       else  
          ! set j to terminate do-while loop
          j = ir + 1  
       endif
    enddo
    ra (i) = rra  
    ind (i) = iind  
  end do sorting    
  !
  contains 
  !  internal function 
  !  compare two real number and return the result
  logical function hslt( a, b )
    REAL(dbl) :: a, b
    if( abs(a-b) <  eps ) then
      hslt = .false.
    else
      hslt = ( a < b )
    end if
  end function
  !
  end subroutine hpsort_eps
  !
  !----------------------------------------------------------------
  function equiv (a, b)
  !----------------------------------------------------------------
  !
  ! decide whether the vectors a(1:3) and b(1:3) do coincide
  !
  implicit none
  integer, parameter :: DP = selected_real_kind(14,200)
  real(kind=DP), parameter :: eps8 = 1.0D-8
  logical :: equiv
  real(kind=DP) :: a(3), b(3)
  !
  equiv =  ( ( abs ( a(1) - b(1) ) .lt. eps8) .and. &
             ( abs ( a(2) - b(2) ) .lt. eps8) .and. &
             ( abs ( a(3) - b(3) ) .lt. eps8) ) 
  !
  end function equiv
  !
