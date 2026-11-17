These region files are for use by the common go test framework < ADD LINK >

They define the regions that can be selected and a priority for each, to be used by automation to select a region to run a test against.

`icd-gen2-region-prefs.yaml` and `icd-classic-region-prefs.yaml` list the regions for ICD module PR tests, for Gen2 and classic (Gen1) instances respectively. To move tests to a different region, flip `useForTest` or change `testPriority` in the relevant file.
