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

# ASAP seasonal calendar

Explore [ASAP](https://agricultural-production-hotspots.ec.europa.eu/wexplorer/)
seasonal calendar data

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import os
from pathlib import Path

import geopandas as gpd
import pandas as pd

from src import utils
```

```python
# utils.process_asap_seasonal()
df = utils.load_asap_seasonal()
```

```python
df
```

```python
# count unique crops per adm1
cols = ["asap0_id", "name0_shr", "asap1_id_match", "name1_shr"]
crop_count = df.groupby(cols).nunique()["crop_name"].reset_index()
```

```python
# join with CODAB
# note - some asap1_ids don't match up,
# hence will be missing from plot
cod_crop = cod_asap.merge(
    crop_count[["asap1_id_match", "crop_name"]],
    left_on="asap1_id",
    right_on="asap1_id_match",
)
```

```python
# plot by adm1
cod_crop.explore(column="crop_name", vmin=0, vmax=7)
```

```python
# count unique crops per adm0
cols = ["asap0_id", "name0_shr"]
crop0_count = df.groupby(cols).nunique()["crop_name"].reset_index()
```

```python
# join with CODAB

cod0_crop = cod0_asap.merge(
    crop0_count[["asap0_id", "crop_name"]], on="asap0_id"
)
```

```python
# plot by adm0
cod0_crop.explore(column="crop_name", vmin=0, vmax=7)
```

```python

```
