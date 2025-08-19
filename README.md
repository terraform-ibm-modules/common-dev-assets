# common-dev-assets
![This repository contains code and assets that are used to support parts of terraform-ibm-modules development processes. It is not specifically designed to be consumed outside the terraform-ibm-modules project - although it may be source of inspiration](https://img.shields.io/badge/-Internal%20to%20terraform%20ibm%20modules%20Project-lightgrey "This repository contains code and assets that are used to support parts of terraform-ibm-modules development processes. It is not specifically designed to be consumed outside the terraform-ibm-modules project - although it may be source of inspiration") [![Build Status](https://github.com/terraform-ibm-modules/common-dev-assets/actions/workflows/ci.yml/badge.svg)](https://github.com/terraform-ibm-modules/common-dev-assets/actions/workflows/ci.yml)

Repo containing common CI assets.

## Local Development Setup
Follow the below steps to get set up with your local development environment in order to contribute to this repo..

### Prereqs
This repo uses multiple pre-commit hooks, however before hooks can run, you need to have the pre-commit package manager
installed. See the following [installation steps](https://pre-commit.com/#install).

### Install dev dependencies:
To set up all necessary tools (including pre-commit hooks), from the root directory of this repo, run the following
command:
```bash
make
```

# Note on typos pre-commit hook

## Overview
This repository uses **typos** to automatically check for common spelling mistakes in code and documentation files.

## What Files Are Checked
- **Terraform files** (`.tf`)
- **Python files** (`.py`)
- **Shell files** (`.sh`)
- **Go files** (`.go`)
- **Markdown files** (`.md`)
- **JSON files** (`.json`)
- **YAML/YML files** (`.yaml/.yml`)

## What Files Are Ignored
- Images (`.svg`), PDFs (`.pdf`)
- Go module files (`go.sum`, `go.mod`)
- Makefiles
- Files in `common-dev-assets/` directory
- Git metadata files

## Handling False Positives

If typos flags a word that should be ignored (technical terms, DA specific, etc.), add it to file:

```
ci/.typos.toml
```
