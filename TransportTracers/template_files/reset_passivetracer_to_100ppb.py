#!/usr/bin/env python
"""
Resets the PassiveTracer species field in a GEOS-Chem Classic or GCHP
restart file to a spatially uniform value of 100 ppb.

PassiveTracer (used in the TransportTracers simulation) is meant to
stay at a uniform 100 ppb everywhere, but repeated restarts (and the
mass-conservation pressure scaling applied on restart) can introduce
non-uniformity over time (see
https://github.com/geoschem/GCHP/issues/552). This script resets it
back to the expected uniform value.

Examples
--------

1. Copy this file to a different folder and navigate to that folder.
2. In your copy, edit file names for your use case.
3. Run the following commands:

.. code-block:: console

   $ conda activate gcpy_env
   (gcpy_env) $ ./reset_passivetracer_to_100ppb.py
"""

# Imports
import xarray as xr
from gcpy.constants import SKIP_THESE_VARS

# PassiveTracer's variable name differs between GEOS-Chem Classic
# ("SpeciesRst_PassiveTracer") and GCHP ("SPC_PassiveTracer")
PASSIVETRACER_VARNAMES = ["SpeciesRst_PassiveTracer", "SPC_PassiveTracer"]

# 100 ppb, expressed in the restart file's native units (mol/mol dry air)
PASSIVETRACER_VALUE_VV = 1.0e-7


def reset_passivetracer_to_100ppb(
        infile,
        outfile
):
    """
    Resets the PassiveTracer species field in a GEOS-Chem Classic or
    GCHP restart file to a spatially uniform value of 100 ppb.

    Parameters
    ----------
    infile : str
        Name of the input restart file (GEOS-Chem Classic or GCHP).
        This file will not be modified.
    outfile : str
        Name of the output restart file, with PassiveTracer reset to
        a uniform 100 ppb.
    """
    with xr.set_options(keep_attrs=True):

        dset = xr.open_dataset(infile, drop_variables=SKIP_THESE_VARS)

        varname = next(
            (v for v in PASSIVETRACER_VARNAMES if v in dset.data_vars),
            None
        )
        if varname is None:
            raise ValueError(
                f"Could not find a PassiveTracer variable in {infile} "
                f"(looked for {PASSIVETRACER_VARNAMES})."
            )

        dset[varname].values[:] = PASSIVETRACER_VALUE_VV

        dset.to_netcdf(outfile)

        print(
            f"Reset {varname} to a uniform 100 ppb "
            f"({PASSIVETRACER_VALUE_VV} mol/mol dry) in {outfile}"
        )


def main():
    """
    Main program.  Edit input/output file names and paths as needed.
    """
    # GEOS-Chem Classic example
    reset_passivetracer_to_100ppb(
        "GEOSChem.Restart.TransportTracers.20190101_0000z.nc4",
        "new.GEOSChem.Restart.TransportTracers.20190101_0000z.nc4",
    )

    # GCHP example
    reset_passivetracer_to_100ppb(
        "GCHP.Restart.TransportTracers.20190101_0000z.c180.nc4",
        "new.GCHP.Restart.TransportTracers.20190101_0000z.c180.nc4",
    )


# Only execute when we run as a standalone script
if __name__ == "__main__":
    main()
