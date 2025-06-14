*******************************************************
****   Description                                  ***
*******************************************************

* This .do file conducts a dispersion analysis of marketing outcomes
* across different fixed effects (bank, time, state, and their interactions).
* It runs models on two dependent variables:
*   (1) Signup Bonuses
*   (2) Unique Individuals (proxy for mailing volumes)
* It also defines a helper program to automate regressions and 
* export results as esttab-formatted LaTeX tables.
*
* Author: Runping Zhao
* Date:   May 7, 2025

*******************************************************


*******************************************************
* Clean up & Set environment
*******************************************************
cap prog drop _all
clear
set more off

* Define root directory
global root "/Users/zhaorunping/Desktop/Research_Ongoing/2502_Haas_Matteo/Mixed-Banking/Figure bonus and volume dispersion in Comperemedia"

*******************************************************
* Import Data
*******************************************************
import delimited "${root}/data/final/for reg/comperemedia_bank-time-state_level.csv", clear

* Generate identifiers
egen bankym = group(primarycompany ym_date), label
egen bankstate = group(primarycompany state), label
egen stateym = group(ym_date state), label

*******************************************************
* Define regression helper
*******************************************************
cap program drop run_regression
program define run_regression
    syntax varlist(min=1 max=1), FE(varname) MODELNAME(str)

    local yvar `varlist'

    reghdfe `yvar', absorb(`fe') tol(0.0001)

    estadd local FE_Bank       = cond("`fe'" == "primarycompany", "Yes", "No")
    estadd local FE_YearMonth  = cond("`fe'" == "ym_date", "Yes", "No")
    estadd local FE_State      = cond("`fe'" == "state", "Yes", "No")
    estadd local FE_BankMonth  = cond("`fe'" == "bankym", "Yes", "No")
    estadd local FE_BankState  = cond("`fe'" == "bankstate", "Yes", "No")
    estadd local FE_StateMonth = cond("`fe'" == "stateym", "Yes", "No")

    estadd scalar ar2 = e(r2_a)

    quietly summarize `yvar' if e(sample)
    estadd scalar DV_mean = r(mean)
    estadd scalar DV_sd   = r(sd)

    eststo `modelname'
end

*******************************************************
* Run models: Signup Bonuses
*******************************************************
eststo clear
run_regression signup_bonuses_total, fe(primarycompany) modelname(SB1)
run_regression signup_bonuses_total, fe(ym_date)        modelname(SB2)
run_regression signup_bonuses_total, fe(state)          modelname(SB3)
run_regression signup_bonuses_total, fe(bankym)         modelname(SB4)
run_regression signup_bonuses_total, fe(bankstate)      modelname(SB5)
run_regression signup_bonuses_total, fe(stateym)        modelname(SB6)

*******************************************************
* Run models: Unique Individuals
*******************************************************
run_regression uniindividual_num, fe(primarycompany) modelname(U1)
run_regression uniindividual_num, fe(ym_date)        modelname(U2)
run_regression uniindividual_num, fe(state)          modelname(U3)
run_regression uniindividual_num, fe(bankym)         modelname(U4)
run_regression uniindividual_num, fe(bankstate)      modelname(U5)
run_regression uniindividual_num, fe(stateym)        modelname(U6)



*******************************************************
* Program: Export Wide 6-Column Esttab Table
*******************************************************
cap program drop export_table_wide6
program define export_table_wide6
    syntax namelist(min=1), DVNAME(str) OUTPATH(str) TITLE(str) LABELNAME(str) TABLABEL(str)

    esttab `namelist' using "`outpath'", ///
        replace tex ///
        label se star(* 0.1 ** 0.05 *** 0.01) ///
        varlabels(`dvname' "`labelname'") ///
        stats(FE_Bank FE_YearMonth FE_State FE_BankMonth FE_BankState FE_StateMonth ///
              r2 ar2 DV_mean DV_sd N, ///
              fmt(%9s %9s %9s %9s %9s %9s %5.3f %5.3f %9.2f %9.2f %9.0g) ///
              labels("Bank F.E." "Year-Month F.E." "State F.E." "Bank×Time F.E." ///
                     "Bank×State F.E." "State×Time F.E." ///
                     "\$R^2\$" "\$R^2\$ Adjusted" "Y Mean" "Y SD" "Observations")) ///
        prehead("\begin{table}[htbp]\centering\footnotesize" ///
                "\caption{`title'}" ///
                "\label{`tablabel'}" ///
                "\begin{tabular}{l*{6}{c}}" ///
                "\hline\hline") ///
        posthead("\hline") ///
        postfoot("\hline\hline" ///
                 "\multicolumn{7}{l}{\footnotesize Robust standard errors are reported.}\\\\" ///
                 "\multicolumn{7}{l}{\footnotesize \sym{*} \(p<0.1\), \sym{**} \(p<0.05\), \sym{***} \(p<0.01\)}\\\\" ///
                 "\end{tabular}" ///
                 "\end{table>")
end

*******************************************************
* Export Signup Bonuses Table (6 columns)
*******************************************************
export_table_wide6 SB1 SB2 SB3 SB4 SB5 SB6, ///
    dvname(signup_bonuses_total) ///
    outpath("${root}/output/table/bank_time_state_level_dispersion_SB.tex") ///
    title("Bank–Time–State Level Dispersion of Signup Bonuses") ///
    labelname("\$Signup\:Bonuses\$") ///
    tablabel("tab:dispersion_SB_state")

*******************************************************
* Export Unique Individuals Table (6 columns)
*******************************************************
export_table_wide6 U1 U2 U3 U4 U5 U6, ///
    dvname(uniindividual_num) ///
    outpath("${root}/output/table/bank_time_state_level_dispersion_TV.tex") ///
    title("Bank–Time–State Level Dispersion of Unique Individuals") ///
    labelname("\$Unique\:Individuals\$") ///
    tablabel("tab:dispersion_UI_state")
