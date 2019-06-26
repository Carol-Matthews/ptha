#
# NON-COARRAY
#

source ../../../src/test_run_commands
echo 'Will run openmp version with: ' $OMP_RUN_COMMAND
echo 'Will run coarray version with: ' $CAF_RUN_COMMAND

# Clean existing binary
rm ./BP09
rm -r ./OUTPUTS
# Build the code
make -B -f make_BP09 > build_outfile.log
# Run the code
eval "$OMP_RUN_COMMAND ./BP09 '' > outfile_omp.log"
# Plot and report tests
echo '# Testing openmp version '
Rscript plot_results.R lowresolution_omp
# Store a log file for later tests
cp ./OUTPUTS/RUN*/multidomain_log.log ./multidomain_log_lowresolution_openmp.log

#
# SAME MODEL WITH COARRAY
#
# Clean existing binary
rm ./BP09
#rm -r ./OUTPUTS 
# Build the code
make -B -f make_BP09_coarray > build_outfile.log
# Run the code
eval "$CAF_RUN_COMMAND ./BP09 '' > outfile_ca.log"
# Plot and report tests
echo '# Testing coarray version '
Rscript plot_results.R lowresolution_coarray
# Store a log file for later tests
cp ./OUTPUTS/RUN*/multidomain_log*01.log ./multidomain_log_lowresolution_coarray.log

# Run the comparison script
echo '# Comparing coarray/openmp versions '
Rscript compare_logs_coarray_openmp.R
