# Reformat data from typical 'wide format' Excel spreadsheets into CSV files conforming to DHIS2 data import specifications
*(including transforming orgunit names and data element codes into DHIS2 internal unique identifiers)*

## Overview

Use this project to transform Excel spreadsheets into CSV files:

### Input Excel format

orgunit | period | variable_code_1 |  variable_code_2 |  variable_code_3 | etc ... |
------- | ------ | --------------- | ---------------- | ---------------- | ------- | 
District 1 | 2015Q1 | 120 | 56 | 12 | etc ... 
District 2 | 2015Q1 | 95 | 46 | 35 | etc ... 
etc ... |  |  |  |  | 

or, if you have codes for the orgunits:

code | period | variable_code_1 |  variable_code_2 |  variable_code_3 | etc ... |
------- | ------ | --------------- | ---------------- | ---------------- | ------- | 
code1 | 2015Q1 | 120 | 56 | 12 | etc ... 
cde2 | 2015Q1 | 95 | 46 | 35 | etc ... 
etc ... |  |  |  |  | 


### Output CSV format 

This project creates CSV output files that conform to the DHIS@ specification at https://docs.dhis2.org/2.25/en/developer/html/webapi_data_values.html#webapi_data_values_csv 


## Requirements

* **R packages**:
    * RODBC
    * dplyr
    * tidyr
    * stringr

* **R** (I developed these scripts using R version 3.3.2)

* **RStudio**, although not strictly necessary (I developed these scripts using RStudio version 1.0.136)

* **DHIS2** (I developed these scripts using DHIS2 version 2.25). 
    
    In our instance we have the following orgunit hierarchy:
    
    1. Global
    2. Region
    3. Country
    4. Admin 1
    5. Admin 2 or facility
    6. Facility
    
    You will need 2 SQL views in your DHIS2 instance:

    * organisation_internal_ids_and_country
    * data_and_category_internal_ids

    The `organisation_internal_ids_and_country` view lists the country to which an orgunit belongs, assuming it is level 3 of the hierarchy. This is used to filter orgunits by country.

## Instructions

1. Make sure DHIS2 reference files are up to date. If new orgunits have been added then log into DHIS2 and do the following

    `Data Administration app > SQL view > organisation_internal_ids_and_country  > Show SQL View > Download as CSV`
    
2. Edit `set_parameters.r` to specify check_only mode, country, input and output file names

3. After making sure `check_only <- TRUE` in `set_parameters.r`, do in RStudio:

    `> source("transform_data.r")`

4. In RStudio, check the contents of the following dataframes:

    * `duplicated_orgunits`   (make sure it is empty)
    * `all_periods`  (make sure the periods are the ones you expected to see)
    * `missing_orgunits`    (make sure it is empty)
    * `missing_data_elements` (make sure it is empty)

    Fix the input file if any of the above are not true and repeat steps 3 and 4 until all conditions are met.
    
5. Once assured that input data is consistent with DHIS2 contents (orgunit names and data element codes all match), change `check_only <- FALSE` in `set_parameters.r` and then do in RStudio:

    `> source("transform_data.r")`
    
6. Find and import CSV files into DHIS2. If you had set `test_orgunit` to an orgunit name then you will find a file called `testing_file_to_import_yyyy-mm-dd.csv` in your output folder. This testing file has data just for the one orgunit which you can import into DHIS2 to verify that the data are being imported correctly. 

    Once satisfied you can import the full data file, called `ZZZZZ_to_import_yyyy-mm-dd.csv`, where ZZZZZ is the output file name you specified in `set_parameters.r`.


## The set_parameters.r file

You need to create this to match your local computing environment. It sets up the paths to input and output folders and the connection string to the database (if available).

Here is a template to use:

```
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up the running environment for reformating an Excel data file into a
# CSV file that can be imported directly into DHIS2
#
# Edit this file each time a new dataset needs to be transformed
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# 1. Path to folder containing these scripts
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

scripts_folder <- getwd() # when running in an RStudio project this will be the root folder of the project.

# 2. Script running mode (TRUE to check only or FALSE to create output files)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

check_only <- TRUE

# 3. Method of matchig orgunits to internal DHIS2 ID Orgunit matching mode
# (TRUE to match on orgunit code or FALSE to match on shortname)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

match_on_orgcode <- TRUE

# 4. Country name and, if you want, an org unit to use for a test data file
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

country <- "Timimistan"
test_orgunit <- "Hazimabad"
test_orgcode <- "HT-01"

# 5. Input file
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

input_folder <- "D:/Example/Timimistan/original_data"
input_file <- "2014-2016_Notifications_Timimistan.xlsx"
input_worksheet <- "Sheet1"

# 6. Output file
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

output_folder <- "D:/Example/Timimistan/transformed_data"
output_file <- "timimistan_notifs"


# 7. Full path to the DHIS2 reference files for data element and orgunit unique IDs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

dhis2_orgunit_ids_file <- "D:/Example/dhis2reference/organisation_internal_ids_and_country.csv"
dhis2_data_element_ids_file <- "D:/Example/dhis2reference/data_and_category_internal_ids.csv"
```


