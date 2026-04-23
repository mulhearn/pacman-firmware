pacman-firmware
===============

Firmware for the PACMAN card.

Tools:
------

This repo is currently based on Vivado 2023.2.  The Vivado version is included in each major branch name.

Branches:
---------

zipline-2023.2:
   This is the pristine zipline firmware branch for Vivado 2023.2
   Only the release manager (Mulhearn, currently) will make PRs into this branch.

working-on-3.<X>-zipline-2023:
   A branch of this form is an integration branch aimed at zipline
   version 3.<X> Commits are by pull request (PR) only, rebase only.
   Only fully validated commits, with a cleaned-up and linear commit
   history will be accepted.

There are no other branches supported, currently.  Developers should
work in their own fork of this reposistory, and make PRs only when a
task has been completed and validated.

Usage
-----

See docs/flow.txt for firmware build and development workflows.

