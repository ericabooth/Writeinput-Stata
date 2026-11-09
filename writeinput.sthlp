{smcl}
{* version 3.0.3 09nov2026}{...}
{hline}
help for {hi:writeinput}
{hline}

{title:Advanced dataset-to-input command generator}

{p 4 8 2} 
{cmd:writeinput}
{it:varlist} 
[{cmd:if} {it:exp}] 
[{cmd:in} {it:range}] 
[{cmd:using} {it:newfile}]
[{cmd:,} 
{cmdab:rep:lace} 
{cmd:append}
{cmdab:nocl:ear} 
{cmdab:n:ote(}{it:string}{cmd:)}
{cmdab:h:eader(}{it:string}{cmd:)}
{cmd:labels}
{cmd:dates}
{cmd:dryrun}
{cmd:markdown}
{cmd:precision(}{it:str}{cmd:)}
{cmd:maxobs(}{it:#}{cmd:)}
{cmd:sort(}{it:varlist}{cmd:)}
{cmd:sample(}{it:#}{cmd:)}
{cmd:seed(}{it:#}{cmd:)}
{cmd:varlab}
{cmd:generic}
{cmd:frame(}{it:name}{cmd:)}]

{title:Description}

{p 4 4 2}
{cmd:writeinput} (v3.0.3) is a robust utility for generating reproducible Stata
{help input} code from data currently in memory. It is specifically designed to 
facilitate sharing "Minimum Working Examples" (MWEs) on forums like Statalist 
or technical support emails.

{p 4 4 2}
Compared to version 1.x and 2.x, this version adds significant intelligence 
regarding data precision (hexadecimal support), extended missing values (.a-.z), 
and modern Stata 16+ features like {help frames}.

{title:Output Options}

{p 4 8 2}
{cmd:using} {it:newfile} writes the generated code to a do-file. If {it:newfile}
does not end in {cmd:.do}, {cmd:.do} is added. At least one of {cmd:using},
{cmd:dryrun}, or {cmd:markdown} is required. {p_end}

{p 4 8 2}
{cmd:replace} overwrites an existing {it:newfile}. {p_end}

{p 4 8 2}
{cmd:append} adds the generated code to the end of an existing file. Each
appended block starts with its own {cmd:clear} line (unless {cmd:noclear} is
given), so running the whole file leaves the last block's data in memory. {p_end}

{p 4 8 2}
{cmd:dryrun} prints the generated code in the Results window. {p_end}

{p 4 8 2}
{cmd:markdown} prints the code in the Results window inside a fenced code block
marked {cmd:stata}, ready for pasting into GitHub or Stack Overflow. {p_end}

{p 4 8 2}
{cmd:noclear} leaves out the {cmd:clear} line that normally precedes {cmd:input}. {p_end}

{p 4 8 2}
{cmd:header(}{it:string}{cmd:)} writes {it:string} as the first line of the
generated code. Start it with {cmd:*} or {cmd://} to make it a comment. One
layer of outer quotes is removed, so {cmd:header("** Project X")} and
{cmd:header(** Project X)} write the same line. {p_end}

{p 4 8 2}
{cmd:note(}{it:string}{cmd:)} writes {it:string} as a {cmd:**} comment after
{cmd:end}. One layer of outer quotes is removed. {p_end}

{title:Robustness & Correctness Options}

{p 4 8 2}
{cmd:precision(}{it:str}{cmd:)} controls numeric precision. {cmd:precision(hex)}
writes every numeric variable in hexadecimal format ({cmd:%21x}), which is
bit-for-bit exact when the data are read back. You can also pass a standard
numeric format such as {cmd:precision(%20.0g)}. Without {cmd:precision()},
values are still written exactly: doubles with up to 17 significant digits and
floats with the fewest digits (up to 9) that read back to the same value. {p_end}

{p 4 8 2}
{it:Extended Missings}: The command automatically detects and preserves 
extended missing values (.a, .b, ..., .z). {p_end}

{p 4 8 2}
{it:String Escaping}: All string values are wrapped in
compound double quotes ({cmd:`"}...{cmd:"'}), so internal double quotes,
apostrophes, dollar signs, and backticks are written verbatim. A few values
cannot be read by {cmd:input} even inside compound quotes: values that contain
a line break, end in a backtick, or contain a backtick followed by a double
quote or a double quote followed by an apostrophe. Such a value is written as
an empty string in the {cmd:input} block and restored by a {cmd:replace} line
after {cmd:end}, so the data still round-trip exactly. {p_end}

{p 4 8 2}
{cmd:labels} writes value-labeled numeric variables as their label text.
Values that have no label text keep their numeric code (as a string). {p_end}

{p 4 8 2}
{cmd:dates} writes variables with a date or time format as strings in that
format. {p_end}

{title:Feature Options}

{p 4 8 2}
{cmd:maxobs(}{it:#}{cmd:)} caps the number of rows written (default 500). 
Set to 0 to disable the limit. This prevents accidental massive file creation. {p_end}

{p 4 8 2}
{cmd:varlab} embeds variable labels as comments directly above the {cmd:input} line.
With {cmd:generic}, the comments still show the real labels. {p_end}

{p 4 8 2}
{cmd:sort(}{it:varlist}{cmd:)} sorts the observations by the specified variables 
before writing, ensuring a consistent and logical order. {p_end}

{p 4 8 2}
{cmd:sample(}{it:#}{cmd:)} and {cmd:seed(}{it:#}{cmd:)} allow you to write a 
randomly drawn, reproducible subset of {it:#} observations. {it:#} must not be
negative; 0 (the default) writes every observation. {p_end}

{p 4 8 2}
{cmd:generic} renames all output variables to v1, v2, ... to anonymize the 
data structure while preserving the underlying logic. {p_end}

{p 4 8 2}
{cmd:markdown} wraps the results window output in a fenced code block with 
Stata syntax highlighting, ready for pasting into GitHub or Stack Overflow. {p_end}

{p 4 8 2}
{cmd:frame(}{it:name}{cmd:)} allows you to pull data from a specific Stata 16+ 
frame without leaving your current workspace. The {it:varlist}, {cmd:if}, {cmd:in}, 
and {cmd:sort()} all refer to the variables in frame {it:name}, which need not exist 
in the current frame. You remain in your current frame afterward, even if 
{cmd:writeinput} stops with an error. {p_end}

{title:Examples}

{p 4 4 2}High-precision export for technical support:{p_end}
{p 8 12 2}{cmd:. sysuse auto, clear}{p_end}
{p 8 12 2}{cmd:. writeinput mpg price weight in 1/5, precision(hex) dryrun}{p_end}

{p 4 4 2}Create an anonymized, sorted random sample for a forum post:{p_end}
{p 8 12 2}{cmd:. webuse nlswork, clear}{p_end}
{p 8 12 2}{cmd:. writeinput age ln_wage race, sample(20) seed(123) sort(age) generic markdown}{p_end}

{p 4 4 2}Include variable metadata and a project header:{p_end}
{p 8 12 2}{cmd:. sysuse auto, clear}{p_end}
{p 8 12 2}{cmd:. writeinput make price mpg in 1/5 using mwe.do, varlab header("** Project X | Date: $S_DATE") replace}{p_end}

{title:Returned Values}

{p 4 8 2}The command returns the following in {cmd:r()}: {p_end}
{synoptset 15 tabbed}{...}
{synopt:{cmd:r(filename)}}The path to the created file{p_end}
{synopt:{cmd:r(nobs)}}Number of observations written{p_end}
{synopt:{cmd:r(nvars)}}Number of variables written{p_end}
{synopt:{cmd:r(varlist)}}The list of variables written{p_end}
{synopt:{cmd:r(truncated)}}1 if maxobs was reached, 0 otherwise{p_end}

{title:Author}

{p 4 4 2}Eric A. Booth{break} 
         eric.a.booth@gmail.com{break}
         {browse "http://www.eric-booth.com"}

{title:Also see}

{p 4 8 2}On-line:  help for {help input}, {help dataex}, {help frames}
