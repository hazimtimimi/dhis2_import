# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Convert an Excel data file into long format to import into DHIS2
#
# Hazim Timimi, 2016 - 2017
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Instructions ----
#
#   1. Make sure DHIS2 reference files are up to date. If new orgunits have been added then
#      in DHIS2 do
#
#               Data Administration app > SQL view > organisation_internal_ids_and_country  >
#               Show SQL View > Download as CSV
#
#      (See dhis2_import_functions.r for the SQL behind the organisation_internal_ids_and_country view)
#
#   2. Edit set_parameters.r to specify check_only mode, country, input and output file names
#   3. Run this script with check_only == TRUE until all data errors have been fixed
#   4. Once assured that input data is consistent with DHIS2 contents (orgunit names and
#      data element codes), run this script with check_only == FALSE
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


# start with empty environment ----
rm(list=ls())

# Load packages ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
library(RODBC)
library(dplyr)
library(tidyr)
library(stringr)

# Set up the running environment ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# This depends on the person, location, machine used etc.and populates the following:
#
# scripts_folder:  Path to folder containing these scripts
#
# check_only:      Whether to run the script to check data consistency only (check_only==TRUE)
#                  or to create the output files (check_only==FALSE)
#
# country:         Name of country whose data will be transformed (needs to exactly match country name in DHIS2)
# test_orgunit:    Name of an orgunit whose data will be output into a separate CSV file for testing
#
#
# input_folder:    Path to folder containing spreadsheet whose data are to be transformed
# input_file:      Name of Excel spreadsheet whose data are to be transformed
#
# input_worksheet: Name of worksheet within the Excel file where data are located
#
# output_folder:   Path to folder where CSV file will be saved
# output_file:     Name of CSV file containing transformed data
#
# dhis2_orgunit_ids_file:      Full path to DHIS2 reference file containing orgunit unique IDs
# dhis2_data_element_ids_file: Full path to DHIS2 reference file containing data element unique IDs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

scripts_folder <- getSrcDirectory(function(x) {x})  # See http://stackoverflow.com/a/30306616

setwd(scripts_folder)

source("set_parameters.r")  # particular to each person so this file is in the ignore list



# Load functions ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source("dhis2_import_functions.r")


# Load DHIS2 reference data ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

orgunits <- get_dhis2_orgunit_ids(dhis2_orgunit_ids_file)

data_and_categories <- get_dhis2_data_element_ids(dhis2_data_element_ids_file)



# Check there are no duplicated names in the DHIS2 orgunits for the specified country ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if (isTRUE(check_only)) {

  duplicated_orgunits <- orgunits %>%
                         filter(countryname == country) %>%
                         check_no_dups_without_diacritics()

  View(duplicated_orgunits)
}


# Load data to be transformed ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setwd(input_folder)

data_to_import <- get_excel_data(input_file, input_worksheet)


# Transform data to long format needed by DHIS2 ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

data_to_import <- unpivot_for_dhis2(data_to_import)

# Remove records with no data
data_to_import <- data_to_import %>%
                  filter(!is.na(value))

# Check periods are in correct format and as expected ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if (isTRUE(check_only)) {

  all_periods <- unique(data_to_import$period)

  View(data.frame(all_periods))
}


# Add orgunit DHIS2 unique IDs ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
data_to_import <- link_country_org_ids(data_to_import, orgunits, country)


# Check there are no orgunits with missing DHIS2 unique IDs ----
if (isTRUE(check_only)) {

  missing_orgunits <- data_to_import %>%
                      filter(is.na(org_uid)) %>%
                      group_by(orgunit) %>%
                      summarise(n())

  View(missing_orgunits)
}


# Add data element DHIS2 unique IDs ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

data_to_import <- link_var_uids(data_to_import, data_and_categories)


# Check there are no data elements with missing DHIS2 unique IDs ----
if (isTRUE(check_only)) {

  missing_data_elements <- data_to_import  %>%
                           filter(is.na(dataelement_uid))  %>%
                           group_by(variable_name)  %>%
                           summarise(n())

  View(missing_data_elements)
}



# Create the CSV data file to be imported into DHIS2 ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if (!isTRUE(check_only)) {

  setwd(output_folder)
  export_for_dhis2(data_to_import, output_file)

  # Create a CSV file containing only one orgunit's data for testing
  # but only if test_orgunit contains a name
  if (nchar(test_orgunit) > 0) {

    data_to_import %>%
      filter(orgunit == toupper(test_orgunit)) %>%
      export_for_dhis2("testing_file")
  }

}


# Reset working folder back to the scripts folder
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
setwd(scripts_folder)


