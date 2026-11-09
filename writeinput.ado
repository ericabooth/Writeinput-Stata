*! writeinput - advanced dataset-to-input command generator
*! Eric A. Booth <eric.a.booth@gmail.com>
*! Version 3.0.3 : Nov 2026
** Version 3.0.3 : Nov 2026 (fix: header()/note() lose their outer quotes; values
**                input cannot hold verbatim (line breaks, a trailing backtick,
**                `" or "' inside) are restored by replace lines; labels keeps
**                unlabeled codes; floats round-trip at any magnitude; generic
**                no longer collides with v# names; noclear abbreviates to
**                nocl; sample() < 0 is refused; no stray 0 on file writes)
** Version 3.0.2 : Nov 2026 (fix: frame() parses varlist/if/in inside the target
**                frame, and the caller's frame is restored on any error)
** Version 3.0.1 : Jul 2026
** Version 3.0.0 : May 2026
** Version 2.0.0 : May 2026
** Version 1.0.1 : Mar 2011

program define writeinput, rclass
    version 16

    *-- Handle Frame.  frame() is pulled out before the full parse, because
    *-- syntax checks varlist, if, in, and sort() against the data in the
    *-- CURRENT frame.  The body is then parsed and run inside the target
    *-- frame through the frame prefix, which restores the caller's frame
    *-- whether the body succeeds or fails.  (No if-prefix one-liners here:
    *-- "if exp command" expands its command a second time, which would eat
    *-- backticks in note()/header() text.)
    _parse comma lhs rhs : 0
    loc 0 `"`macval(rhs)'"'
    syntax [, Frame(name) * ]
    if "`frame'" != "" {
        mata: st_local("fexists", strofreal(st_frameexists(st_local("frame"))))
        if "`fexists'" != "1" {
            di as err "Frame `frame' not found"
            exit 111
        }
        loc opts `", `macval(options)'"'
        frame `frame': _writeinput_body `macval(lhs)' `macval(opts)'
        return add
        exit
    }
    _writeinput_body `macval(lhs)' `macval(rhs)'
    return add
end


program define _writeinput_body, rclass
    version 16
    syntax varlist [if] [in] [using/] [, ///
        Replace noCLear Append ///
        Note(str asis) Header(str asis) ///
        Labels Dates Dryrun Markdown ///
        Precision(str) Maxobs(integer 500) ///
        Sort(varlist) Sample(integer 0) Seed(integer 0) ///
        Varlab Generic ]

    *-- Handle 'using' and 'dryrun'
    if "`using'" == "" & "`dryrun'" == "" & "`markdown'" == "" {
        di as err "must specify 'using filename', 'dryrun', or 'markdown'"
        exit 198
    }

    if `sample' < 0 {
        di as err "sample() must be a positive count"
        exit 198
    }

    if "`using'" != "" {
        *-- add .do only when the name does not already end in .do
        if lower(substr(`"`using'"', -3, .)) != ".do" {
            loc using `"`using'.do"'
        }

        cap confirm file `"`using'"'
        if !_rc & "`replace'" == "" & "`append'" == "" {
            di as err "File `using' exists; specify 'replace' or 'append' option"
            exit 198
        }
    }

    *-- Validate precision() early so Mata never sees a bad format
    if "`precision'" != "" & "`precision'" != "hex" {
        cap loc pchk = string(1, "`precision'")
        if _rc | "`pchk'" == "" {
            di as err "invalid precision() format: `precision'"
            exit 120
        }
    }

    *-- Filter data (novarlist: rows with missing values must be kept,
    *-- else they silently vanish from the serialized dataset)
    marksample touse, strok novarlist

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
        if `maxobs' > 0 & _N > `maxobs' {
            keep in 1/`maxobs'
            loc truncated = 1
        }

        if _N == 0 {
            noi di as err "no observations"
            restore
            exit 2000
        }

        *-- Handle Generic (Anonymize).  Keep only the written variables,
        *-- then rename through temporary names, so existing v# variables
        *-- (in or out of the varlist, in any order) cannot collide.
        if "`generic'" != "" {
            keep `varlist'
            loc k : word count `varlist'
            loc tmpnames ""
            loc new_varlist ""
            forvalues i = 1/`k' {
                tempvar t`i'
                loc tmpnames "`tmpnames' `t`i''"
                loc new_varlist "`new_varlist' v`i'"
            }
            rename (`varlist') (`tmpnames')
            rename (`tmpnames') (`new_varlist')
            loc varlist : list retokenize new_varlist
            if "`varlab'" != "" {
                noi di as txt "(note: varlab writes the real variable labels;" ///
                    " generic renames variables only)"
            }
        }

        *-- Handle Labels option
        if "`labels'" != "" {
            foreach v in `varlist' {
                loc lblname : value label `v'
                if "`lblname'" != "" {
                    *-- values with no label text keep their numeric code
                    *-- (decode alone would turn them into "")
                    tempvar dec
                    decode `v', gen(`dec')
                    replace `dec' = string(`v') if `dec' == "" & `v' != .
                    drop `v'
                    rename `dec' `v'
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

        *-- Input Statement
        loc inp_line "input"
        foreach v in `varlist' {
            loc type : type `v'
            loc inp_line "`inp_line' `type' `v'"
        }

        *-- Emit everything (file and/or screen) in Mata.  Data values,
        *-- header(), and note() text reach the output via st_local()/
        *-- st_sdata(), which the macro processor never re-expands, so
        *-- $, `, and embedded quotes in the data survive verbatim.
        *-- Values that input cannot hold verbatim (a line break, a
        *-- trailing backtick, or a backtick-quote or quote-apostrophe pair)
        *-- are written as "" in the input block and restored by a replace
        *-- line after end, built from char() pieces.
        loc file_mode = cond("`append'" != "", "a", "w")
        noi mata: _writeinput_emit()

        if "`using'" != "" {
            noi di as smcl _n `"Output file written to: {browse `"`using'"'}"'
        }

        *-- Post results
        return local filename "`using'"
        return scalar nobs = _N
        return scalar nvars = `: word count `varlist''
        return local varlist "`varlist'"
        return scalar truncated = `truncated'

        restore
    }
end


version 16
mata:

// write one generated line to the file and/or the screen
void _writeinput_put(real scalar fh, real scalar scrn, string scalar s)
{
    if (fh >= 0) fput(fh, s)
    if (scrn) printf("{txt}%s\n", s)
}

// serialize one numeric value; strofreal() maps ., .a, ... correctly
string scalar _writeinput_num(real scalar x, string scalar type,
    string scalar prec)
{
    string scalar s

    if (prec == "hex") return(strofreal(x, "%21x"))
    if (prec != "")    return(strofreal(x, prec))
    // defaults are round-trip exact: %12.0g covers byte/int/long, doubles
    // need up to 17 significant digits, and a float gets the shortest of
    // %12.0g / 8 / 9 significant digits that reads back to the same float
    if (type == "double") return(strofreal(x, "%21.0g"))
    s = strofreal(x, "%12.0g")
    if (type == "float" & !missing(x)) {
        if (floatround(strtoreal(s)) != x) s = strofreal(x, "%15.8g")
        if (floatround(strtoreal(s)) != x) s = strofreal(x, "%16.9g")
    }
    return(s)
}

// strip one layer of outer quotes ("..." or compound) from option text
string scalar _writeinput_unq(string scalar s)
{
    real scalar L

    L = strlen(s)
    if (L >= 4) {
        if (substr(s, 1, 2) == char(96) + char(34) &
            substr(s, L - 1, 2) == char(34) + char(39)) {
            return(substr(s, 3, L - 4))
        }
    }
    if (L >= 2) {
        if (substr(s, 1, 1) == char(34) & substr(s, L, 1) == char(34)) {
            return(substr(s, 2, L - 2))
        }
    }
    return(s)
}

// 1 if input cannot read s verbatim inside compound double quotes
real scalar _writeinput_unsafe(string scalar s)
{
    if (strpos(s, char(10)) | strpos(s, char(13))) return(1)
    if (strpos(s, char(96) + char(34)))            return(1)
    if (strpos(s, char(34) + char(39)))            return(1)
    if (strlen(s) > 0) {
        if (substr(s, strlen(s), 1) == char(96))    return(1)
    }
    return(0)
}

// a Stata string expression that rebuilds s exactly when the do-file runs:
// quote, macro, escape and line-break bytes become char() calls, and the
// other bytes go in plain double quotes (UTF-8 multibyte text never
// contains these ASCII bytes, so a byte scan is safe)
string scalar _writeinput_expr(string scalar s)
{
    string scalar out, run, c
    real scalar   i, b

    out = ""
    run = ""
    for (i = 1; i <= strlen(s); i++) {
        c = substr(s, i, 1)
        b = ascii(c)
        if (b == 96 | b == 34 | b == 39 | b == 36 | b == 92 |
            b == 10 | b == 13) {
            if (run != "") {
                out = out + (out != "" ? " + " : "") + char(34) + run + char(34)
                run = ""
            }
            out = out + (out != "" ? " + " : "") + "char(" + strofreal(b) + ")"
        }
        else run = run + c
    }
    if (run != "") {
        out = out + (out != "" ? " + " : "") + char(34) + run + char(34)
    }
    if (out == "") out = char(34) + char(34)
    return(out)
}

void _writeinput_emit()
{
    string scalar    fn, dry, md, prec, s, line, cqo, cqc, v
    string rowvector vars
    string colvector fixes
    real rowvector   idx
    real scalar      fh, scrn, i, j, nv, N

    fn   = st_local("using")
    dry  = st_local("dryrun")
    md   = st_local("markdown")
    prec = st_local("precision")
    vars = tokens(st_local("varlist"))
    idx  = st_varindex(vars)
    nv   = cols(vars)
    N    = st_nobs()
    scrn = (dry != "" | md != "")
    cqo  = char(96) + char(34)      // `"
    cqc  = char(34) + char(39)      // "'

    fh = -1
    if (fn != "") {
        if (st_local("file_mode") == "w") (void) _unlink(fn)
        fh = _fopen(fn, st_local("file_mode"))
        if (fh < 0) {
            errprintf("file %s could not be opened\n", fn)
            exit(error(603))
        }
    }

    // screen-only decorations
    if (md != "") _writeinput_put(-1, scrn, "```stata")
    else if (dry != "") {
        printf("{txt}{hline}\n")
        printf("{txt}{title:Generated Input Command}\n")
        if (st_local("truncated") == "1") {
            printf("{res}** Truncated to %s observations **\n",
                st_local("maxobs"))
        }
        printf("{txt}{hline}\n")
    }

    // header block
    s = _writeinput_unq(st_local("header"))
    if (s != "") _writeinput_put(fh, scrn, s)
    if (st_local("clear") != "noclear") _writeinput_put(fh, scrn, "clear")

    // variable labels as comments
    if (st_local("varlab") != "") {
        for (j=1; j<=nv; j++) {
            s = st_varlabel(idx[j])
            if (s != "") {
                _writeinput_put(fh, scrn,
                    "** var: " + vars[j] + "  label: " + s)
            }
        }
    }

    // input statement
    _writeinput_put(fh, scrn, st_local("inp_line"))

    // data rows
    fixes = J(0, 1, "")
    for (i=1; i<=N; i++) {
        line = ""
        for (j=1; j<=nv; j++) {
            if (st_isstrvar(idx[j])) {
                v = st_sdata(i, idx[j])
                if (_writeinput_unsafe(v)) {
                    s = cqo + cqc
                    fixes = fixes \ ("replace " + vars[j] + " = " +
                        _writeinput_expr(v) + " in " + strofreal(i))
                }
                else s = cqo + v + cqc
            }
            else {
                s = _writeinput_num(st_data(i, idx[j]),
                    st_vartype(idx[j]), prec)
            }
            line = line + (j > 1 ? " " : "") + s
        }
        _writeinput_put(fh, scrn, line)
    }

    // footer
    _writeinput_put(fh, scrn, "end")
    for (i=1; i<=rows(fixes); i++) _writeinput_put(fh, scrn, fixes[i])
    s = _writeinput_unq(st_local("note"))
    if (s != "") _writeinput_put(fh, scrn, "** " + s)
    if (st_local("truncated") == "1") {
        _writeinput_put(fh, scrn,
            "** Truncated to " + st_local("maxobs") + " observations")
    }

    if (md != "") _writeinput_put(-1, scrn, "```")
    else if (dry != "") printf("{txt}{hline}\n")

    if (fh >= 0) fclose(fh)
}

end
