# Calling the packages needed
library(pharmaversesdtm)
library(admiral)
library(dplyr)

dm <- pharmaversesdtm::dm
ds <- pharmaversesdtm::ds
ex <- pharmaversesdtm::ex
ae <- pharmaversesdtm::ae
lb <- pharmaversesdtm::lb
vs <- pharmaversesdtm::vs

#DM domain is used as the basis for ADSL
adsl <- dm %>%
  select(-DOMAIN)


# lookup table for Age Group Variables
agegr9_lookup <- exprs(
  ~condition,             ~AGEGR9,      ~AGEGR9N,
  AGE < 18,                 "<18",             1,
  between(AGE, 18, 50), "18 - 50",             2,
  AGE > 50,                 ">50",             3,
  is.na(AGE),        NA_character_,   NA_integer_
)

adsl <- adsl %>%
  derive_vars_cat(
    definition = agegr9_lookup
  )


# Deriving start and end time of exposure to first and last respectively
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST"
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    time_imputation = "last"
  )

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  )

#The datetime variables returned can be converted to dates
adsl <- adsl %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM))

#TRTSDT and TRTEDT are used to derive Treatment duration (TRTDURD).
adsl <- adsl %>%
  derive_var_trtdurd()


#Deriving Intent to Treat Flag
adsl <- adsl %>%
  derive_vars_cat(
    definition = exprs(
      ~condition,   ~ITTFL,
      !is.na(ARM),     "Y", # Set to "Y" if ARM is not missing
      TRUE,            "N"  # Else set to "N"
    )
  )

#Deriving Abnormal Diastolic Blood Pressure Flag
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = vs,               # Sourced from Vital Signs (VS)
    by_vars = exprs(STUDYID, USUBJID),
    new_var = ABNSBPFL,
    false_value = "N",
    missing_value = "N",
    # Below Condition matching our specification
    condition = VSTESTCD == "SYSBP" & 
      VSSTRESU == "mmHg" & 
      (VSSTRESN >= 140 | VSSTRESN < 100)
  )

#Deriving Cardiac Population Flag.
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = ae,                  # Sourced from Adverse Events (AE)
    by_vars = exprs(STUDYID, USUBJID),
    new_var = CARPOPFL,
    false_value = NA_character_,       # Else set to missing
    missing_value = NA_character_,     # Else set to missing
    # # Below Condition matching our specification
    condition = str_to_upper(AESOC) == "CARDIAC DISORDERS"
  )

# Pre-processing step -
# Clean and filter VS for complete dates with valid results
vs_alive <- vs %>%
  filter(
    !is.na(VSDTC) & nchar(VSDTC) >= 10,                     # Ensures complete datepart (YYYY-MM-DD)
    !(is.na(VSSTRESN) & (is.na(VSSTRESC) | VSSTRESC == "")) # Not both missing
  )

# Clean and filter AE for complete onset dates
ae_alive <- ae %>%
  filter(!is.na(AESTDTC) & nchar(AESTDTC) >= 10)


#Clean and filter DS for complete disposition dates
ds_alive <- ds %>%
  filter(!is.na(DSSTDTC) & nchar(DSSTDTC) >= 10)


# Derive of Last Alive Date
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      # (1) Last complete date of vital assessment
      event(
        dataset_name = "vs_alive",
        order = exprs(VSDTC, VSSEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(VSDTC),
          seq = VSSEQ
        )
      ),
      # (2) Last complete onset date of AEs
      event(
        dataset_name = "ae_alive",
        order = exprs(AESTDTC, AESEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(AESTDTC),
          seq = AESEQ
        )
      ),
      # (3) Last complete disposition date
      event(
        dataset_name = "ds_alive",
        order = exprs(DSSTDTC, DSSEQ),
        set_values_to = exprs(
          LSTALVDT = convert_dtc_to_dt(DSSTDTC),
          seq = DSSEQ
        )
      ),
      # (4) Last date of treatment administration (Datepart of TRTEDTM)
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDTM),
        set_values_to = exprs(
          LSTALVDT = date(TRTEDTM), # Extracts the datepart of the datetime
          seq = 0
        )
      )
    ),
    source_datasets = list(
      vs_alive = vs_alive, 
      ae_alive = ae_alive, 
      ds_alive = ds_alive, 
      adsl = adsl
    ),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT)
  )


adsl <- adsl %>%
  # Relocate and sequence variables strictly per CDISC ADaM IG guidelines
  dplyr::select(
    # Core Identifiers
    STUDYID, USUBJID, SUBJID, SITEID, COUNTRY,
    
    # Baseline Demographics & Groupings
    AGE, AGEU, AGEGR9, AGEGR9N, SEX, RACE, ETHNIC, BRTHDTC,
    
    # Treatment Arms
    ARMCD, ARM, ACTARMCD, ACTARM, ARMNRS, ACTARMUD,
    
    # Raw SDTM Reference Milestones
    RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC, DMDTC, DMDY,
    
    # Foundation Analysis Flags
    ITTFL,
    
    # Derivation Treatment Windows (Datetime and Date)
    TRTSDTM, TRTSTMF, TRTEDTM, TRTETMF, TRTSDT, TRTEDT, TRTDURD,
    
    # Specific Efficacy, Safety, and Medical Subpopulations
    ABNSBPFL, CARPOPFL,
    
    # Survival Tracker Metrics
    LSTALVDT, DTHDTC, DTHFL
  )
