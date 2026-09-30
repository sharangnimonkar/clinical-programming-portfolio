"""
Clinical Trial GenAI Data Assistant
=====================================
Translates free-text clinical questions into structured Pandas queries
using an LLM (OpenAI GPT-3.5 via LangChain) through LangChain.

If no API key is available, the agent falls back to a mock LLM
so the full Prompt -> Parse -> Execute flow is always demonstrable.
"""

import os
import json
import re
import pandas as pd
from typing import Optional
from dataclasses import dataclass


# ---------------------------------------------------------------------------
# Dataset schema — passed to the LLM as context
# ---------------------------------------------------------------------------

SCHEMA_DESCRIPTION = """
You are a clinical data assistant. The dataset is an ADaM ADAE (Adverse Events)
table from a clinical trial. Below are the key columns you may query:

| Column   | Description                                          | Example values                        |
|----------|------------------------------------------------------|---------------------------------------|
| AESEV    | Severity / intensity of the adverse event            | MILD, MODERATE, SEVERE                |
| AETERM   | Verbatim adverse event term reported by the subject  | HEADACHE, NAUSEA, VOMITING            |
| AEDECOD  | MedDRA preferred term (decoded AE term)              | HEADACHE, NAUSEA, VOMITING            |
| AESOC    | MedDRA System Organ Class (body system)              | CARDIAC DISORDERS, SKIN DISORDERS     |
| AEBODSYS | Body system (same as AESOC in this dataset)          | GASTROINTESTINAL DISORDERS            |
| AESER    | Whether the AE was serious (Y/N)                     | Y, N                                  |
| AEREL    | Causality / relatedness to study drug                | NONE, REMOTE, POSSIBLE, PROBABLE      |
| ACTARM   | Treatment arm the subject was assigned to            | Placebo, Xanomeline High Dose         |

Synonyms to be aware of:
- "severity", "intensity", "grade"           → AESEV
- "condition", "event", "term", "diagnosis"  → AETERM or AEDECOD
- "body system", "organ class", "system"     → AESOC
- "serious", "SAE"                           → AESER
- "related", "causality", "causation"        → AEREL
- "treatment", "arm", "group", "dose"        → ACTARM

Your task: given a user question, return ONLY a JSON object with:
  {
    "target_column": "<column name from the table above>",
    "filter_value":  "<the value to filter for, uppercased>",
    "reasoning":     "<one sentence explaining your mapping>"
  }

Return ONLY the JSON. No markdown, no explanation outside the JSON.
"""


# ---------------------------------------------------------------------------
# Structured output dataclass
# ---------------------------------------------------------------------------

@dataclass
class ParsedQuery:
    target_column: str
    filter_value: str
    reasoning: str


# ---------------------------------------------------------------------------
# Mock LLM — keyword-based fallback when no API key is set
# ---------------------------------------------------------------------------

class MockLLM:
    """
    Rule-based fallback that mimics LLM JSON output.
    Covers common synonym mappings so the full flow is demonstrable
    without an API key.
    """

    SEVERITY_KEYWORDS   = ["sever", "mild", "moderate", "intense", "intensity", "grade"]
    TERM_KEYWORDS       = ["term", "condition", "event", "diagnosis", "headache", "nausea",
                           "vomiting", "pain", "erythema", "pruritus", "dizziness", "fatigue"]
    SOC_KEYWORDS        = ["body system", "organ class", "cardiac", "skin", "gastro",
                           "nervous", "psychiatric", "eye", "ear", "renal", "hepat",
                           "musculo", "respiratory", "vascular", "endocrine"]
    SERIOUS_KEYWORDS    = ["serious", "sae", "hospitaliz", "life-threatening"]
    RELATED_KEYWORDS    = ["causality", "causation", "drug-related", "probable", "possible",
                           "remote", "none"]
    ARM_KEYWORDS        = ["arm", "group", "treatment", "placebo", "xanomeline",
                           "high dose", "low dose"]

    # Severity value normalisation
    SEV_MAP = {"mild": "MILD", "moderate": "MODERATE", "severe": "SEVERE"}

    # SOC partial-match map
    SOC_MAP = {
        "cardiac":       "CARDIAC DISORDERS",
        "skin":          "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
        "gastro":        "GASTROINTESTINAL DISORDERS",
        "nervous":       "NERVOUS SYSTEM DISORDERS",
        "psychiatric":   "PSYCHIATRIC DISORDERS",
        "eye":           "EYE DISORDERS",
        "ear":           "EAR AND LABYRINTH DISORDERS",
        "renal":         "RENAL AND URINARY DISORDERS",
        "hepat":         "HEPATOBILIARY DISORDERS",
        "musculo":       "MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS",
        "respiratory":   "RESPIRATORY, THORACIC AND MEDIASTINAL DISORDERS",
        "vascular":      "VASCULAR DISORDERS",
        "endocrine":     "ENDOCRINE DISORDERS",
    }

    def invoke(self, question: str) -> str:
        q = question.lower()

        # --- AESEV ---
        for kw in self.SEVERITY_KEYWORDS:
            if kw in q:
                for sev_kw, sev_val in self.SEV_MAP.items():
                    if sev_kw in q:
                        return json.dumps({
                            "target_column": "AESEV",
                            "filter_value":  sev_val,
                            "reasoning":     f"Question mentions severity keyword '{kw}' "
                                             f"and value '{sev_val}'."
                        })
                # severity keyword found but no explicit value — default to MODERATE
                return json.dumps({
                    "target_column": "AESEV",
                    "filter_value":  "MODERATE",
                    "reasoning":     "Severity keyword detected; defaulting to MODERATE."
                })

        # --- AESER ---
        for kw in self.SERIOUS_KEYWORDS:
            if kw in q:
                return json.dumps({
                    "target_column": "AESER",
                    "filter_value":  "Y",
                    "reasoning":     f"Question mentions '{kw}', mapping to AESER=Y."
                })

        # --- AESOC (check before AEREL to avoid generic word false positives) ---
        for soc_kw, soc_val in self.SOC_MAP.items():
            if soc_kw in q:
                return json.dumps({
                    "target_column": "AESOC",
                    "filter_value":  soc_val,
                    "reasoning":     f"Question mentions body system keyword '{soc_kw}'."
                })

        # --- AEREL ---
        for kw in self.RELATED_KEYWORDS:
            if kw in q:
                rel_val = kw.upper() if kw in ["probable","possible","remote","none"] else "PROBABLE"
                return json.dumps({
                    "target_column": "AEREL",
                    "filter_value":  rel_val,
                    "reasoning":     f"Question mentions relatedness keyword '{kw}'."
                })

        # --- ACTARM ---
        for kw in self.ARM_KEYWORDS:
            if kw in q:
                if "high" in q:
                    val = "Xanomeline High Dose"
                elif "low" in q:
                    val = "Xanomeline Low Dose"
                elif "placebo" in q:
                    val = "Placebo"
                else:
                    val = "Placebo"
                return json.dumps({
                    "target_column": "ACTARM",
                    "filter_value":  val,
                    "reasoning":     f"Question mentions treatment arm keyword '{kw}'."
                })

        # --- AETERM / AEDECOD (specific condition) ---
        for kw in self.TERM_KEYWORDS:
            if kw in q:
                # Extract the specific term from the question
                val = kw.upper()
                return json.dumps({
                    "target_column": "AEDECOD",
                    "filter_value":  val,
                    "reasoning":     f"Question mentions a specific AE term '{kw}', "
                                     f"mapping to AEDECOD."
                })

        # Fallback
        return json.dumps({
            "target_column": "AESEV",
            "filter_value":  "MILD",
            "reasoning":     "Could not confidently map question; defaulting to AESEV=MILD."
        })


# ---------------------------------------------------------------------------
# Real LLM via LangChain + OpenAI (used when OPENAI_API_KEY is set)
# ---------------------------------------------------------------------------

def _build_real_llm():
    try:
        from langchain_openai import ChatOpenAI
        from langchain.schema import HumanMessage, SystemMessage

        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            return None

        llm = ChatOpenAI(model="gpt-3.5-turbo", temperature=0, openai_api_key=api_key)

        class WrappedLLM:
            def invoke(self, question: str) -> str:
                messages = [
                    SystemMessage(content=SCHEMA_DESCRIPTION),
                    HumanMessage(content=question),
                ]
                response = llm.invoke(messages)
                return response.content

        return WrappedLLM()

    except ImportError:
        return None


# ---------------------------------------------------------------------------
# ClinicalTrialDataAgent
# ---------------------------------------------------------------------------

class ClinicalTrialDataAgent:
    """
    Translates free-text clinical questions into Pandas DataFrame queries.

    Flow:
        User question
            → LLM (real or mock) with schema context
            → Structured JSON { target_column, filter_value }
            → Pandas filter on ADAE DataFrame
            → { subject_count, unique_usubjids }
    """

    def __init__(self, dataframe: pd.DataFrame):
        self.df = dataframe.copy()
        # Normalise key string columns to uppercase for consistent matching
        for col in ["AESEV", "AETERM", "AEDECOD", "AESOC", "AEBODSYS",
                    "AESER", "AEREL", "USUBJID"]:
            if col in self.df.columns:
                self.df[col] = self.df[col].astype(str).str.upper().str.strip()

        # Use real LLM if API key is available, otherwise fall back to mock
        real_llm = _build_real_llm()
        if real_llm:
            self.llm = real_llm
            self.llm_mode = "OpenAI GPT-3.5-turbo (LangChain)"
        else:
            self.llm = MockLLM()
            self.llm_mode = "Mock LLM (no API key set)"

        print(f"[Agent] LLM mode: {self.llm_mode}")

    # ------------------------------------------------------------------
    # Step 1 — Parse: send question to LLM, get structured JSON back
    # ------------------------------------------------------------------

    def _parse_question(self, question: str) -> ParsedQuery:
        raw = self.llm.invoke(question)

        # Strip markdown fences if LLM wraps in ```json ... ```
        raw = re.sub(r"```(?:json)?", "", raw).strip().rstrip("`").strip()

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise ValueError(f"LLM returned invalid JSON: {raw}") from e

        return ParsedQuery(
            target_column=data.get("target_column", "").strip().upper(),
            filter_value =data.get("filter_value",  "").strip().upper(),
            reasoning    =data.get("reasoning",     ""),
        )

    # ------------------------------------------------------------------
    # Step 2 — Execute: apply the Pandas filter
    # ------------------------------------------------------------------

    def _execute_query(self, parsed: ParsedQuery) -> dict:
        col = parsed.target_column

        # Handle ACTARM case-sensitivity (mixed case in dataset)
        if col == "ACTARM":
            actarm_col = self.df["ACTARM"] if "ACTARM" in self.df.columns else None
            if actarm_col is not None:
                # Case-insensitive match
                mask = self.df["ACTARM"].str.upper() == parsed.filter_value.upper()
                filtered = self.df[mask]
            else:
                filtered = self.df.iloc[0:0]
        elif col not in self.df.columns:
            return {
                "error": f"Column '{col}' not found in dataset.",
                "available_columns": list(self.df.columns),
            }
        else:
            filtered = self.df[self.df[col] == parsed.filter_value]

        unique_subjects = sorted(filtered["USUBJID"].unique().tolist())

        return {
            "subject_count":   len(unique_subjects),
            "unique_usubjids": unique_subjects,
        }

    # ------------------------------------------------------------------
    # Public: ask() — full pipeline
    # ------------------------------------------------------------------

    def ask(self, question: str) -> dict:
        """
        Run the full Prompt -> Parse -> Execute pipeline.

        Returns a dict with:
          - question        : original question
          - target_column   : column the LLM mapped to
          - filter_value    : value the LLM extracted
          - reasoning       : LLM's explanation
          - subject_count   : number of unique matching subjects
          - unique_usubjids : list of matching USUBJID values
        """
        parsed = self._parse_question(question)
        result = self._execute_query(parsed)

        return {
            "question":      question,
            "target_column": parsed.target_column,
            "filter_value":  parsed.filter_value,
            "reasoning":     parsed.reasoning,
            **result,
        }
