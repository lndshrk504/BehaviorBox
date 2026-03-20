---
name: matlab-change-verification
description: Use this skill when a task changes MATLAB `.m` files, classdef or package code, startup or addpath behavior, MATLAB scripts, or MATLAB tests. Do not use it for Python-only changes or for data-only edits.
---

# MATLAB change verification

## Goal

Make MATLAB edits safer and less guessy.

## Required workflow

1. Identify the exact MATLAB entrypoints touched by the task.
   - name the modified functions, scripts, classes, and test files
   - identify whether the code lives in `+pkg`, `@Class`, `private`, or plain folders

2. Check path and dispatch risks before editing.
   - package resolution
   - class method dispatch
   - `private/` visibility
   - `startup.m`, `pathdef.m`, `addpath`, or project setup logic

3. Prefer `matlab -batch` validation.
   - use the narrowest real test or smoke command first
   - if a full suite is too expensive, run the smallest command that exercises the changed path

4. If no test exists, state that explicitly and propose the smallest defensible smoke check.

5. In the handoff, report:
   - changed MATLAB files
   - validation command(s)
   - what remains unverified
   - any risk around paths, dispatch, or saved-file compatibility

## Do not

- do not rely on static reading alone for behavior changes
- do not add broad path hacks unless the repo already depends on them
- do not expand the task into a refactor unless the user asks
