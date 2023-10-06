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
import geopandas as gpd
import pandas as pd
import pycountry
import shapely
from shapely.validation import make_valid, explain_validity

from src import utils
```

```python
# utils.process_fewsnet_lz_asap_adm_intersection()
gdf = utils.load_fewsnet_lz_asap_adm_intersection()
gdf.explore()
```
