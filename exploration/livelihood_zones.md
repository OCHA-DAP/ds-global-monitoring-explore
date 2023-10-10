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

# FEWSNET livelihood zones

Explore [FEWSNET livelihood zones](https://fews.net/data/livelihood-zones)

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
from pathlib import Path
import os

import geopandas as gpd

from src import utils
```

```python
gdf = utils.load_fewsnet_livelihoodzones()
```

```python
gdf.explore()
```

```python
gdf
```

```python

```
