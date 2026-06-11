module decompMod

  !-----------------------------------------------------------------------
  ! !DESCRIPTION:
  ! Module provides a decomposition into a clumped data structure which can
  ! be mapped back to atmosphere physics chunks
  !-----------------------------------------------------------------------

  use shr_kind_mod, only : r8 => shr_kind_r8
  implicit none

  !Adding nclumps
  integer, public :: nclumps
  type, public :: bounds_type
     integer :: begg, endg       ! Beginning and ending gridcell index
     integer :: begl, endl       ! Beginning and ending landunit index
     integer :: begc, endc       ! Beginning and ending column index
     integer :: begp, endp       ! Beginning and ending patch index
  end type bounds_type
  
  type, public :: clump_type
    integer :: begg, endg
    integer :: begl, endl
    integer :: begc, endc
    integer :: begp, endp
  end type clump_type

  type(clump_type), public, allocatable :: clumps(:)
  !public bounds_type

contains
  !Crude implementation of decompInit. No MPI
  subroutine decompInit(nsite)
    integer, intent(in) :: nsite
    integer ::n

    nclumps = nsite
    allocate(clumps(nclumps))

    do n=1, nclumps
      clumps(n)%begg = n; clumps(n)%endg = n
      clumps(n)%begl = n; clumps(n)%endl = n
      clumps(n)%begc = n; clumps(n)%endc = n
      clumps(n)%begp = n; clumps(n)%endp = n
    end do
  end subroutine decompInit


  !only for 1 site --use OMP in another loop
  subroutine get_clump_bounds (n, bounds)

    implicit none
    integer, intent(in)  :: n                ! processor clump index
    type(bounds_type), intent(out) :: bounds

    ! Define grid cell (g), land unit (l), column (c), and patch (p) bounds
    ! for CLM g/l/c/p hierarchy. CLM processes clumps of gridcells (and
    ! associated subgrid-scale entities) with length defined by
    ! begg/endg, begl/endl, begc/endc, and begp/endp. This code assumes
    ! that a grid cell has one land unit with one column and one patch. It
    ! processes a single grid cell.

    bounds%begg = clumps(n)%begg
    bounds%endg = clumps(n)%endg
    bounds%begl = clumps(n)%begl
    bounds%endl = clumps(n)%endl
    bounds%begc = clumps(n)%begc
    bounds%endc = clumps(n)%endc
    bounds%begp = clumps(n)%begp
    bounds%endp = clumps(n)%endp

  end subroutine get_clump_bounds

  subroutine get_proc_bounds(bounds)
    type(bounds_type), intent(out) :: bounds
    bounds%begg =1 ; bounds%endg = nclumps
    bounds%begl =1 ; bounds%endl = nclumps
    bounds%begc =1 ; bounds%endc = nclumps 
    bounds%begp =1 ; bounds%endp = nclumps
  end subroutine get_proc_bounds

end module decompMod
