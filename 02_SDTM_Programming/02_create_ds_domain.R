# Calling the packages needed
library(sdtm.oak)
library(stringr)
library(lubridate)
library(pharmaverseraw)
library(pharmaversesdtm)
library(dplyr)
library(here)

ds_raw <- pharmaverseraw::ds_raw

dm <- pharmaversesdtm::dm

# Generate oak internal variables
ds_raw <- ds_raw %>%
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

#Controlled Terminology Input 
study_ct <- read.csv(here("02_SDTM_Programming", "sdtm_ct.csv"))

#Only valid SDTM Oak ID tracking variables 
ds <- ds_raw %>% 
  select(oak_id, raw_source, patient_number)


ds <- ds %>%
  # Map VISIT using INSTANCE
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  # Map VISITNUM from INSTANCE using assign_ct
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",         
    id_vars = oak_id_vars()
  ) 

ds <- ds %>%
  # RULE 1: If OTHERSP is null, apply normal term mappings
  assign_no_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP)),
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP)),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  # RULE 2: If OTHERSP is NOT null, overwrite DSTERM and DSDECOD with OTHERSP value
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) %>%
  
  # RULE 3: Category Mapping Conditions (DSCAT)
  hardcode_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) & IT.DSDECOD == "Randomized"),
    raw_var = "FORML",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) & IT.DSDECOD != "Randomized"),
    raw_var = "FORML",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP)),
    raw_var = "FORML",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    ct_spec = study_ct,
    ct_clst = "C74558",
    id_vars = oak_id_vars()
  )

#Map DSDTC and DSSTDTC row-by-row using assign_datetime
ds <- ds %>%
  # Force the raw date column to be a character format first
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),           # Vector of both date and time columns
    tgt_var = "DSDTC",
    raw_fmt = list(c("m-d-y"), "H:M"),           # Maps formats to their matching variables
    id_vars = oak_id_vars()
  ) 

# Derive standard structural SDTM variables
ds <- ds %>%
  dplyr::mutate(
    STUDYID = ds_raw$STUDY,      
    DOMAIN  = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM),
    DSDECOD  = toupper(DSDECOD), # Converts to uppercase
    DSSTDTC = stringr::str_sub(DSDTC, 1, 10) # Extracts the ISO date segment
  ) %>%
  
  # 2. Sequence derivation
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSTERM", "DSDTC")
  ) %>%
  
  # 3. Derive study day for collection date (DSDY)
  derive_study_day(
    sdtm_in = .,          
    dm_domain = dm,       
    tgdt = "DSDTC",       
    refdt = "RFXSTDTC",   
    study_day_var = "DSDY" 
  ) %>%
  
  # 4. Derive study day for event start date (DSSTDY)
  derive_study_day(
    sdtm_in = .,          
    dm_domain = dm,       
    tgdt = "DSSTDTC",       
    refdt = "RFXSTDTC",   
    study_day_var = "DSSTDY" 
  ) %>%
  
  # 5. Clean variable selection matching standard CDISC DS requirements
  dplyr::select(
    "STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", "DSDECOD", 
    "DSCAT", "VISIT", "VISITNUM", "DSDTC", "DSSTDTC", "DSDY", "DSSTDY"
  )
