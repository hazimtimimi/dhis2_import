# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Functions used to transform data into long format and to
# link to DHIS2 identifiers to import into DHIS2
# Hazim Timimi, 2016
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

get_dhis2_orgunit_ids <- function(orgunit_ids_csv_file) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Import CSV reference file exported from DHIS2
  # (Data Administration app > SQL view > organisation_internal_ids_and_country  >
  #            Show SQL View > Download as CSV)
  #
  # SELECT o.uid,
  #           o.shortname,
  #           o.code,
  #           c.shortname AS countryname
  # FROM organisationunit AS o
  # INNER JOIN _orgunitstructure ON
  #                  o.uid = _orgunitstructure.organisationunituid
  #
  # INNER JOIN organisationunit AS c ON
  #                  _orgunitstructure.uidlevel3 = c.uid
  #
  # ORDER BY o.shortname;
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


  orgunit_ids <- read.csv(orgunit_ids_csv_file,
                          stringsAsFactors = FALSE,
                          encoding = "UTF-8")

  return(orgunit_ids)

}


get_dhis2_data_element_ids <- function(data_element_ids_csv_file) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Import CSV reference file exported from DHIS2
  # (Data Administration app > SQL view > data_and_category_internal_ids  >
  #            Show SQL View > Download as CSV)
  #
  # SELECT 	dataelement.uid AS dataelement_uid,
  # 		dataelement.code AS dataelement_code,
  # 		dataelement.name AS dataelement_name,
  # 		dataelement.shortname AS dataelement_shortname,
  #
  # 		categoryoptioncombo.uid as categoryoptioncombo_uid,
  # 		categoryoptioncombo.code as categoryoptioncombo_code,
  # 		categoryoptioncombo.name as categoryoptioncombo_name
  #
  #
  # FROM	dataelement
  # 			INNER JOIN categorycombos_optioncombos ON
  # 				dataelement.categorycomboid = categorycombos_optioncombos.categorycomboid
  #
  # 			LEFT JOIN categoryoptioncombo ON
  # 				categorycombos_optioncombos.categoryoptioncomboid = categoryoptioncombo.categoryoptioncomboid
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  data_ids <- read.csv(dhis2_data_element_ids_file,
                       stringsAsFactors = FALSE)

  # Create an additional field which is the combination of dataelement_code and categoryoptioncombo_code
  # to make up TME-style variables such as newrel_labconf_cur

  data_ids$compound_code <- ifelse(!is.na(data_ids$categoryoptioncombo_code),
                                          paste0(data_ids$dataelement_code,
                                                 data_ids$categoryoptioncombo_code),
                                          NA)
  return(data_ids)

}

check_no_dups_without_diacritics <- function(dhis2_orgunits, match_code) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Finds if there are any duplicated orgunit names or codes in DHIS2 if we ignore
  # diacritics
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  if (isTRUE(match_code)) {

    # ignore short name and just look at codes

    duplicates <- dhis2_orgunits %>%
                  group_by(code) %>%
                  arrange(code) %>%
                  filter(n()>1)

  } else {

   # convert names to upper case and accented characters to plain text characters

    dhis2_orgunits$shortname <- toupper(dhis2_orgunits$shortname)
    dhis2_orgunits$shortname <- gsub("É", "E", dhis2_orgunits$shortname)
    dhis2_orgunits$shortname <- gsub("Ï", "I", dhis2_orgunits$shortname)
    dhis2_orgunits$shortname <- gsub("Ô", "O", dhis2_orgunits$shortname)

    duplicates <- dhis2_orgunits %>%
                  group_by(shortname) %>%
                  arrange(shortname) %>%
                  filter(n()>1)
  }


  return(duplicates)
}



get_excel_data <- function(filename, worksheet){

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Read data from an Excel worksheet using RODBC
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  conn <- odbcConnectExcel2007(filename)
  data_to_transform <- sqlFetch(conn,worksheet, stringsAsFactors = FALSE)
  odbcClose(conn)
  return(data_to_transform)

}


unpivot_for_dhis2 <- function(dataframe, match_code) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Unpivot a dataframe into long format used by DHIS2 as specified at
  # https://docs.dhis2.org/2.25/en/developer/html/webapi_data_values.html#webapi_data_values_csv
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if (isTRUE(match_code)) {

  #Drop the orgunit name if it exists
  if ("orgunit" %in% colnames(dataframe)) {
    dataframe <- select(dataframe, -orgunit)
  }

  #keep the organisation code
  dataframe %>% gather(key = variable_name,
                       value,
                       # and specify the variables to exclude from long format
                       # (i.e. they become the keys -- code and period)
                       -code, -period)

} else {

  # keep the organisation shortname
  dataframe %>% gather(key = variable_name,
                       value,
                       # and specify the variables to exclude from long format
                       # (i.e. they become the keys -- orgunit and period)
                       -orgunit, -period)

}



}



link_country_org_ids <- function(dataframe, dhis2_orgunits, country) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Add unique dhis2 internal orgunit codes to a dataframe, matching on
  # orgunit short names
  #
  # The file is filtered by country name to avoid linking to an organisation with
  # the same name but in a different country
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # Get rid of empty rows (Orgunit empty)
  dataframe <- dataframe %>%
               filter(is.na(orgunit) == FALSE)

  # Remove any trailing spaces from the orgname in the data to import
  dataframe$orgunit <- sub("\\s+$", "", dataframe$orgunit)


  # Filter the DHIS2 org units by country
  dhis2_orgunits <- dhis2_orgunits %>%
                    filter(countryname == country)

  # Convert names from DHIS2 and the data to import to upper case
  dhis2_orgunits$shortname <- toupper(dhis2_orgunits$shortname)
  dataframe$orgunit <- toupper(dataframe$orgunit)

  # Get problems with accented characters that are UTF-8 encoded in DHIS2
  # CSV download, but can't get them as UTF-8 from Tomas's spreadsheets
  # Tried loads of different converstions but couldn't get it to work. the latin1
  # encoding of the names in the spreadsheets don't convert to clean UTF-8 for some
  # reason ... so have to bodge this which is most unsatisfactory

  # convert accented characters to plain text characters
  # For some reason a command like
  #
  # > dataframe$orgunit <- gsub("É", "E", dataframe$orgunit)
  #
  # works in interactive mode but not when called in this function, maybe because
  # of the way the chaaracter is stored in the R file.
  # Finally got this method to work by converting the data type of the orgunit to UTF-8

  dataframe$orgunit <- iconv(dataframe$orgunit, to="UTF-8")

  # link to the DHIS2 file containing orgunit unique IDs
  dataframe <- dataframe %>%
                left_join(dhis2_orgunits, by = c("orgunit" = "shortname")) %>%
                rename(org_uid = uid)


  return(dataframe)

}

link_country_org_ids_by_code <- function(dataframe, dhis2_orgunits, country) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Add unique dhis2 internal orgunit codes to a dataframe, matching on
  # orgunit *codes* instead of short names
  #
  # The file is filtered by country name to avoid linking to an organisation with
  # the code but in a different country
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  # Get rid of empty rows (code empty)
  dataframe <- dataframe %>%
               filter(is.na(code) == FALSE)

  # Remove any trailing spaces from the code in the data to import
  dataframe$code <- sub("\\s+$", "", dataframe$code)


  # Filter the DHIS2 org units by country
  dhis2_orgunits <- dhis2_orgunits %>%
                    filter(countryname == country)

  # Convert codes from DHIS2 and the data to import to upper case
  dhis2_orgunits$code <- toupper(dhis2_orgunits$code)
  dataframe$code <- toupper(dataframe$code)

  # link to the DHIS2 file containing orgunit unique IDs
  dataframe <- dataframe %>%
                left_join(dhis2_orgunits, by = c("code" = "code")) %>%
                rename(org_uid = uid)


  return(dataframe)

}


link_var_uids <- function(dataframe, dhis2_variable_uids) {

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Add unique dhis2 internal data element codes to a dataframe, matching on
  # TME-style data element codes stored in DHIS2
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  dataframe <- dataframe %>%
              left_join(dhis2_variable_uids, by = c("variable_name" = "compound_code"))

  return(dataframe)
}


export_for_dhis2 <- function(dataframe, filename){

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Export data in the format specified at
  # https://dhis2.github.io/dhis2-docs/2.23/en/developer/html/ch01s15.html#d0e2983
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  dataframe %>%  mutate(attroptioncombo = NA) %>%

                        select(dataelement_uid,
                               period,
                               org_uid,
                               categoryoptioncombo_uid,
                               attroptioncombo,
                               value) %>%

                        write.csv(file=paste0(filename, "_to_import_",Sys.Date(),".csv"),
                                  na = "",
                                  row.names = FALSE)
}
