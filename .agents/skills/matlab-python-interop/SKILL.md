---
name: matlab-python-interop
description: Use this skill when a task crosses the MATLAB and Python boundary, including `py.` calls in MATLAB, `matlab.engine` usage in Python, `.mat` or HDF5 interchange, or debugging mismatched shapes, dtypes, indexing, or serialization between the two runtimes.
---

# MATLAB / Python interop

## Goal

Avoid silent bugs at the language boundary.

## Required workflow

1. Identify the boundary.
   - who produces the data
   - who consumes it
   - whether the boundary is an in-process call, `matlab.engine`, `py.` bridge, `.mat` file, HDF5, JSON, CSV, or another artifact

2. Build a contract table before changing code.
   For every boundary object, list:
   - name
   - owner side (MATLAB or Python)
   - shape
   - dtype / class
   - indexing convention
   - orientation / axis meaning
   - units or normalization assumptions
   - filename or function that carries it

3. Check the classic failure modes explicitly.
   - MATLAB 1-based indexing vs Python 0-based indexing
   - row-major vs column-major assumptions
   - shape squeezing / singleton dimension loss
   - dtype coercion
   - complex values
   - strings / categorical / datetime handling
   - NaN / Inf / missing-value behavior

4. Prefer changing one side of the boundary at a time.
   If both sides must change, state why.

5. In the handoff, report:
   - the contract before and after
   - exact files changed on each side
   - validation commands on both sides
   - remaining incompatibility risk

## Do not

- do not “fix” mismatches by blindly transposing or squeezing arrays without proving the contract
- do not change file schema silently
- do not assume a `.mat` or HDF5 consumer tolerates dtype or field-name drift
