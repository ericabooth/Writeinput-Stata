# writeinput for Stata

**Advanced dataset-to-input command generator for reproducible research and technical support.**

[![Stata Version](https://img.shields.io/badge/Stata-16+-blue.svg)](https://www.stata.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🚀 Overview

`writeinput` is a robust utility designed to convert your current Stata data (or a filtered subset) into a self-contained, reproducible `input` command block. This is the "gold standard" for sharing Minimum Working Examples (MWEs) on forums like [Statalist](https://www.statalist.org), Stack Overflow, or in technical support requests.

Unlike standard data-sharing tools, `writeinput` v3.0.0 is engineered for **bit-for-bit precision** and **structural safety**, ensuring that your example data re-loads exactly as intended across any platform.

---

## ✨ Key Features

- **High Precision:** Support for hexadecimal (`%21x`) output for `double` variables via the `precision(hex)` option—guaranteeing no loss of precision.
- **Extended Missings:** Automatically detects and preserves Stata's extended missing values (`.a` through `.z`).
- **Safe Strings:** Uses compound double quotes (`` `" "' ``) to wrap all string data, making the output immune to internal quotes or backticks.
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
writeinput id year inc, precision(hex) using "support_example.do", replace
```

### 3. Anonymized Random Sample
Create an anonymized, sorted random sample for a public issue report:
```stata
webuse nlswork, clear
writeinput age inc race, sample(20) seed(123) sort(age) generic markdown
```

---

## ⚙️ Options Summary

| Option | Description |
| :--- | :--- |
| `using` | Path to the output `.do` file. |
| `dryrun` | Print output to the results window. |
| `markdown` | Wrap output in a GitHub-flavored code block. |
| `labels` | Decode value labels into strings. |
| `dates` | Format date/time variables as strings. |
| `precision(hex)`| Use hexadecimal format for bit-exact doubles. |
| `maxobs(#)` | Cap the number of rows (default 500). |
| `varlab` | Embed variable labels as comments. |
| `generic` | Anonymize variables as v1, v2, ... |
| `frame(name)` | Pull data from a specific Stata Frame. |

---

## 👤 Author

**Eric A. Booth**
- 🏛️ Sr Researcher, Texas 2036
- 📧 [eric.a.booth@gmail.com](mailto:eric.a.booth@gmail.com)
- 🌐 [www.eric-booth.com](http://www.eric-booth.com)
- 💼 [GitHub Profile](https://github.com/ericabooth)

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
