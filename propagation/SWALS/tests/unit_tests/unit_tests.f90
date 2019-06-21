program unit_tests

    ! Get the test subroutines
    use read_raster_mod, only: test_read_raster1
    use spherical_mod, only: test_spherical_mod
    use points_in_poly_mod, only: test_points_in_poly_mod
    use which_mod, only: test_which
    use point_gauge_mod, only: test_point_gauge_mod
    use linear_interpolator_mod, only: test_linear_interpolator_mod
    use coarray_utilities_mod, only: test_coarray_utilities_mod
    use nested_grid_comms_mod, only: test_nested_grid_comms_mod
    use coarray_point2point_comms_mod, only: test_coarray_point2point_comms_mod
    use reshape_array_mod, only: test_reshape_array_mod
    use qsort_mod, only: test_qsort_mod
    use multidomain_mod, only: test_multidomain_mod
    use domain_mod, only: test_domain_mod
    implicit none

    print*, 'Testing read raster'
    call test_read_raster1()

    print*, 'Testing spherical mod'
    call test_spherical_mod()

    print*, 'Testing points_in_poly'
    call test_points_in_poly_mod()

    print*, 'Testing which'
    call test_which()

    print*, 'Testing qsort'
    call test_qsort_mod()
    
    print*, 'Testing point_gauge_mod'
    call test_point_gauge_mod()

    print*, 'Testing linear_interpolator_mod'
    call test_linear_interpolator_mod()
    
    print*, 'Testing reshape_array_mod'
    call test_reshape_array_mod()

    print*, 'Testing coarray_point2point_comms_mod'
    call test_coarray_point2point_comms_mod()

    print*, 'Testing coarray_utilities_mod'
    call test_coarray_utilities_mod()

    print*, 'Testing nested_grid_comms_mod'
    call test_nested_grid_comms_mod()

    print*, 'Testing multidomain_mod'
    call test_multidomain_mod()

    print*, 'Testing domain'
    call test_domain_mod()

end program
    
