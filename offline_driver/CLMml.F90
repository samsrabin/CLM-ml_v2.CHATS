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
  implicit none
  integer :: nc

  type(bounds_type)        :: bounds
  type(tower_config_type)  :: configs(ntower)

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

  !$OMP PARALLEL DO PRIVATE(bounds, nc) SCHEDULE(DYNAMIC) COPYIN(clm_initialized)
  do nc = 1, ntower
    end if
    call get_clump_bounds(nc, bounds)
    call CLMml_drv(bounds, configs(nc))
  end do
  !$OMP END PARALLEL DO

end program CLMml
