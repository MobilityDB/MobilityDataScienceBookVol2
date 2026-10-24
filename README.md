## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

This is the companion repository of the book "Mobility Data Science: From Edge to Cloud Processing" published by Springer in 2026. It contains the datasets used in the book alongside with the scripts allowing you to input these datasets in PostgreSQL and reproduce the examples and exercises in the book. [FIGURES.md](FIGURES.md) lists each figure of the book with the scripts of this repository that draw it, and `check_figures.py` checks, against the LaTeX sources of the book, that every figure the book includes is listed there with a script of this repository.

`tools/book_env/setup.sh` builds, under `BOOK_ENV` (default: `/mnt/bookdb/env`), the software that the chapters use: a Python 3.12 venv with the packages that the READMEs of the chapters install, a second one with those of chapter 9 (PyFlink 2.1.0 needs a pyarrow older than the one of the other chapters), the Chromium of Playwright, and the chain of chapter 9, which builds `libmeos.so` and MobilityFlink and the walk of the chapter. It may be run again at any time, and `. tools/book_env/env.sh` sets up a shell to use it.

This repository is still IN CONSTRUCTION and we will improved it little by little. We welcome the contributions from the community to make this repository better.
