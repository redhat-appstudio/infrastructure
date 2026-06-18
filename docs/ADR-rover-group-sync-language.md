---
title: "1. Rover Group Sync Coding Language"
status: In-Progress
applies_to:
  - "rover-group-sync"
topics:
  - coding-language
---

# 1. Rover Group Sync Coding Language

Date: 2026-06-15

## Status

under Review

## Context

After several iterations, the Rover Group Sync component was written in bash as it was the quickest way to get the component completed. Since then, several people have spoken up about what coding language the Rover Group Sync component should be written in regards to readability, testing, and maintainability. This ADR aims to conclude whether or not a re-write of Rover Group Sync should be done in another language.

Something else to consider is that (hopefully) this functionality will be available in-cluster in a newer version of OpenShift that allows connecting with more OIDC providers. This version of OpenShift has already been released, but the team has yet to upgrade all Konflux clusters to that version.

## Options

### Option 1: Bash

The coding language remains as is, written in bash, but the script is reorganized into functions to allow for better, more robust testing.

**Pros:**
 - Less time needed for a partial re-write
 - Has direct access to necessary system tools
 - Smaller container image

 **Cons:**
 - Less readable than other languages
 - Has a more difficult-to-use testing system (i.e. BATS) than other languages
 - Error handling is less elegant
 - Has tool/runtime dependencies and thus requires code to check for such tools

### Option 2: Golang

The functionality of Rover Group Sync is re-written using Golang.

**Pros:**
- More readable than bash
- Has several easy-to-use test libraries
- No runtime dependencies (except `oc`)
- Smaller container image

**Cons:**
- More time needed for a full re-write
- Golang's [git package](https://github.com/go-git/go-git/tree/main) is hard to use

### Option 3: Python

The functionality of Rover Group Sync is re-written using Python.

**Pros:**
- More readable than bash
- Has multiple easy-to-use test libraries
- No subprocess calls

**Cons:**
- More time needed for a full re-write
- Larger container image
- Our developers may be less familiar with this language
- Still has runtime dependencies

## Decision

Option 1: Bash with the caveat to reevaluate this decision at the beginning of the 2027 calendar year. This provides time to see if Rover Group Sync's functionality is going to be replaced by connectivity with other OIDCs in a newer OpenShift version.

## Consequences

- A small amount of time will be spent on refactoring/improvement (other areas will receive priority)
- Little to no risk of new deployments
- Testing will continue with BATS
- This decision will be reevaluated at the beginning of 2027
