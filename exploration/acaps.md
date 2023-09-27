---
jupyter:
  jupytext:
    formats: ipynb,md
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.6
  kernelspec:
    display_name: ds-global-monitoring-explore
    language: python
    name: ds-global-monitoring-explore
---

# ACAPS seasonal calendar

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import geopandas as gpd
import pandas as pd
import numpy as np

from src import utils
```

```python
cods = utils.load_drought_codabs()
```

```python
# utils.process_acaps_seasonal()
seasons = utils.load_acaps_seasonal_processed()
seasons = seasons[seasons["has_codab"]]
growing = seasons[seasons["event_type"] == "Planting and growing"]
```

```python
# check crops available for each source
for source in growing["source"].unique():
    print(source)
    print(growing[growing["source"] == source]["label"].unique())
```

```python
# count crops per adm1
growing_agg = (
    growing.groupby(["source", "iso", "ADM1_NUM"])
    .nunique()["label"]
    .reset_index()
)
```

```python
cod_crop = cods.merge(growing_agg, on=["iso", "ADM1_NUM"])
```

```python
cod_crop[cod_crop["source"] == "FAO"].explore(column="label", vmin=0, vmax=7)
```

```python
cod_crop[cod_crop["source"] == "USDA"].explore(column="label", vmin=0, vmax=7)
```

```python

```
