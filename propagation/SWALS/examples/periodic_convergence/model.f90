module local_routines 
    use global_mod, only: dp, ip, charlen, wall_elevation, pi
    use domain_mod, only: domain_type, STG, UH, VH, ELV
    use read_raster_mod, only: multi_raster_type
    use logging_mod, only: log_output_unit
    implicit none

    contains 

    subroutine set_initial_conditions(domain)            
        class(domain_type), intent(inout):: domain
        integer(ip):: i, j
        real(dp), allocatable:: x(:), y(:)

        ! Make space for x/y coordinates, at which we will look-up the rasters
        allocate(x(domain%nx(1)), y(domain%nx(1)))
        x = domain%x
        
        ! Set stage and elevation row-by-row.
        do j = 1, domain%nx(2)
            y = domain%y(j)
            domain%U(:,j,ELV) = 2.0_dp - sin(2*pi*x) - cos(2*pi*y)
            domain%U(:,j,STG) = domain%U(:,j,ELV) + 10.0_dp + exp(sin(2*pi*x))*cos(2*pi*y)
            domain%U(:,j,UH) = sin(cos(2*pi*x))*sin(2*pi*y)
            domain%U(:,j,VH) = cos(2*pi*x)*cos(sin(2*pi*y))
        end do

        deallocate(x,y)

        ! Ensure stage >= elevation
        domain%U(:,:,STG) = max(domain%U(:,:,STG), domain%U(:,:,ELV) + 1.0e-07_dp)

        write(log_output_unit,*) 'Stage range is: ', minval(domain%U(:,:,STG)), maxval(domain%U(:,:,STG))
        write(log_output_unit,*) 'Elev range is: ', minval(domain%U(:,:,ELV)), maxval(domain%U(:,:,ELV))

    end subroutine

end module 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

program run_model

    use global_mod, only: ip, dp, minimum_allowed_depth, charlen
    use domain_mod, only: domain_type
    use multidomain_mod, only: multidomain_type, setup_multidomain, test_multidomain_mod
    use boundary_mod, only: flather_boundary, transmissive_boundary
    use local_routines
    use timer_mod
    use logging_mod, only: log_output_unit, send_log_output_to_file
    use stop_mod, only: generic_stop
    use iso_c_binding, only: C_DOUBLE !, C_INT, C_LONG
    implicit none

    ! Type holding all domains 
    type(multidomain_type) :: md

    ! Local timing object
    type(timer_type) :: program_timer

    ! Change this to decrease the cell size by mesh_refine (i.e. for convergence testing)
    character(len=32) :: mesh_refine_input
    integer(ip) :: mesh_refine

    ! Approx timestep between outputs
    real(dp) :: approximate_writeout_frequency = 0.005_dp
    real(dp) :: final_time = 0.06_dp
    real(dp) :: my_dt 

    ! Length/width
    real(dp), parameter, dimension(2):: global_lw = [1.0_dp, 1.0_dp]
    ! Lower-left corner coordinate
    real(dp), parameter, dimension(2):: global_ll = [0.0_dp, 0.0_dp]
    ! grid size (number of x/y cells)
    integer(ip), dimension(2):: global_nx

    ! Useful misc variables
    integer(ip):: j, i, i0, j0, centoff, nd
    real(dp):: last_write_time, gx(4), gy(4), stage_err
    character(len=charlen) :: md_file, ti_char, stage_file, model_name

    call get_command_argument(1, mesh_refine_input)
    read(mesh_refine_input, '(I4)') mesh_refine

    my_dt = 4e-04_dp/mesh_refine
    global_nx = [100_ip, 100_ip]*mesh_refine + 1

    ! Set the model name
    md%output_basedir = './OUTPUTS/'

    call program_timer%timer_start('setup')

#ifdef SPHERICAL
    write(log_output_unit,*) 'Code assumes cartesian coordinates, but SPHERICAL is defined'
    call generic_stop
#endif

    ! Set periodic boundary condition
    md%periodic_xs = [0.0_dp, 1.0_dp]
    md%periodic_ys = [0.0_dp, 1.0_dp]
    
    ! nd domains in this model
    nd = 1 
    allocate(md%domains(nd))

    !
    ! Setup basic metadata
    !

    ! Linear domain
    md%domains(1)%lw = global_lw
    md%domains(1)%lower_left =global_ll
    md%domains(1)%nx = global_nx
    md%domains(1)%dx = md%domains(1)%lw/md%domains(1)%nx
    md%domains(1)%dx_refinement_factor = 1.0_dp
    md%domains(1)%timestepping_refinement_factor = 1_ip
    md%domains(1)%timestepping_method = 'rk2' ! Do not use linear!

    ! Linear domain should have CFL ~ 0.7
    do j = 1, size(md%domains)
        md%domains(j)%cfl = 0.99_dp
    end do

    ! Allocate domains and prepare comms
    call md%setup()
    call md%memory_summary()

    ! Set initial conditions
    do j = 1, size(md%domains)
        call set_initial_conditions(md%domains(j))
    end do
    call md%make_initial_conditions_consistent()
    
    ! NOTE: For stability in 'null' regions, we set them to 'high land' that
    ! should be inactive. 
    call md%set_null_regions_to_dry()
   
    write(log_output_unit,*) 'End setup'

    call program_timer%timer_end('setup')
    call program_timer%timer_start('evolve')

#ifdef COARRAY
    sync all
    flush(log_output_unit)
#endif

    !
    ! Evolve the code
    !

    ! Trick to get the code to write out just after the first timestep
    last_write_time = 0.0_dp
    do while (.true.)
        
        ! IO 
        if(abs(md%domains(1)%time - last_write_time) <= my_dt*0.5_dp) then
            !call program_timer%timer_start('IO')

            call md%print()

            do j = 1, size(md%domains)
                call md%domains(j)%write_to_output_files()
            end do
            last_write_time = last_write_time + approximate_writeout_frequency
            flush(log_output_unit)

#ifdef COARRAY
            ! This sync can be useful for debugging but is not a good idea in general
            !sync all
#endif
        end if

        call md%evolve_one_step(my_dt)

        if (md%domains(1)%time > final_time) exit
    end do

    call program_timer%timer_end('evolve')

    ! Print out timing info for each
    do i = 1, nd
        write(log_output_unit,*) ''
        write(log_output_unit,*) 'Timer ', i
        write(log_output_unit,*) ''
        call md%domains(i)%timer%print(log_output_unit)
        call md%domains(i)%write_max_quantities()
        call md%domains(i)%finalise()
    end do

    write(log_output_unit, *) ''
    write(log_output_unit, *) 'Multidomain timer'
    write(log_output_unit, *) ''
    call md%timer%print(log_output_unit)

    write(log_output_unit,*) ''
    write(log_output_unit, *) 'Program timer'
    write(log_output_unit, *) ''
    call program_timer%print(log_output_unit)
end program
