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
cal
# try different methods of aggregating start and end by adm1 and adm0
# just use phenology
```

```python
iri.dtypes
```

```python
iri = iri.rename(columns={"asap1": "asap1_id"})
```

```python
# filter iri just to make things faster
# and keep only adm1s for which we have a calendar
iri_f = iri[
    (iri["date"] > "2023-01-01")
    & (iri["threshold"].isin([35, 36]))
    & (iri["asap1_id"].isin(cal["asap1_id"]))
].copy()
```

```python
# filter cal, keep only adm1s for which we have iri
cal_f = cal[cal["asap1_id"].isin(iri_f["asap1_id"])]
```

```python
iri_f["pct_gte_thresh"].hist()
```

```python
# this seems to be the fastest way to add month column
iri_f.loc[:, "relevant_date"] = iri_f["date"] + iri_f[
    "leadtime"
].values.astype("timedelta64[M]")
iri_f["relevant_month"] = iri_f["relevant_date"].dt.month
```

```python
# determine whether in season
cal_iri = cal_f.merge(iri_f, on="asap1_id")

# for _, row in iri_f.iterrows():
#     season_status = ""
#     first_dekad = (row["relevant_month"] - 1) * 3 + 1
#     third_dekad = first_dekad + 2
#     if row["relevant_month"]
#     pass
```

```python
cal_iri
```

```python
iri_f["relevant_month"] = iri_f["relevant_date"].dt.month
```

```python
iri_f
```

```python
print(len(cal[cal["asap1_id"].isin(iri["asap1_id"])]) / len(cal))
```

```python

```
