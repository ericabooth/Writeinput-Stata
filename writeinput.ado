*! writeinput - advanced dataset-to-input command generator
*! Eric A. Booth <eric.a.booth@gmail.com>
*! Version 3.0.0 : May 2026
** Version 2.0.0 : May 2026
** Version 1.0.1 : Mar 2011

program define writeinput, rclass
    version 16
    syntax varlist [if] [in] [using/] [, ///
        Replace noCLEAR Append ///
        Note(str asis) Header(str asis) ///
        Labels Dates Dryrun Markdown ///
        Precision(str) Maxobs(integer 500) ///
        Sort(varlist) Sample(integer 0) Seed(integer 0) ///
        Varlab Generic Frame(name) ]

    *-- Handle Frame
    if "`frame'" != "" {
        loc original_frame "`c(frame)'"
        cap frame change `frame'
        if _rc {
            di as err "Frame `frame' not found"
            exit 111
        }
    }

    *-- Handle 'using' and 'dryrun'
    if "`using'" == "" & "`dryrun'" == "" & "`markdown'" == "" {
        di as err "must specify 'using filename', 'dryrun', or 'markdown'"
        exit 198
    }

    if "`using'" != "" {
        loc check : subinstr local using ".do" "", count(loc howmany)
        if "`howmany'" == "0" loc using "`using'.do"
        
        cap confirm file `"`using'"'
        if !_rc & "`replace'" == "" & "`append'" == "" {
            di as err "File `using' exists; specify 'replace' or 'append' option"
            exit 198
        }
    }

    *-- Filter data
    marksample touse
    
    qui {
        preserve
        keep if `touse'
        
        *-- Handle Sample/Seed
        if `sample' > 0 {
            if `seed' > 0 set seed `seed'
            sample `sample', count
        }

        *-- Handle Sort
        if "`sort'" != "" sort `sort'

        *-- Handle Maxobs
        loc truncated = 0
        if `maxobs' > 0 & `_N' > `maxobs' {
            keep in 1/`maxobs'
            loc truncated = 1
        }

        if `_N' == 0 {
            di as err "no observations"
            restore
            if "`original_frame'" != "" frame change `original_frame'
            exit 2000
        }

        *-- Handle Generic (Anonymize)
        if "`generic'" != "" {
            loc i = 1
            foreach v in `varlist' {
                rename `v' v`i'
                loc new_varlist "`new_varlist' v`i'"
                loc ++i
            }
            loc varlist "`new_varlist'"
        }

        *-- Handle Labels option
        if "`labels'" != "" {
            foreach v in `varlist' {
                loc lblname : value label `v'
                if "`lblname'" != "" {
                    decode `v', gen(`v'_lab)
                    drop `v'
                    rename `v'_lab `v'
                }
            }
        }

        *-- Handle Dates option
        if "`dates'" != "" {
            foreach v in `varlist' {
                loc fmt : format `v'
                if strpos("`fmt'", "t") | strpos("`fmt'", "d") {
                    tempvar `v'_str
                    gen str ``v'_str' = string(`v', "`fmt'")
                    drop `v'
                    rename ``v'_str' `v'
                }
            }
        }

        *-- Prepare file handling
        tempname mh
        if "`using'" != "" {
            loc file_mode = cond("`append'" != "", "append", "write")
            file open `mh' using "`using'", `file_mode' text
        }

        *-- Helper program to write to both file and screen
        *-- Added markdown wrapping support
        program define _sv_write
            args fh line dryrun markdown
            if "`fh'" != "" file write `fh' `"`line'"' _n
            if "`dryrun'" != "" | "`markdown'" != "" di as txt `"`line'"'
        end

        if "`markdown'" != "" di as txt "```stata"
        if "`dryrun'" != "" | "`markdown'" != "" {
            di as txt "{hline}" 
            di as txt "{title:Generated Input Command}" 
            if `truncated' di as res "** Truncated to `maxobs' observations **"
            di as txt "{hline}"
        }

        *-- Header Block
        if `"`header'"' != "" _sv_write `mh' `"`header'"' "`dryrun'" "`markdown'"
        if "`clear'" != "noclear" _sv_write `mh' "clear" "`dryrun'" "`markdown'"
        
        *-- Variable Labels as comments
        if "`varlab'" != "" {
            foreach v in `varlist' {
                loc vl : var label `v'
                if `"`vl'"' != "" _sv_write `mh' `"** var: `v'  label: `vl'"' "`dryrun'" "`markdown'"
            }
        }

        *-- Input Statement
        loc inp_line "input "
        foreach v in `varlist' {
            loc type : type `v'
            if substr("`type'", 1, 3) == "str" {
                loc inp_line "`inp_line' `type' `v'"
            }
            else {
                * Precision control: use double for double, or hex if requested
                if "`type'" == "double" & "`precision'" == "hex" {
                    loc inp_line "`inp_line' double `v'"
                }
                else loc inp_line "`inp_line' `type' `v'"
            }
        }
        _sv_write `mh' "`inp_line'" "`dryrun'" "`markdown'"

        *-- Data Rows
        forval n = 1/`=_N' {
            loc row ""
            foreach v in `varlist' {
                loc val = `v'[`n']
                cap confirm string variable `v'
                if !_rc {
                    * Precision: String escaping with compound double quotes
                    loc row `"`row' `"`val'"'"'
                }
                else {
                    * Precision: Extended missing values (.a, .b, ...)
                    loc sval = string(`val')
                    * Precision: Hex for doubles if requested
                    if "`: type `v''" == "double" & "`precision'" == "hex" {
                        loc sval = string(`val', "%21x")
                    }
                    else if "`precision'" != "" {
                        loc sval = string(`val', "`precision'")
                    }
                    loc row "`row' `sval'"
                }
            }
            _sv_write `mh' "`row'" "`dryrun'" "`markdown'"
        }

        *-- Footer
        _sv_write `mh' "end" "`dryrun'" "`markdown'"
        if `"`note'"' != "" _sv_write `mh' `"** `note'"' "`dryrun'" "`markdown'"
        if `truncated' _sv_write `mh' "** Truncated to `maxobs' observations" "`dryrun'" "`markdown'"

        if "`dryrun'" != "" | "`markdown'" != "" {
            di as txt "{hline}"
        }
        if "`markdown'" != "" di as txt "```"

        if "`using'" != "" {
            file close `mh'
            di as smcl _n "Output file written to: {browse `using'}"
        }
        
        *-- Post results
        return local filename "`using'"
        return scalar nobs = `_N'
        return scalar nvars = `: word count `varlist''
        return local varlist "`varlist'"
        return scalar truncated = `truncated'

        restore
        if "`original_frame'" != "" frame change `original_frame'
    }
end
