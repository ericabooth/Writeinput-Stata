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

di as res "ALL TESTS PASSED"
