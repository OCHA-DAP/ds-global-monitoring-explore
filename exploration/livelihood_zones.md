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

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
from pathlib import Path
import os

import geopandas as gpd
```

```python
DATA_DIR = Path(os.getenv("AA_DATA_DIR"))
```

```python
filepath = DATA_DIR / "public/raw/glb/fewsnet" / "FEWS_NET_LH_World.zip"
gdf = gpd.read_file(f"zip:///{filepath}")
```

```python
gdf.explore()
```

```python
gdf
```

```python

```
