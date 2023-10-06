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
DATA_DIR = Path(os.getenv("AA_DATA_DIR"))
```

```python
# load data
asap_ref_dir = DATA_DIR / "public/raw/glb/asap/reference_data"
filename = "crop_calendar_gaul1"
df = pd.read_csv(asap_ref_dir / filename / f"{filename}.csv", delimiter=";")
cod_asap = gpd.read_file(f"zip://{asap_ref_dir / 'gaul1_asap_v04.zip'}")
cod0_asap = gpd.read_file(f"zip://{asap_ref_dir / 'gaul0_asap_v04.zip'}")
```

```python
# count unique crops per adm1
cols = ["asap0_id", "name0_shr", "asap1_id", "name1_shr"]
crop_count = df.groupby(cols).nunique()["crop_name"].reset_index()
```

```python
# join with CODAB
# note - some asap1_ids don't match up,
# hence will be missing from plot
cod_crop = cod_asap.merge(crop_count[["asap1_id", "crop_name"]], on="asap1_id")
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
# doing with adm0 since adm1 IDs don't all match
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