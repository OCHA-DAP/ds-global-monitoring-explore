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

# ASAP admin + FEWSNET livelihoods

Combining ASAP admin boundaries and FEWSNET livelihoods zones

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import os
from pathlib import Path

from src import utils
```

```python
utils.process_fewsnet_lz_asap_adm_intersection()
```

```python
gdf = utils.load_fewsnet_lz_asap_adm_intersection()
gdf.explore(column="name0")
```

```python
gdf.columns
```

```python
gdf["MAINCROPS"].value_counts()
```

```python
gdf["id_len"] = gdf["FNID_asap1"].apply(len)
```

```python
gdf["id_len"].value_counts()
```

```python
len(gdf["FNID_asap1"].unique())
```

```python
len(gdf)
```

```python
gdf[gdf.duplicated(subset=["FNID_asap1"], keep=False)]
```

```python

```
