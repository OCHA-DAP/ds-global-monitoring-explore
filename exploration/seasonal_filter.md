---
jupyter:
  jupytext:
    formats: ipynb,md
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.15.2
  kernelspec:
    display_name: ds-global-monitoring-explore
    language: python
    name: ds-global-monitoring-explore
---

# Filtering by seasonal calendar

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import pandas as pd

from src import utils
```

```python
# load data
# note: loading IRI is a bit slow because it has 21M rows
# and there is some minor processing
iri = utils.load_lhz_adm1_crop_pct_thresh()
cal = utils.load_asap_seasonal()
```

```python
iri.dtypes
```

```python
iri_f = iri_f.rename(columns={"asap1": "asap1_id"})
```

```python
# filter just to make things faster
iri_f = iri[
    (iri["date"] > "2023-01-01") & (iri["threshold"].isin([35, 36]))
].copy()
```

```python
# this seems to be the fastest way to add month column
iri_f.loc[:, "relevant_date"] = iri_f["date"] + iri_f[
    "leadtime"
].values.astype("timedelta64[M]")
```

```python
# determine whether in season
print("Fraction of adm1s with a seasonal calendar:")
print(len(iri_f[iri_f["asap1_id"].isin(cal["asap1_id"])]) / len(iri_f))

cal[cal["sos_e"] > cal["eos_e"]]
```

```python
iri_f
```

```python

```
