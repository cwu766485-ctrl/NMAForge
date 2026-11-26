# NMAForge Python environment

NMAForge Python scripts and Makefile targets default to **Python 3.12**.
`.python-version` selects 3.12 for pyenv users; Makefiles use `python3.12`
unless `PYTHON` is explicitly overridden. The Linux smoke launcher prefers
3.12 and supports 3.8 or newer when run on another machine. It no longer falls
back to an older system `python3` such as Python 3.6.

Create an isolated environment and install the checked-in dependencies with:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements-python312.txt
```

The dependency set covers the repository's model-generation scripts
(`numpy`, `scikit-learn`, `onnx`) and common Python validation tools
(`pytest`, `PyYAML`, `jsonschema`). Core RTL simulation still requires the
separately installed VCS/EDA tools and their licensed setup.

For a user-shell default, put the chosen Python 3.12 environment's `bin`
directory before `/usr/bin` on `PATH`. Keep the distribution-managed
`/usr/bin/python3` unchanged; system utilities may depend on it.
