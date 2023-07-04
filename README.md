# ESSD-EMOS

Emos scripts for ESSD benchmark. Provide the Emos output file (see the method's details below).

This code is provided as supplementary material with:

* Demaeyer, J., Bhend, J., Lerch, S., Primo, C., Van Schaeybroeck, B., Atencia, A., Ben Bouallègue, Z., Chen, J., Dabernig, M., Evans, G., Faganeli Pucer, J., Hooper, B., Horat, N., Jobst, D., Merše, J., Mlakar, P., Möller, A., Mestre, O., Taillardat, M., and Vannitsem, S.: The EUPPBench postprocessing benchmark dataset v1.0, Earth Syst. Sci. Data, 15, 2635–2653, https://doi.org/10.5194/essd-15-2635-2023, 2023.

**Please cite this article if you use (a part of) this code for a publication.**

## Data

First, if you do not have it, get the ESSD benchmark dataset using [the download script](https://github.com/EUPP-benchmark/ESSD-benchmark-datasets). This will fetch the dataset into NetCDF files on your disk.

## Training and producing predictions of the EMOS model

The script `install.r` can be run first to install dependencies used by the model.
Then one must create a temporary folder `fc` to hold the forecast files produced by running the script `EMOS.r`.
Finally, the script `write.netcdf.r` will convert the postprocessed forecasts and write them as a single netCDF file.

## Runtime 

On a virtual machine (32 GB, 16 x 2.3 GHz) not parallelized was < 48 minutes.

Author:Markus Dabernig
