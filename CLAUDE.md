# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Run-directory setup scripts and model-vs-observation IDL plotting code for GEOS-Chem Classic 1-year benchmarks, run on the Harvard Cannon cluster (SLURM). There is no build system, linter, or test suite; nothing here is run from inside the repository. The step-by-step operator procedures live in `FullChem/README.md`, `TransportTracers/README.md`, and `FullChem/IDL/README.md`; keep those in sync when changing script behavior. `FullChem/template_files/README` is a short 2017 summary of the FullChem setup steps; keep its variable names in sync too. The benchmark plots and tables themselves are produced by GCPy (`gcpy/benchmark/config/1yr_*_benchmark.yml` + `benchmark_slurm.sh`), not by this repo.

## Two parallel benchmark flavors

`FullChem/template_files/` and `TransportTracers/template_files/` each have their own copies of `setup_*`, `make_runscripts`, `run.template`, `job_depend.pl`, `pack_*`, and `copy_*`. They are near-duplicates that differ in run cadence, so a fix to one usually needs to be applied to the other (e.g. `diff FullChem/template_files/run.template TransportTracers/template_files/run.template`):

| | FullChem | TransportTracers |
|---|---|---|
| Setup script | `setup_1yr_run` | `setup_1yr_transport_bm` |
| Run stages | 18 monthly runs, 2018-07 → 2019-12 (first 12 months are spin-up) | 11 yearly runs, 2009 → 2019 (10 years of spin-up) |
| `make_runscripts` args | `VERSION START-YEAR START-MONTH [NRUNS]` (default 24) | `VERSION START-YEAR [NRUNS]` (default 11) |
| Script name suffix | `.YYYYMM` | `.YYYY` |
| Version string | `GCC_X.Y.Z-rc.N` | `GCC_X.Y.Z-rc.N-TransportTracers` |

`FullChem/template_files/setup_10yr_run` is a 10-year FullChem variant (`make_runscripts VERSION 2018 1 120`, reusing the 1-yr `pack_*`/`copy_*` and GCPy config). Because the shared `job_depend.pl` lists only the 18 one-year stages, `setup_10yr_run` rewrites its `@jobs` list with `perl` from the 120 generated run scripts. Never run `job_depend.pl` to test it: it calls `sbatch` for real.

## How the run-directory pipeline fits together

1. The operator creates a MERRA-2 4x5 run directory with GCClassic's `createRunDir.sh`, copies the `setup_*` script into it, and edits `BM_VERSION`, `GCPY_ROOT`, and `THIS_REPO_ROOT` (default `$HOME/GC/benchmarks/1yr`, i.e. a clone of this repo).
2. `setup_*` runs inside the run directory. It creates `Config/`, `Logs/`, `RunScripts/`, `BenchmarkResults/`; moves `geoschem_config.yml` to `Config/geoschem_config.yml.template` with the hard-coded default dates (`20190701`/`20190801` FullChem, `20190101`/`20190201` TT) replaced by `{DATE1}`/`{DATE2}`; changes `EFYO` → `CYS` in `HEMCO_Config.rc` so a restart from a different year is accepted; edits `HISTORY.rc` with `sed` (FullChem uncomments extra collections, TT switches `'End'` to monthly output); copies `run.template`, `make_runscripts`, `job_depend.pl` from `$THIS_REPO_ROOT` into `RunScripts/`; copies `pack_*`/`copy_*` and the GCPy config + `benchmark_slurm.sh` into place.
3. `make_runscripts` stamps out one SLURM script per stage from `run.template` by substituting `{CDATE}`, `{VERSTR}`, `{STYEAR}`, `{STMONTH}`, `{RUNSTR}`. At run time each script `cd ..`s into the run directory, sources `runScriptSamples/operational_examples/harvard_cannon/gcclassic.gcc12_cannon_rocky.env` (change it in both `run.template` files when the compiler or OS image changes), fills `{DATE1}`/`{DATE2}`/`{VERSION}` (FullChem also `{TIME1}`/`{TIME2}`) in the yml template, and runs `./gcclassic`. The stage with `RUN == 01` also compiles GEOS-Chem (`cmake ../CodeDir -DRUNDIR=..`); extra CMake options go there.
4. `job_depend.pl` submits the stages chained with `sbatch --dependency=afterok`. Its `@jobs` list is **hard-coded** and only the version placeholder is `sed`-replaced by `setup_*`, so changing `START_YR`/`START_MON`/`N_MONTHS`/`N_YEARS` also requires editing that list.
5. After GCPy plotting, `pack_*` tars `Logs`, `OutputDir`, `Restarts`, `Config`, `RunScripts` (the `rm` lines are intentionally commented out; it leaves a copy of `species_database.yml` in the run dir), and `copy_* PATH` copies the tarballs, `BenchmarkResults/`, and `README.md` to gcgrid with `jacob_gcst` group permissions.

Because the setup script copies files out of `$THIS_REPO_ROOT`, edits made in this repo only affect run directories set up afterwards; an existing run directory uses its own copies in `RunScripts/`.

TransportTracers specifics: `PassiveTracer` must be a uniform 1e-7 mol/mol in the restart file before the final (2019) stage. Use the `ncap2` commands in `TransportTracers/README.md` or `TransportTracers/template_files/reset_passivetracer_to_100ppb.py` (needs a GCPy conda env; file names are edited in `main()`). `setup_1yr_transport_bm` copies it into the run directory.

## IDL model-vs-observation plots (`FullChem/IDL`)

- Driver is `benchmark_1yr.pro`; it pulls in every routine in `subroutines/` with `@ ./subroutines/...` includes, so IDL must be started from `FullChem/IDL/`. It depends on the GAMAP and TOOLS IDL packages.
- Each benchmark adds an input file `input/GC_X.Y.Z-rc.N.1yr` (template: `input/input.1yr`) with `V/D/L/M/R/Y` keys for Ref (1) and Dev (2).
- Run per category, e.g. `IDL> benchmark_1yr, 'input/GC_X.Y.Z-rc.N.1yr', /DO_Ox` (also `/DO_CO`, `/DO_MOZAIC`, `/DO_AIRCRAFT`, `/DO_PAN`, `/DO_AEROSOL`, `/DO_BrO`). PDF output is always on. Run on the Cannon login node, since a SLURM bug blocks the needed X11 windows in interactive sessions.
- Output goes to `output/`; `output/move_output.sh /path/to/results` moves the PDFs into `ModelVsObs/`.
- `data/` holds the observational datasets (sondes, CMDL, MOZAIC, PAN, BrO, PM2.5, etc.) and should be treated as read-only reference data.

`TransportTracers/IDL/` (including `obsolete/`) is legacy and probably no longer used.
