* test_writeinput.do -- behavioral contract for writeinput
* run from the repo directory: stata-mp -b do test_writeinput.do
* then grep the log for ALL TESTS PASSED
clear all
adopath ++ "`c(pwd)'"
set varabbrev off
set linesize 120

* --- (1) round-trip: string+numeric mix (the v3.0.0 blank-row bug) ----------
sysuse auto, clear
keep in 1/3
keep make price mpg
tempfile orig1
save "`orig1'"
tempfile stub1
loc g1 "`stub1'.do"
writeinput make price mpg using "`g1'", replace
assert r(nobs) == 3
assert r(nvars) == 3
assert "`r(varlist)'" == "make price mpg"
assert r(truncated) == 0
assert "`r(filename)'" == "`g1'"
* data rows must actually contain the data, not blanks
mata: st_local("hit", strofreal(max(strpos(cat("`g1'"), "AMC Concord")) > 0))
assert `hit' == 1
do "`g1'"
assert _N == 3
cf _all using "`orig1'"

* --- (2) round-trip: special characters in string data ----------------------
clear
set obs 5
gen str60 s = ""
replace s = `"embedded "double quotes" here"' in 1
replace s = "apostrophe's, comma, semi; colon:" in 2
replace s = "dollar " + char(36) + "USD and " + char(36) + "{global}" in 3
replace s = "back" + char(96) + "tick and " + char(96) + "local" + char(39) + " ref" in 4
replace s = "unicode: cafe au lait, naive, checkmark" in 5
replace s = "unicode: caf" + char(233) + " " + uchar(10003) in 5
gen int n = _n
tempfile orig2
save "`orig2'"
tempfile stub2
loc g2 "`stub2'.do"
writeinput s n using "`g2'", replace
do "`g2'"
assert _N == 5
cf _all using "`orig2'"
* spot-check the two nastiest values survived verbatim
assert s[3] == "dollar " + char(36) + "USD and " + char(36) + "{global}"
assert s[4] == "back" + char(96) + "tick and " + char(96) + "local" + char(39) + " ref"

* --- (3) round-trip: missing values (regular + extended) --------------------
clear
set obs 4
gen int a = _n
replace a = .  in 1
replace a = .a in 2
replace a = .z in 3
gen double d = 1/7
replace d = .b in 2
gen str8 s = "x"
replace s = "" in 3
tempfile orig3
save "`orig3'"
tempfile stub3
loc g3 "`stub3'.do"
writeinput a d s using "`g3'", replace
do "`g3'"
cf _all using "`orig3'"
assert a[1] == . & a[2] == .a & a[3] == .z & a[4] == 4
assert d[2] == .b & d[1] == 1/7
assert s[3] == ""

* --- (4) numeric precision: float/double exact by default; hex; formats -----
clear
set obs 3
gen float f = _n/3
gen double d = _pi*_n
tempfile orig4
save "`orig4'"
tempfile stub4
loc g4 "`stub4'.do"
writeinput f d using "`g4'", replace
do "`g4'"
cf _all using "`orig4'"
* precision(hex) is bit-exact and runnable
use "`orig4'", clear
tempfile stub4x
loc g4x "`stub4x'.do"
writeinput d using "`g4x'", replace precision(hex)
mata: st_local("hex", strofreal(max(strpos(cat("`g4x'"), "X+")) > 0))
assert `hex' == 1
do "`g4x'"
assert d[1] == _pi & d[2] == 2*_pi & d[3] == 3*_pi
* explicit precision() format is honored
sysuse auto, clear
keep in 1/1
tempfile stub4f
loc g4f "`stub4f'.do"
writeinput price using "`g4f'", replace precision(%12.4f)
mata: st_local("fmt", strofreal(max(strpos(cat("`g4f'"), "4099.0000")) > 0))
assert `fmt' == 1

* --- (5) dryrun prints the block (visible in batch logs) --------------------
sysuse auto, clear
keep in 1/3
tempfile lstub
loc dlog "`lstub'_d.log"
log using "`dlog'", text name(wtest)
writeinput make price mpg, dryrun
log close wtest
mata: t = cat("`dlog'")
mata: st_local("h1", strofreal(max(strpos(t, "input str18 make int price int mpg")) > 0))
mata: st_local("h2", strofreal(max(strpos(t, "AMC Concord")) > 0))
mata: st_local("h3", strofreal(sum(t :== "end")))
assert `h1' == 1 & `h2' == 1 & `h3' >= 1

* --- (6) markdown prints a fenced block (visible in batch logs) -------------
loc mlog "`lstub'_m.log"
log using "`mlog'", text name(wtest)
writeinput make price mpg, markdown
log close wtest
mata: t = cat("`mlog'")
mata: st_local("h1", strofreal(sum(t :== char((96,96,96)) + "stata")))
mata: st_local("h2", strofreal(sum(t :== char((96,96,96)))))
mata: st_local("h3", strofreal(max(strpos(t, "AMC Pacer")) > 0))
assert `h1' == 1 & `h2' == 1 & `h3' == 1

* --- (7) replace overwrites; missing replace/append refuses -----------------
writeinput make price mpg using "`g1'", replace
assert r(nobs) == 3
cap noi writeinput make price mpg using "`g1'"
assert _rc == 198

* --- (8) append stacks a second block ----------------------------------------
tempfile stub8
loc g8 "`stub8'.do"
writeinput make using "`g8'", replace
writeinput make using "`g8'", append
mata: st_local("nin", strofreal(sum(strpos(cat("`g8'"), "input ") :== 1)))
assert `nin' == 2

* --- (9) if/in honored; maxobs truncates and says so ------------------------
sysuse auto, clear
tempfile stub9
loc g9 "`stub9'.do"
writeinput make price if foreign == 1 using "`g9'", replace
assert r(nobs) == 22
writeinput make price using "`g9'", replace maxobs(10)
assert r(truncated) == 1
assert r(nobs) == 10
mata: st_local("trn", strofreal(max(strpos(cat("`g9'"), "** Truncated to 10 observations")) > 0))
assert `trn' == 1
do "`g9'"
assert _N == 10

* --- (10) noclear, header(), and note() land where promised -----------------
sysuse auto, clear
keep in 1/2
tempfile stub10
loc g10 "`stub10'.do"
writeinput make using "`g10'", replace noclear header(** generated by test) note(round-trip contract)
mata: t = cat("`g10'")
mata: st_local("nc", strofreal(sum(t :== "clear")))
mata: st_local("hd", strofreal(max(strpos(t, "** generated by test")) > 0))
mata: st_local("nt", strofreal(max(strpos(t, "** round-trip contract")) > 0))
assert `nc' == 0 & `hd' == 1 & `nt' == 1

* --- (11) varlab writes variable-label comments ------------------------------
lab var make "Make and model"
tempfile stub11
loc g11 "`stub11'.do"
writeinput make using "`g11'", replace varlab
mata: st_local("vl", strofreal(max(strpos(cat("`g11'"), "** var: make  label: Make and model")) > 0))
assert `vl' == 1

* --- (12) error contracts -----------------------------------------------------
cap noi writeinput make
assert _rc == 198
cap noi writeinput make, dryrun precision(banana)
assert _rc == 120
tempfile stub12
cap noi writeinput make if price < 0 using "`stub12'.do", replace
assert _rc == 2000

* --- (13) frame(): parse inside the target frame, restore caller on error ---
* (13a) variables exist only in the target frame
sysuse auto, clear
frame create other
frame other {
    set obs 3
    gen a = _n
    gen b = _n*2
    gen str20 s = "x"
}
writeinput a b, frame(other) dryrun
assert r(nobs) == 3 & r(nvars) == 2 & "`r(varlist)'" == "a b"
assert c(frame) == "default"
assert _N == 74
* if/in/sort() evaluated in the target frame
writeinput a b if b > 2 in 1/3, frame(other) sort(b) dryrun
assert r(nobs) == 2
assert c(frame) == "default"
* round trip from the other frame to a file
tempfile f1
writeinput a b s using "`f1'.do", frame(other) replace
frame create chk
frame chk: do "`f1'.do"
frame chk: assert _N == 3 & a[3] == 3 & b[3] == 6 & s[1] == "x"
frame drop chk
assert c(frame) == "default" & _N == 74
* (13b) error after the frame switch returns the user to the caller's frame
cap writeinput a b using "`c(tmpdir)'/nonexistent_dir_wi/x.do", frame(other) replace
assert _rc == 603
assert c(frame) == "default"
cap writeinput nosuchvar, frame(other) dryrun
assert _rc == 111
assert c(frame) == "default"
cap writeinput a b in 1/0, frame(other) dryrun
assert _rc != 0
assert c(frame) == "default"
* (13c) missing frame
cap writeinput a, frame(nosuch) dryrun
assert _rc == 111
* (13d) frame() naming the current frame works
writeinput price mpg in 1/2, frame(default) dryrun
assert r(nobs) == 2
* (13e) option text with $, backticks, commas, quotes survives the re-parse,
*     with and without frame()
loc nt = "cost " + char(36) + "5, a " + char(96) + "tick" + char(39) + " and " + char(34) + "q" + char(34)
* (never call writeinput behind an if-prefix here: that re-expands the line)
tempfile f2
writeinput price in 1/1 using "`f2'.do", replace note(`macval(nt)') header(** h `macval(nt)')
mata: T = cat("`f2'.do")
mata: st_local("okn", strofreal(anyof(T, "** " + st_local("nt"))))
mata: st_local("okh", strofreal(anyof(T, "** h " + st_local("nt"))))
assert `okn' == 1 & `okh' == 1
tempfile f3
writeinput a in 1/1 using "`f3'.do", replace note(`macval(nt)') header(** h `macval(nt)') frame(other)
mata: T = cat("`f3'.do")
mata: st_local("okn", strofreal(anyof(T, "** " + st_local("nt"))))
mata: st_local("okh", strofreal(anyof(T, "** h " + st_local("nt"))))
assert `okn' == 1 & `okh' == 1
assert c(frame) == "default"
* (13f) using path containing a comma and spaces
loc d "`c(tmpdir)'/wi dir, comma"
mata: st_local("de", strofreal(direxists(st_local("d"))))
if !`de' {
    mkdir "`d'"
}
writeinput a b using "`d'/out file.do", frame(other) replace
confirm file "`d'/out file.do"
erase "`d'/out file.do"
rmdir "`d'"

* --- (14) 3.0.3 regressions ---------------------------------------------------
* (14a) quoted header()/note() lose one layer of quotes; the file runs
sysuse auto, clear
tempfile f14
writeinput make price in 1/2 using "`f14'.do", replace header("** Project X | Date: $S_DATE") note("hello note")
mata: T = cat("`f14'.do")
mata: st_local("h", strofreal(substr(T[1], 1, 12) == "** Project X"))
mata: st_local("n", strofreal(anyof(T, "** hello note")))
assert `h' == 1 & `n' == 1
do "`f14'.do"
assert _N == 2
sysuse auto, clear
writeinput make in 1/1 using "`f14'.do", replace header(`"** compound "q" header"')
mata: st_local("h", strofreal(cat("`f14'.do")[1] == `"** compound "q" header"'))
assert `h' == 1
* (14b) values input cannot hold verbatim round-trip through replace lines
clear
set obs 6
gen str60 s = "ends with tick " + char(96) in 1
replace s = `"he said "hi" "' + char(96) in 2
replace s = "line A" + char(10) + "line B" + char(13) + char(10) + "C" in 3
replace s = "open " + char(96) + char(34) + "nested and close " + char(34) + char(39) + " " + char(36) + "x " + char(92) + char(96) + "y" + char(39) in 4
replace s = "caf" + uchar(233) + " " + char(92) + char(36) + "HOME " + char(96) in 5
replace s = "plain" in 6
gen x = _n
gen str5 t = "z"
tempfile o14 g14
save "`o14'"
writeinput s x t using "`g14'.do", replace
do "`g14'.do"
assert _N == 6
cf _all using "`o14'"
* (14c) labels keeps codes that have no label text
clear
input byte g
1
2
3
.
.a
end
label define gl 1 "one" 2 "two"
label values g gl
tempfile g14c
writeinput g using "`g14c'.do", labels replace
do "`g14c'.do"
assert g[1] == "one" & g[2] == "two" & g[3] == "3" & g[4] == "" & g[5] == ".a"
* (14d) floats round-trip at small and large magnitudes
clear
set obs 4
gen float f = 1.2345678e-10 in 1
replace f = 98765.43 in 2
replace f = 1/3 in 3
replace f = 123456789 in 4
tempfile o14d g14d
save "`o14d'"
writeinput f using "`g14d'.do", replace
do "`g14d'.do"
cf _all using "`o14d'"
* (14e) generic with v# names present, in any order
clear
set obs 2
gen v2 = 1
gen v1 = 2
gen a = 3
writeinput v2 v1, generic dryrun
assert "`r(varlist)'" == "v1 v2"
writeinput a, generic dryrun
assert "`r(varlist)'" == "v1"
confirm variable v2 v1 a
* (14f) nocl abbreviation, negative sample(), .do inside the path
sysuse auto, clear
writeinput price in 1/2, dryrun nocl
cap noi writeinput price in 1/2, sample(-1) dryrun
assert _rc == 198
loc d "`c(tmpdir)'/wi my.docs"
mata: st_local("de", strofreal(direxists(st_local("d"))))
if !`de' {
    mkdir "`d'"
}
writeinput make in 1/2 using "`d'/mwe", replace
confirm file "`d'/mwe.do"
assert "`r(filename)'" == "`d'/mwe.do"
erase "`d'/mwe.do"
rmdir "`d'"

di as res "ALL TESTS PASSED"
