context('test_rupture_creation_and_probabilities')

test_that("test_rupture_creation_and_probabilities", {
    # Alaska source zone computations

    alaska_contour_shapefile = './testshp/alaska.shp'

    # Make discrete source
    discrete_source = discretized_source_from_source_contours(alaska_contour_shapefile,
        desired_subfault_length=100, desired_subfault_width=50, make_plot=FALSE)
      
    # Get summary statistics for unit sources 
    unit_source_summary_statistics = discretized_source_summary_statistics(discrete_source,
        approx_dx=5000, approx_dy = 5000) 

    # Get a table with all earthquake events between Mw = 7.5 and Mw = 9.4
    dMw = 0.1
    earthquake_event_table = get_all_earthquake_events(discrete_source, unit_source_summary_statistics,
        Mmin = 7.5, Mmax = 9.4, dMw = dMw)

    event_conditional_probabilities = get_event_probabilities_conditional_on_Mw(
        earthquake_event_table,
        conditional_probability_model = 'inverse_slip')

    # Get total area of source-zone in km^2
    sourcezone_total_area = sum(unit_source_summary_statistics$length *
        unit_source_summary_statistics$width)


    # Check event_index_string is correct (for an event in the middle of the
    # event table)
    ei_ind = ceiling(length(earthquake_event_table[,1])/2)
    indices_in_event_ei_ind = get_unit_source_indices_in_event(
        earthquake_event_table[ei_ind,])
    back_computed_event_index_string = paste(indices_in_event_ei_ind, '-', 
        sep="", collapse="")
    orig_event_index_string = as.character(
        earthquake_event_table$event_index_string[ei_ind])

    expect_that(back_computed_event_index_string == orig_event_index_string, is_true())

    ###########################################################################
    #
    # A 'REALISTIC' TEST
    #
    ###########################################################################

    # Recurrence parameters
    slip_rate = c(44.00, 49.50, 55.00)/1000 # m/year
    slip_rate_prob = c(0.6, 0.2, 0.2)  
    b = c(0.95, 0.7, 1.2)
    b_prob = c(0.6, 0.2, 0.2)
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = c(9.40, 9.40, 9.00)
    Mw_max_prob = c(0.6, 0.3, 0.1)

    rate_function = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min - dMw/2,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)

    # Test the rate of 'Great earthquakes' is reasonable
    # These bounds may change but they work at present (2/10/2015) and are
    # consistent with other estimates for the "Alaska" sourcezone
    # This test is 'just' checking that the results do not suddenly become
    # extremely inconsistent with previous results.
    freq_gt9 = 1/rate_function(9.0)
    expect_that( (freq_gt9 > 600) & (freq_gt9 < 700), is_true() )
   
    # Check that if we account for the moment below mwmin, then the rate
    # of earthquakes is less. 
    rate_functionB = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min - dMw/2,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        account_for_moment_below_mwmin=TRUE)

    freq_gt9B = 1/rate_functionB(9.0)
    expect_that( freq_gt9 < freq_gt9B, is_true())

    #
    # Check that we get pretty much the same as rate_functionB by setting Mw_min to 0,
    # and ignoring the moment below mwmin.
    #
    # Slight differences can occur because when we use 'account_for_moment_below_mwmin',
    # the integration of moment rate below mw-min is done in high detail. OTOH, when
    # we use the earthquake event table, we get the moment from Mw [often crudely discretized, e.g. dMw=0.1]
    # and assign a rate based on the exact rate from [Mw-dMw/2, Mw+dMw/2]. The 'moment' in the
    # bin would obviously differ if we split the bin into a set of finer bins [because the moment at Mw=7.5 is not
    # equal to the mean of all moments between Mw=7.4 and Mw=7.6
    #
    # To do this test, we need to hack events with Mw = 0 to Mw = 7.4 into to
    # the event table. Those events need the right seismic moment.
    fake_event_table = earthquake_event_table[1,]
    fake_event_table$Mw = 0
    fake_event_table$slip = M0_2_Mw(0, inverse=TRUE)/(fake_event_table$area *1e+06 * 3e+10)
    fake_cond_prob = 1
    for(mwtmp in seq(0.1, Mw_min-0.1, by=0.1)){
        tmp_event_table = earthquake_event_table[1,]
        tmp_event_table$Mw = mwtmp
        tmp_event_table$slip = M0_2_Mw(mwtmp, inverse=TRUE)/(tmp_event_table$area * 1e+06 * 3e+10)
        fake_event_table = rbind(fake_event_table, tmp_event_table)
        fake_cond_prob = c(fake_cond_prob, 1)
    }

    fake_event_table = rbind(fake_event_table, earthquake_event_table)
    fake_cond_prob = c(fake_cond_prob, event_conditional_probabilities)

    rate_functionC = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = 0-dMw/2,
        Mw_min_prob = 1,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = fake_event_table,
        event_conditional_probabilities = fake_cond_prob,
        account_for_moment_below_mwmin=FALSE)

    freq_gt9C = 1/rate_functionC(9.0)
    expect_that(abs(freq_gt9C - freq_gt9B) < 0.0005*max(freq_gt9C, freq_gt9B), is_true())

    #
    # Compute some quantiles representing uncertainty in the rate function
    #
    rate_gt9_quantiles = rate_function(9.0, quantiles=seq(0.1, 0.9, by=0.1))
    # The mean of these values should be close to the raw value of rate_function, which
    # is based on the weighted mean of the logic-tree rates
    expect_that( abs(mean(rate_gt9_quantiles) - rate_function(9.0)) < 1e-04, is_true())
   
    # Check we can do multiple mw and quantiles at once, and it still works
    rate_gt_multiple_mw_and_quantiles = rate_function(c(9.0, 9.0, 9.1), quantiles=seq(0.1, 0.9, by=0.1))
    rate_gt91_quantiles = rate_function(9.1, quantiles=seq(0.1, 0.9, by=0.1))
    expect_that( all(rate_gt9_quantiles == rate_gt_multiple_mw_and_quantiles[1,]), is_true())
    expect_that( all(rate_gt9_quantiles == rate_gt_multiple_mw_and_quantiles[2,]), is_true())
    expect_that( all(rate_gt91_quantiles == rate_gt_multiple_mw_and_quantiles[3,]), is_true())

    # More test of chunking
    # Get more quantiles than the chunk size
    rate_gt_multiple_mw_and_many_quantiles = rate_function(c(9.0, 9.0, 9.1), quantiles=seq(0.01, 0.99, by=0.005))
    inds = seq(20, 180, by=20)-1
    mytest = all(rate_gt_multiple_mw_and_many_quantiles[,inds] == rate_gt_multiple_mw_and_quantiles)
    expect_that(mytest, is_true())

    # Back-calculate slip on each fault
    event_rate = event_conditional_probabilities * 
        (rate_function(earthquake_event_table$Mw-dMw/2) - 
        rate_function(earthquake_event_table$Mw + dMw/2))
    event_longterm_slip = earthquake_event_table$slip * event_rate
    unit_source_longterm_slip = 
        rep(0, length(unit_source_summary_statistics[,1]))

    event_longterm_slip_area = event_longterm_slip * earthquake_event_table$area
    unit_source_longterm_slip_area = 
        rep(0, length(unit_source_summary_statistics[,1]))

    unit_source_area = unit_source_summary_statistics$length * 
        unit_source_summary_statistics$width

    # Loop over all events
    for(ee in 1:length(event_longterm_slip)){
        # Find the unit sources on this event
        unit_sources = strsplit(as.character(
            earthquake_event_table$event_index_string[ee]), '-')[[1]]
        unit_sources = as.numeric(unit_sources)

        # Add the slip to all the involved unit sources
        unit_source_longterm_slip[unit_sources] = 
            unit_source_longterm_slip[unit_sources] + event_longterm_slip[ee]

        # Add the seismic moment to all the involved sources
        unit_source_longterm_slip_area[unit_sources] = 
            unit_source_longterm_slip_area[unit_sources] + 
            event_longterm_slip_area[ee]
    }
    #m1 = matrix(unit_source_longterm_slip, ncol=6,nrow=7,byrow=TRUE)
    #m2 = matrix(unit_source_longterm_slip_area, ncol=6,nrow=7,byrow=TRUE)

    # Check that the mean slip is close to the desired value
    # Why is it not identical? -- because our relations ensure that:
    # (long-term-slip x area) = sum(earthquake_slip x area)
    #, which is not the same as ensuring the mean slip itself is identical
    # [unless the mean is weighted by area]
    theoretical_slip = sum(slip_rate*slip_rate_prob)
    back_calc_slip = mean(unit_source_longterm_slip)
    err = abs(back_calc_slip - theoretical_slip)/theoretical_slip
    expect_that(err < 0.01, is_true())

    weighted_slip = weighted.mean(unit_source_longterm_slip, unit_source_area)
    err = abs(sum(weighted_slip) - theoretical_slip)/theoretical_slip
    expect_that(err < 1.0e-08, is_true())


    ###########################################################################
    #
    # Test 2 -- check that the weighting is occurring properly
    #
    ###########################################################################   
    slip_rate = 55.00/1000 # m/year
    slip_rate_prob =  1.0
    b = c(0.7, 1.2)
    b_prob = c(0.3, 0.7)
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = 9.40
    Mw_max_prob = 1

    rate_function = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)

    # Compute rate functions individually and confirm their weightings
    rate_function_b0.7 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b[1],
        b_prob = 1.0,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)

    rate_function_b1.2 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b[2],
        b_prob = 1.0,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)

    Mws = seq(7.5, 9.5, by=0.1)
    r1 = rate_function(Mws)
    r2 = rate_function_b0.7(Mws)
    r3 = rate_function_b1.2(Mws)

    # This should be zero if the weighing is being correctly done
    err = r1 - (b_prob[1]*r2 + b_prob[2]*r3)

    expect_that( isTRUE(all.equal(err, err*0.0)), is_true())


    #####################################################################
    #
    # Test 3: Check that weighting of logic-tree probabilities with data is ok
    #
    #####################################################################
    #
    # Idea: Provide strongly varying slip rates. Give data that only agrees with one or the other
    # Check that the final averaged rate curve reflects this

    slip_rate = c(0.1, 100)/1000 # m/year
    slip_rate_prob =  c(0.5, 0.5)
    b = 1
    b_prob = 1
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = 9.40
    Mw_max_prob = 1

    # The following data is much more consistent with 100mm of slip/year, vs
    # 0.1mm
    Mw_count_duration = c(7.6, 3, 50)

    # Slip rate = 0.1mm/year alone
    rate_function1 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate[1],
        slip_rate_prob = 1,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)
    
    # Slip rate = 100mm/year alone
    rate_function2 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate[2],
        slip_rate_prob = 1,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities)

    # Weighted combination of both models, adjusted for the data
    rate_function3 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration)

    # Given the data, rate_function3 should be basically equal to rate_function2
    mws = seq(7.5, 9.399, len=100)
    expect_that(
        isTRUE(all.equal(rate_function3(mws), rate_function2(mws), tol=1.0e-05)), 
        is_true())

    # Alternative use of data to combine, based on a poisson process with incomplete start/end times 
    # Note that in this case, the time 'before' the first earthquake, and 'after' the last one, is
    # treated as censored observations
    rate_function4 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        Mw_obs_data=list(Mw=NULL, t=c(10, 30, 45))
        )

    expect_that(
        isTRUE(all.equal(rate_function4(mws), rate_function2(mws), tol=1.0e-02)), 
        is_true())

    # Mathematically, this one will give the 'same' result as the poisson
    # distribution approach (rate_function3). This is because the 'time-between events'
    # is 10, 20, 20 -- which adds exactly to 50 -- while the lower bounds of the 'start and end'
    # earthquakes are zero, and from a censored viewpoint, the probability of
    # these values is 1 [i.e. it is impossible to be less anyway]
    rate_function5 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=c(Mw_count_duration[1], 4, Mw_count_duration[3]),
        Mw_obs_data=list(Mw=NULL, t=c(0, 10, 30, 50))
        )

    expect_that(
        isTRUE(all.equal(rate_function5(mws), rate_function3(mws), tol=1.0e-12)), 
        is_true())


    #
    # Try Mw update as well
    #
    slip_rate = c(0.1, 100)/1000 # m/year
    slip_rate_prob =  c(0.5, 0.5)
    b = 1
    b_prob = 1
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = c(8.3, 9.4, 9.6)
    Mw_max_prob = c(1,1,1)/3
  
    # 
    # Poisson-count approach 
    #
    rate_function6_a = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=c(Mw_count_duration[1], 4-1, Mw_count_duration[3]),
        Mw_obs_data=list(Mw=NULL, t=NULL)
        )
    #
    # Detailed times approach, setup to give identical answer to poisson-count approach
    #
    rate_function6_b = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=c(Mw_count_duration[1], 4, Mw_count_duration[3]),
        Mw_obs_data=list(Mw=NULL, t=c(0, 10, 30, 50))
        )

    #
    # Approach with Mw data as well as times. This should exclude the branch with low Mw_max
    #
    rate_function7 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=c(Mw_count_duration[1], 4, Mw_count_duration[3]),
        Mw_obs_data=list(Mw=c(7.6, 7.8, 8.301, 7.7), t=c(0, 10, 30, 50))
        )

    expect_that(
        isTRUE(all.equal(rate_function6_a(mws), rate_function6_b(mws), tol=1.0e-12)), 
        is_true())
    

    d6_a = rate_function6_a(NA, return_all_logic_tree_branches=TRUE)
    d6_b = rate_function6_b(NA, return_all_logic_tree_branches=TRUE)
    d7 = rate_function7(NA, return_all_logic_tree_branches=TRUE)

    expect_that(isTRUE(all.equal(d6_a$all_par_prob, d6_b$all_par_prob, tol=1e-12)), is_true())

    # Check that the rate function with Mw data 'zeroed' the logic tree branch
    # with Mw_max < max_mw_observed
    kk = which(d7$all_par$Mw_max < 8.301)
    expect_that(all(d7$all_par_prob[kk] == 0), is_true())
    
    # Because the data contains no large Mw, it should have *slightly*
    # increased our weight on the lower plausible Mw_max, and *slightly*
    # decreased our weight on the higher one, compared to just providing the temporal data.
    #
    # Compute model 6 rates, assuming they know the branch with Mw = 8.3 has zero weight
    d6_prob_adjusted = d6_a$all_par_prob
    d6_prob_adjusted[kk] = 0
    d6_prob_adjusted = d6_prob_adjusted/sum(d6_prob_adjusted)
    
    # Slight increase in weight to Mw = 9.4
    kk = which(d7$all_par$Mw_max == 9.4)
    expect_that(all(d7$all_par_prob[kk] > d6_prob_adjusted[kk]), is_true())
    # Slight decrease in weight to Mw = 9.6
    kk = which(d7$all_par$Mw_max == 9.6)
    expect_that(all(d7$all_par_prob[kk] < d6_prob_adjusted[kk]), is_true())

    # Example where we don't change our weights on mw_max
    rate_function6_a_donot_update_mwmax_weights = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=c(Mw_count_duration[1], 4-1, Mw_count_duration[3]),
        Mw_obs_data=list(Mw=NULL, t=NULL),
        mw_max_posterior_equals_mw_max_prior = TRUE
        )
    # Compare with the earlier rate_function6. They are quite different.
    x1 = rate_function6_a(7.6)
    x2 = rate_function6_a_donot_update_mwmax_weights(7.6)
    expect_that( abs(x1-x2) < 0.4*x1 & abs(x1-x2) > 0.3*x1, is_true())

    # Check that we get the nonzero event weight correct
    possibility_mw = rate_function6_a_donot_update_mwmax_weights(
        c(7.6, 8.2, 8.29, 8.3, 8.4, 9.3, 9.39, 9.4, 9.5, 9.59, 9.6, 9.7), 
        epistemic_nonzero_weight=TRUE)
    # Considering we use a truncated GR, the possibility associated with Mw-max
    # should be zero
    expected_possibility = 
        c(  1,   1,  1, 2/3, 2/3, 2/3, 2/3, 1/3, 1/3, 1/3, 0, 0) 
    expect_that(isTRUE(all(abs(possibility_mw - expected_possibility) < 1.0e-06)), 
        is_true())
    # Should not matter whether we account for Mw obs error
    possibility_mw = rate_function6_a_donot_update_mwmax_weights(
        c(7.6, 8.2, 8.29, 8.3, 8.4, 9.3, 9.39, 9.4, 9.5, 9.59, 9.6, 9.7), 
        epistemic_nonzero_weight=TRUE, account_for_mw_obs_error=TRUE)
    expect_that(isTRUE(all(abs(possibility_mw - expected_possibility) < 1.0e-06)), 
        is_true())

    #
    #
    # Check that with full Mw data, we really can 'filter' logic tree branches well,
    # and get the correct one
    #
    #
    slip_rate = c(0.1, 50, 90)/1000 # m/year
    slip_rate_prob =  rep(1,length(slip_rate))/length(slip_rate)
    b = c(0.7, 0.9, 1, 1.3)
    b_prob = rep(1,length(b))/length(b)
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = 9.4
    Mw_max_prob = 1
    Mw_freq_dist = c('truncated_gutenberg_richter', 'characteristic_gutenberg_richter')
    Mw_freq_dist_prob = c(0.5, 0.5)

    # Suppose true relation has:
    # slip-rate = 50
    # b = 1
    # Mw_max = 9.4
    # rate turns out to be 0.059 events with Mw>7.5 per year
    # Characteristic Gutenberg richter

    #
    # Make a large random dataset 
    #
    n = 1000
    random_inv_quant = runif(n)
    true_b = 1
    random_Mw = -log10(random_inv_quant*10**(-true_b*7.5))
    if(any(random_Mw > Mw_max)){
        random_Mw[random_Mw > Mw_max] = Mw_max # Characteristic!
    }
    random_dt = rexp(n, rate=0.059)
    Mw_count_duration = c(7.5, n, sum(random_dt)+1)
    random_t = cumsum(random_dt)

    #
    # Do the analysis with the large random dataset
    #
    rate_function8 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution=Mw_freq_dist,
        Mw_frequency_distribution_prob = Mw_freq_dist_prob,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        Mw_obs_data=list(Mw=random_Mw, t=random_t)
        )
    #
    # Check we identified the correct logic tree branch
    #
    xx = rate_function8(NA, return_all_logic_tree_branches=TRUE)
    # Should have id'd the optional branch
    k = which.max(xx$all_par_prob)
    # Should be 'much much' better than any other branch
    expect_that(all(xx$all_par_prob[k] > 1.0e-08*xx$all_par_prob[-k]), is_true())
    # Should match the inputs
    expect_that(isTRUE(all.equal(xx$all_par$b[k], true_b)), is_true())
    expect_that(isTRUE(all.equal(xx$all_par$slip_rate[k], 0.05)), is_true())
    expect_that(xx$all_par$Mw_frequency_distribution[k] == 'characteristic_gutenberg_richter', is_true())


    #
    # Modelling accounting for Mw observation errors
    #

    # Uniform errors
    error_sd = 0.12
    cdf_mw_error<-function(x, mw_true){
        output = pnorm(x, mean=0, sd=error_sd) #punif(x, -0.4, 0.4)
        # Clip it because our implementation requires finite support
        output[x <= -0.5] = 0
        output[x >= 0.5] = 1 
        return(output)
    }
    # Only have variation in slip - rate
    slip_rate = seq(0.07, 0.1, len=1000) # m/year
    slip_rate_prob = rep(1, len=1000)/length(slip_rate)
    b = 1
    b_prob = 1
    Mw_min = 7. 
    Mw_min_prob = 1
    Mw_max = 9.40
    Mw_max_prob = 1
    Mw_count_duration = c(7.6, 4, 50)
    Mw_obs_data = list(Mw=c(7.63, 8.0, 7.84, 7.73), t=NULL)

    # Compute the rate function, ignoring Mw-observation-errors
    rate_no_mw_error = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution='characteristic_gutenberg_richter',
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        account_for_moment_below_mwmin=TRUE)

    # Compute the rate function, accounting for Mw-observation-errors
    # This one uses Mw_count_duration, but not Mw_obs_data
    rate_mw_error = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution='characteristic_gutenberg_richter',
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        account_for_moment_below_mwmin=TRUE,
        mw_observation_error_cdf = cdf_mw_error)

    # These should be exactly equal (i.e. same code paths)
    expect_that(rate_mw_error(7.6) == rate_no_mw_error(7.6), is_true())
    
    # Look at the detailed curve weights
    p1 = rate_mw_error(NA, return_all_logic_tree_branches=TRUE)
    # Check consistency between derived 'a' parameters and the slip parameters
    slip_range = max(slip_rate)/min(slip_rate)
    a_range = max(p1$all_par$a) - min(p1$all_par$a)
    expect_that( abs(10**(a_range) - slip_range) < 1.0e-06, is_true())

    # When we account for mw observation errors, the rate should decrease
    # 
    r1 = rate_mw_error(7.6, account_for_mw_obs_error = FALSE)
    r2 = rate_mw_error(7.6, account_for_mw_obs_error=TRUE)
    expect_that( r1 > r2, is_true())

    # Given normal errors, the expected change in the ML estimate of the 'a' parameter
    # is due to Tinti and Mulargia (1985). I don't have that paper but it is discussed in:
    # Rhoads, 1996, Estimation of the Gutenberg-Richter relation allowing for individual earthquake magnitude uncertainties
    # Tectonophysics 258:71-83 
    expected_ml_difference = error_sd^2 * (b*log(10))^2 * log10(exp(1))/2
    # Check that the 'maximum likelihood' value of a does indeed change by
    # this amount, up to some tolerance
    i1 = which.max(p1$all_par_prob)
    i2 = which.max(p1$all_par_prob_with_Mw_error)
    ml1 = p1$all_par$a[i1]
    ml2 = p1$all_par$a[i2]
    # The 'no observation error' value should be larger, because with obs
    # errors, we expect an artificial increase in the rate of events.
    expect_that(ml1 > ml2, is_true())
    # Check that the probability update is consistent with the ML solution
    rel_err = (ml1 - ml2)/expected_ml_difference
    expect_that( rel_err > 1 & rel_err < 1.001, is_true())

    #
    # Next test..
    # Somewhat similar to above, but use all Mw observations, not
    # just the Mw_count_duration information.
    # This should allow 'b' to be better constrained (if there are enough
    # observations).
    # 
    # Uniform errors
    error_sd = 0.12
    cdf_mw_error<-function(x, mw_true){
        output = pnorm(x, mean=0, sd=error_sd) #punif(x, -0.4, 0.4)
        # Clip it because our implementation requires finite support
        output[x <= -0.5] = 0
        output[x >= 0.5] = 1 
        return(output)
    }
    # Only have variation in slip - rate
    slip_rate = seq(0.07, 0.1, len=100) # m/year
    slip_rate_prob = rep(1, len=100)/length(slip_rate)
    b = seq(0.7, 1.2, len=10)
    b_prob = rep(1,length(b))/length(b)
    Mw_min = 7. 
    Mw_min_prob = 1
    Mw_max = 9.40
    Mw_max_prob = 1
    Mw_count_duration = c(7.6, 4, 50)
    Mw_obs_data = list(Mw=c(7.63, 8.0, 7.84, 7.73), t=NULL)

    rate_mw_error_2B = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution='characteristic_gutenberg_richter',
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        Mw_obs_data = Mw_obs_data,
        account_for_moment_below_mwmin=TRUE,
        mw_observation_error_cdf = cdf_mw_error)
    # FIXME: Add a test for this case (beyond just that 'it runs', which is
    # nonetheless something I suppose!)
    # Note the test below covers this topic as well, and actually involves 
    # quantitative checks


    #
    #
    # Check that with full Mw data, we really can 'filter' logic tree branches well,
    # and get the correct one, including consideration of Mw observation error.
    # 
    # In particular, we find that estimates of 'b' are improved by using the full data.
    # For this problem, the impact of considering Mw observation errors is pretty
    # small, but we can nonetheless check that the difference conforms with 
    # mathematical requirements (e.g. reduced 'a' value when errors are considered)
    #
    #
    
    slip_rate = seq(4, 12, len=30)/1000 # m/year
    slip_rate_prob =  rep(1,length(slip_rate))/length(slip_rate)
    b = seq(0.7, 1.1, len=30)
    b_prob = rep(1,length(b))/length(b)
    Mw_min = 7.5
    Mw_min_prob = 1
    Mw_max = 12 # Effectively unbounded
    Mw_max_prob = 1
    Mw_freq_dist = c('truncated_gutenberg_richter', 'characteristic_gutenberg_richter')
    Mw_freq_dist_prob = c(0.5, 0.5)

    #
    # Make a large random dataset, which we will use to update the logic-tree weights.
    # Note we include observation error.
    #
    set.seed(123)
    obs_duration_multiplier = 1 # Use this to scale the size/duration of the data
    n = 1000 * obs_duration_multiplier
    true_b = 1
    true_a = 5.5
    rate_above_7 = 10**(true_a - true_b * 7)
    rate_above_7.5 = 10**(true_a - true_b * 7.5)
    random_Mw = rGR(n, b=true_b, mw_min=7) #-log10(random_inv_quant*10**(-true_b*7.0))
    if(any(random_Mw > Mw_max)){
        random_Mw[random_Mw > Mw_max] = Mw_max # Characteristic!
    }
    # Add a random error to the magnitude observations, clipped to +- 0.5
    obs_random_Mw = random_Mw + pmax(-0.5, pmin(0.5, rnorm(length(random_Mw), mean=0, sd=error_sd)))
    k = which(obs_random_Mw >= Mw_min)
    obs_random_Mw = obs_random_Mw[k]
    Mw_count_duration = c(7.5, length(obs_random_Mw), n/rate_above_7)


    #
    # Fit without using the full Mw observation data
    # This one is unable to constrain 'b' very well, because it only
    # knows the rate of events above 7.5, not their distribution.
    #
    rate_function_simple = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution=Mw_freq_dist,
        Mw_frequency_distribution_prob = Mw_freq_dist_prob,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        Mw_obs_data=list(Mw=NULL, t=NULL),
        mw_observation_error_cdf = cdf_mw_error
        )

    #
    # This fit is like the previous, but we use the actual Mw values.
    # In theory this should allow us to constrain 'b' better
    #
    rate_function_3000 = rate_of_earthquakes_greater_than_Mw_function(
        slip_rate = slip_rate,
        slip_rate_prob = slip_rate_prob,
        b = b,
        b_prob = b_prob,
        Mw_min = Mw_min,
        Mw_min_prob = Mw_min_prob,
        Mw_max = Mw_max,
        Mw_max_prob = Mw_max_prob,
        sourcezone_total_area = sourcezone_total_area,
        event_table = earthquake_event_table,
        event_conditional_probabilities = event_conditional_probabilities,
        Mw_frequency_distribution=Mw_freq_dist,
        Mw_frequency_distribution_prob = Mw_freq_dist_prob,
        update_logic_tree_weights_with_data=TRUE,
        Mw_count_duration=Mw_count_duration,
        Mw_obs_data=list(Mw=obs_random_Mw, t=NULL),
        mw_observation_error_cdf = cdf_mw_error
        )

    ##
    ## These quantities are useful to check if debugging
    ## 
    #r1 = rate_function_simple(7.5)
    #r2 = rate_function_simple(7.5, account_for_mw_obs_error=TRUE)
    #r3 = rate_function_3000(7.5)
    #r4 = rate_function_3000(7.5, account_for_mw_obs_error=TRUE)
    #
    all_logic_tree_simple = rate_function_simple(NA, return_all_logic_tree_branches=TRUE)
    #i1 = order(all_logic_tree_simple$all_par_prob_with_Mw_error, decreasing=TRUE)[1:50]
    #
    all_logic_tree_3000 = rate_function_3000(NA, return_all_logic_tree_branches=TRUE)
    #i3 = order(all_logic_tree_3000$all_par_prob_with_Mw_error, decreasing=TRUE)[1:50]
    # 
    ## This one should constrain b better because it uses Mw data 
    #summary(all_logic_tree_3000$all_par[i3,])
    ## This one should not constrain b as well
    #summary(all_logic_tree_simple$all_par[i1,])

    # To check the ML fit of the random data, can use this routine
    fitted_no_obs_error = fit_truncGR_multiple_catalogues(
        list(list(mw_min=7.5, duration=Mw_count_duration[3], mw=obs_random_Mw)), 
        start=c(0.05, 1))
    ml_b_ignoring_errors = fitted_no_obs_error$par[2]

    # Check the 'b' and 'a' values
    a_3000_mw_error = weighted.mean(all_logic_tree_3000$all_par$a, all_logic_tree_3000$all_par_prob_with_Mw_error)
    a_3000_no_mw_error = weighted.mean(all_logic_tree_3000$all_par$a, all_logic_tree_3000$all_par_prob)
    b_3000_mw_error = weighted.mean(all_logic_tree_3000$all_par$b, all_logic_tree_3000$all_par_prob_with_Mw_error)
    b_3000_no_mw_error = weighted.mean(all_logic_tree_3000$all_par$b, all_logic_tree_3000$all_par_prob)
    # Use of mw-error or not has little effect (but of course 'a' parameter should
    # be smaller, for a similar reason as noted in an earlier test referring to Rhoads paper). 
    # In this problem, since the error is independent of 'b', we do not expect
    # additional errors in 'b' due to error treatment. However, we will get
    # much better 'b' in the _3000 case than in the _simple case because the
    # latter ignores the Mw distribution Beware these thresholds might need to
    # vary if the problem is adjusted.
    expect_that(a_3000_mw_error - a_3000_no_mw_error < 0 & 
                abs(a_3000_mw_error - a_3000_no_mw_error) < 0.05, 
                is_true())
    expect_that(abs(b_3000_mw_error - b_3000_no_mw_error) < 0.002, is_true())
    expect_that(abs(b_3000_mw_error - ml_b_ignoring_errors) < 0.03, is_true())

    a_simple_mw_error = weighted.mean(all_logic_tree_simple$all_par$a, all_logic_tree_simple$all_par_prob_with_Mw_error)
    a_simple_no_mw_error = weighted.mean(all_logic_tree_simple$all_par$a, all_logic_tree_simple$all_par_prob)
    b_simple_mw_error = weighted.mean(all_logic_tree_simple$all_par$b, all_logic_tree_simple$all_par_prob_with_Mw_error)
    b_simple_no_mw_error = weighted.mean(all_logic_tree_simple$all_par$b, all_logic_tree_simple$all_par_prob)

    expect_that(a_simple_mw_error - a_simple_no_mw_error < 0 & 
                abs(a_simple_mw_error - a_simple_no_mw_error) < 0.05, 
                is_true())
    expect_that(abs(b_simple_mw_error - b_simple_no_mw_error) < 0.002, is_true())
    # Key point: 'b' is estimated more poorly when we ignore the magnitude data.
    # At least, this should happen most of the time, depending on data-size /
    # randomness, etc.
    expect_that(abs(b_simple_mw_error - ml_b_ignoring_errors) > abs(b_3000_mw_error - ml_b_ignoring_errors), 
        is_true())


})
