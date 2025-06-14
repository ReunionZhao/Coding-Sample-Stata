*********************************************
****   Description                        ***
*********************************************

* This program performs textual analysis on tweets related to cryptocurrencies.
* It computes TF-IDF scores using multiple word lists associated with persuasive messaging,
* including morality, sentiment, and virtue/vice dimensions.
* The script processes and labels category-level indicators, counts, shares, and logged TF-IDF scores.
*
* Author: Runping Zhao
* Date:   May 11, 2025

*********************************************



*********************************************
****   Import Word Lists                  ***
*********************************************

clear
set maxvar 100000

* Word‐list setup
global to_import morality_pos morality_neg feelings positive vice virtue
global Data "/Users/zhaorunping/Desktop/Research_Ongoing/2502_Haas_Matteo/Mixed-Banking/Persuasion Analysis of tweets/data"

use "$Data/intermediate/WordLists_Final.dta", clear

* Import each list into a global macro of its words
foreach var of global to_import {
    replace `var' = subinstr(`var', " ", "_", .)
    levelsof `var', local(lv_`var')
    global `var' ""
    foreach w of local lv_`var' {
        global `var' $`var' `w'
    }
}

* Define higher‐level categories
global Prescriptions $morality_pos $morality_neg
global Sentiment     $feelings     $positive
global ViceVirtue    $vice         $virtue
global AllPersuasion $Prescriptions $Sentiment

global categories "morality_pos morality_neg feelings positive vice virtue Prescriptions Sentiment ViceVirtue AllPersuasion"


*********************************************
****   Textual Analysis                   ***
*********************************************

import excel "$Data/source/Tweets_Junghye.xlsx", clear firstrow

keep if inlist(currency_id, "BTC", "ADA", "DOGE", "ETH", "MATIC", "XRP", "SHIB")


gen key_words_total = ""
gen nobs            = _N
gen nwords          = length(text) - length(subinstr(text, " ", "", .)) + 1
replace nwords      = . if missing(text)

foreach X of global categories {

    * Initialize category‐level metrics
    gen `X'_tfidf   = 0
    gen `X'_count   = 0
    gen `X'_share   = 0
    gen `X'_dummy   = 0
    gen key_words_`X' = ""

    * Loop over each dictionary word
    foreach val of global `X' {
        local temp = subinstr("`val'", "_", " ", .)

        * Temporary variable names
        local c1    = "cnt1_`val'"
        local c2    = "cnt2_`val'"
        local tot   = "tot_`val'"
        local df    = "df_`val'"
        local sumd  = "sumd_`val'"

        * Count singular + plural
        capture egen `c1' = noccur(text), string(" `temp' ")
        capture egen `c2' = noccur(text), string(" `temp's ")
        capture gen  `tot' = `c1' + `c2'

        * Document frequency and TF-IDF
        capture gen  `df'         = `tot' > 0
        capture egen `sumd'       = sum(`df')
        capture gen  tfidf_`val'  = cond(`tot' > 0, ///
            (1 + log(`tot')) / (1 + log(nwords)) * log(nobs / `sumd'), 0)

        * Accumulate into category totals
        replace `X'_tfidf = `X'_tfidf + tfidf_`val'
        replace `X'_count = `X'_count + `tot'

        * Concatenate each keyword exactly once
        replace key_words_total = key_words_total + " " + "`temp'" if `tot' > 0
        replace key_words_`X'   = key_words_`X'    + " " + "`temp'" if `tot' > 0

        * Drop all temps
        capture drop `c1' `c2' `tot' `df' `sumd' tfidf_`val'
    }

    * Finalize share and dummy
    replace `X'_share = `X'_count / nwords * 100
    replace `X'_dummy = (`X'_count > 0) * 100
}


*********************************************
****   Log TF-IDF                         ***
*********************************************

foreach var of varlist *_tfidf {
    gen `var'_ln = .
    replace `var'_ln = log(`var') if `var' > 0
    label variable `var'_ln "`var' (log)"
}


*********************************************
****   Labeling                           ***
*********************************************

label var morality_pos_dummy   "Morality positive indicator"
label var morality_neg_dummy   "Morality negative indicator"
label var feelings_dummy       "Feelings indicator"
label var positive_dummy       "Positive indicator"

label var Prescriptions_dummy  "Prescriptions dummy"
label var Sentiment_dummy      "Sentiment dummy"

label var morality_pos_tfidf   "Morality positive tfidf"
label var morality_neg_tfidf   "Morality negative tfidf"
label var feelings_tfidf       "Feelings tfidf"
label var positive_tfidf       "Positive tfidf"
label var Prescriptions_tfidf  "Prescriptions tfidf"
label var Sentiment_tfidf      "Sentiment tfidf"

label var nwords               "Text length"

save "$Data/final/Tweets_Junghye_BagofWords.dta", replace


*********************************************
****   Test of TF-IDF Calculation (Optional)
*********************************************

*preserve

* compute all of "happy"'s intermediate counts, df, sumdf & tfidf —
*egen happy_cnt1    = noccur(text), string(" happy ")
*egen happy_cnt2    = noccur(text), string(" happy's ")
*gen  happy_tot     = happy_cnt1 + happy_cnt2
*gen  happy_df      = happy_tot > 0
*egen happy_sumdf   = sum(happy_df)
*gen  happy_tfidf   = cond(happy_tot > 0, ///
    (1 + log(happy_tot)) / (1 + log(nwords)) * log(nobs / happy_sumdf), 0)

*restore
