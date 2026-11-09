# writeinput for Stata

**Advanced dataset-to-input command generator for reproducible research and technical support.**

[![Stata Version](https://img.shields.io/badge/Stata-16+-blue.svg)](https://www.stata.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🚀 Overview

`writeinput` is a robust utility designed to convert your current Stata data (or a filtered subset) into a self-contained, reproducible `input` command block. This is the "gold standard" for sharing Minimum Working Examples (MWEs) on forums like [Statalist](https://www.statalist.org), Stack Overflow, or in technical support requests.

Unlike standard data-sharing tools, `writeinput` v3.0.3 is engineered for **bit-for-bit precision** and **structural safety**, ensuring that your example data re-loads exactly as intended across any platform.

---

## ✨ Key Features

- **High Precision:** Numbers round-trip exactly by default; `precision(hex)` writes every numeric variable in hexadecimal (`%21x`) for bit-for-bit output.
- **Extended Missings:** Automatically detects and preserves Stata's extended missing values (`.a` through `.z`).
- **Safe Strings:** Uses compound double quotes (`` `" "' ``) to wrap all string data, so internal quotes, `$`, and backticks survive. The few values `input` cannot read even then (line breaks, a trailing backtick, or a `` `" `` or `"'` pair inside) are restored by a `replace` line after `end`.
- **Workflow Integration:** Full support for Stata **Frames**, `if/in` qualifiers, and random `sample` drawing.
- **Metadata Preservation:** Optionally embed variable labels as comments and decode value labels into the example.
- **Output Targets:** Write to a `.do` file, the results window (`dryrun`), or as a fenced code block for GitHub/Markdown (`markdown`).

---

## 🛠️ Installation

Install from GitHub in Stata:

```stata
net install writeinput, from("https://raw.githubusercontent.com/ericabooth/Writeinput-Stata/main/") replace force
discard
which writeinput
help writeinput
```

The repository ships `writeinput.pkg` and `stata.toc`, so the command and its
help file arrive in one call. To install by hand instead, copy `writeinput.ado`
and `writeinput.sthlp` into your `personal/w/` folder.

---

## 📖 Usage Examples

### 1. The "Statalist Snippet"
Generate a clean, reproducible snippet with value labels and formatted dates directly in your results window:
```stata
sysuse auto, clear
writeinput make mpg price foreign in 1/5, labels dryrun markdown
```

### 2. The "Technical Support" Export
Export high-precision data with extended missings to a shared `.do` file:
```stata
* Assume 'inc' has extended missing values
writeinput id year inc using "support_example.do", precision(hex) replace
```

### 3. Anonymized Random Sample
Create an anonymized, sorted random sample for a public issue report:
```stata
webuse nlswork, clear
writeinput age ln_wage race, sample(20) seed(123) sort(age) generic markdown
```

---

## ⚙️ Options Summary

| Option | Description |
| :--- | :--- |
| `using` | Path to the output `.do` file (`.do` is added if missing). Goes before the comma. |
| `replace` | Overwrite an existing file. |
| `append` | Add to the end of an existing file. Each block keeps its own `clear` line unless `noclear` is given. |
| `noclear` | Leave out the `clear` line before `input` (abbreviation `nocl`). |
| `dryrun` | Print output to the results window. |
| `markdown` | Wrap output in a GitHub-flavored code block. |
| `header(text)` | First line of the generated code; start it with `*` to make it a comment. Outer quotes are removed. |
| `note(text)` | A `**` comment written after `end`. Outer quotes are removed. |
| `labels` | Decode value labels into strings; values without a label keep their code. |
| `dates` | Format date/time variables as strings. |
| `precision(hex)` or `precision(%fmt)` | Hexadecimal (`%21x`) for every numeric variable, or a numeric format of your choice. |
| `maxobs(#)` | Cap the number of rows (default 500; 0 removes the cap). |
| `sort(varlist)` | Sort the rows before writing. |
| `sample(#)` / `seed(#)` | Write a reproducible random subset of # rows. |
| `varlab` | Embed variable labels as comments. |
| `generic` | Anonymize variables as v1, v2, ... (with `varlab`, the real labels are still written). |
| `frame(name)` | Pull data from another Stata frame. The varlist, `if`, `in`, and `sort()` refer to that frame, and you stay in your current frame, even if the command fails. |

---

## 📝 Changes

- **3.0.3 (Nov 2026):** Quoted `header()` and `note()` text, as in the help's own example, is written without its outer quotes, so the generated do-file runs. String values with a line break, a trailing backtick, or a `` `" `` or `"'` pair inside are now restored exactly by `replace` lines instead of breaking the `input` block. `labels` keeps numeric codes that have no label text (they used to become empty). Floats round-trip at very small and very large magnitudes. `generic` no longer fails when the data already hold v1, v2, ... variables. `noclear` accepts the documented `nocl` abbreviation, `sample()` refuses negative counts, a `.do` elsewhere in the path no longer stops the extension being added, the stray `0` printed on every file write is gone, and the file link works for paths with spaces. README and help examples now run as written.
- **3.0.2 (Nov 2026):** `frame(name)` now works when the variables exist only in the named frame (earlier versions checked the varlist against the current frame and stopped with "variable not found"). An error inside the named frame no longer leaves you switched into it.

---

## 👤 Author

**Eric A. Booth**
- 🏛️ Sr Researcher, Texas 2036
- 📧 [eric.a.booth@gmail.com](mailto:eric.a.booth@gmail.com)
- 🌐 [www.eric-booth.com](http://www.eric-booth.com)
- 💼 [GitHub Profile](https://github.com/ericabooth)

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
