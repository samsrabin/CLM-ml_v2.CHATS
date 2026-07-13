program CLMml

  use decompMod,    only : bounds_type, get_clump_bounds, decompInit, nclumps
  use CLMml_driver, only : CLMml_drv, clm_initialized
  use TowerDataMod, only : ntower, tower_id, tower_num
  use abortutils,   only : tower_error_flag, tower_error_msg, reset_tower_error
  use controlMod,   only : tower_config_type, read_all_configs
  use MLCanopyTurbulenceMod, only : LookupPsihatINI
  use ForcingBufMod,      only : forcing, use_buffer
  use TowerMetMod,        only : prefill_tower_met
  use clmDataMod,         only : prefill_clm, prefill_factor
  use clmSoilOptionMod,   only : clm_phys
  use clm_varpar,         only : clm_varpar_init
  use omp_lib,            only : omp_get_wtime
  implicit none

  integer,  parameter :: nreps = 3
  integer :: nc, irep
  double precision :: t_total_start, t_io_start, t_io_end
  double precision :: t_comp_start, t_comp_end
  double precision :: t_comp(nreps), comp_mean, comp_std, comp_sq

  type(bounds_type)        :: bounds
  type(tower_config_type)  :: configs(ntower)

  t_total_start = omp_get_wtime()
  write (*,*) "Starting Run!"

  ! Read all ntower namelist blocks from stdin sequentially, before any threads start.
  ! This is necessary because stdin cannot be read safely from multiple threads at once.
  call read_all_configs(configs, ntower)
  do nc = 1, ntower
    configs(nc)%run_idx = nc
  end do
  write(*,*) "Read all tower configs."

  ! One clump per tower — each OMP thread will process one tower at a time
  call decompInit(ntower)
  write(*,*) "Initialized decomposition."

  ! Read RSL psihat look-up tables once, single-threaded, before the parallel
  ! region. LookupPsihatINI writes shared MLclm_varcon arrays and opens a
  ! netCDF file — both are unsafe inside the OMP region.
  call LookupPsihatINI

  ! Pre-read all tower met forcing into memory before the parallel region so
  ! that readTowerMet never calls netCDF from inside an OMP thread.
  t_io_start = omp_get_wtime()
  allocate (forcing(ntower))
  do nc = 1, ntower
    call prefill_tower_met(configs(nc)%fin_tower, configs(nc)%ntim, forcing(nc))
    clm_phys = configs(nc)%clm_phys
    call clm_varpar_init()
    call prefill_clm(configs(nc)%fin_clm, forcing(nc))
    if (configs(nc)%nlev_soil_adjust > 0) &
      call prefill_factor(configs(nc)%fin_soil_adjust, forcing(nc))
  end do
  use_buffer = .true.
  t_io_end = omp_get_wtime()
  write(*,'(a,f10.3,a)') 'I/O pre-read phase:  ', t_io_end - t_io_start, ' s'

  ! Run all towers nreps times; output files are overwritten each rep but the
  ! final result is identical to a single run.
  do irep = 1, nreps
    write(*,'(a,i0,a,i0,a)') '--- Compute rep ', irep, ' of ', nreps, ' ---'
    t_comp_start = omp_get_wtime()

    !$OMP PARALLEL DO PRIVATE(bounds, nc) SCHEDULE(DYNAMIC) COPYIN(clm_initialized)
    do nc = 1, ntower
      call get_clump_bounds(nc, bounds)
      call CLMml_drv(bounds, configs(nc))
    end do
    !$OMP END PARALLEL DO

    t_comp_end = omp_get_wtime()
    t_comp(irep) = t_comp_end - t_comp_start
    write(*,'(a,i0,a,f10.3,a)') '  Rep ', irep, ' wall time: ', t_comp(irep), ' s'
  end do

  ! Sample mean and std (n-1 denominator)
  comp_mean = sum(t_comp) / dble(nreps)
  comp_sq   = 0.0d0
  do irep = 1, nreps
    comp_sq = comp_sq + (t_comp(irep) - comp_mean)**2
  end do
  comp_std = sqrt(comp_sq / dble(nreps - 1))

  write(*,*)
  write(*,*) '=== Timing Summary ==='
  write(*,'(a,f10.3,a)') 'I/O pre-read:         ', t_io_end - t_io_start, ' s'
  do irep = 1, nreps
    write(*,'(a,i0,a,f10.3,a)') 'Compute rep ', irep, ':        ', t_comp(irep), ' s'
  end do
  write(*,'(a,f10.3,a)') 'Compute mean:         ', comp_mean, ' s'
  write(*,'(a,f10.3,a)') 'Compute std (sample): ', comp_std, ' s'
  write(*,'(a,f10.3,a)') 'Total wall time:      ', omp_get_wtime() - t_total_start, ' s'

end program CLMml
