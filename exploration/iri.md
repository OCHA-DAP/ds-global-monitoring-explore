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
    display_name: ds-global-monitoring-explore-39
    language: python
    name: ds-global-monitoring-explore-39
---

# IRI

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import requests
import os
from pathlib import Path

import matplotlib.pyplot as plt
from ochanticipy import (
    GeoBoundingBox,
    IriForecastProb,
    IriForecastDominant,
    CodAB,
    create_country_config,
    create_custom_country_config,
)
import rioxarray as rxr
import xarray as xr

from src import utils
```

```python
DATA_DIR = Path(os.getenv("AA_DATA_DIR"))
proc_dir = DATA_DIR / "private/processed/glb/iri"
```

## Load

```python
# set up config
country_config = create_custom_country_config("../glb.yaml")
geobb = GeoBoundingBox(lat_max=90, lat_min=-90, lon_max=180, lon_min=-180)

iri_prob = IriForecastProb(
    country_config=country_config, geo_bounding_box=geobb
)

iri_prob.download()
iri_prob.process()
ds = iri_prob.load()
```

```python
iri_prob._get_file_name().removesuffix(".nc").replace(
    "tercile", "lower_tercile"
)
```

```python
ds
```

## Save TIF

```python
# save TIFs each date
# only lower tercile

da = ds.sel(C=0)["prob"]

save_dir = proc_dir / "tif"

for date in da.F.values:
    filename = (
        iri_prob._get_file_name()
        .removesuffix(".nc")
        .replace("tercile", "lower_tercile")
        + "_"
        + date.strftime("%Y-%m-%d")
        + ".tif"
    )
    da_f = da.sel(F=date)

    da_f.rio.to_raster(save_dir / filename)
```

```python
# check TIF
da_o = rxr.open_rasterio(save_dir / filename)
da_o[0].plot()
```

## Plot examples

```python
# plot example date for below avg tercile
leadtime = 1
forecast_date = "2023-09-16"

ds_f = ds.sel(L=leadtime, F=forecast_date)
ds_f.sel(C=0)["prob"].plot()
```

```python
# calculate for example country

country_config = create_country_config("ner")
cod = CodAB(country_config)
cod.download()
cod.process()
adm0 = cod.load(admin_level=0)
geobb = GeoBoundingBox.from_shape(adm0)

ds_adm0 = ds_f.rio.clip(adm0["geometry"], all_touched=True)
# resample to 0.01 degrees
# note that ESA landcover is 1/12000 degrees (0.0000833...)
# which is about 10m at equator
ds_adm0 = utils.approx_mask_raster(ds_adm0, "X", "Y", resolution=0.01)
ds_adm0 = ds_adm0.rio.clip(adm0["geometry"], all_touched=True)
ds_adm0.sel(C=0)["prob"].plot()
df = (
    ds_adm0.sel(C=0)["prob"]
    .to_dataframe()["prob"]
    .reset_index()
    .drop(columns="F")
)
```

```python
# plot cumulative distribution of probability (reversed)
df.hist("prob", cumulative=-1, bins=100, density=1)
plt.gca().invert_xaxis()
```

```python

```

```python

```
