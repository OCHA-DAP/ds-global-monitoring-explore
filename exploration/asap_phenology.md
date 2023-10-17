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

# ASAP phenology

From [here](https://agricultural-production-hotspots.ec.europa.eu/download.php)

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import os
from pathlib import Path

import xarray as xr
import rioxarray as rxr

from src import utils
```

```python
DATA_DIR = Path(os.getenv("AA_DATA_DIR"))
```

## Process data

```python
# utils.process_asap_phenology_dekads()
```

```python
# utils.process_asap_phenology_months()
```

```python
# utils.process_asap_phenology_trimesters("any")
```

```python
# utils.process_asap_phenology_trimesters("all")
```

## Check plots

```python
da = utils.load_inseason("dekad", 1)
```

```python
lon, lat = 0, 0
da.where(da < 251).sel(x=slice(lon, lon + 40), y=slice(lat + 40, lat)).plot()
```

```python
da = utils.load_inseason("trimester", 11, "sum")
```

```python
lon, lat = 0, 0
da.where(da < 251).sel(x=slice(lon, lon + 40), y=slice(lat + 40, lat)).plot()
```

```python
da.dtype
```

```python
da
```

## Check error values

Assuming that error values (>250) are all set in start of season 1 raster.

```python
load_dir = DATA_DIR / "public/raw/glb/asap/reference_data"
filename = "phenos1_v03.tif"
sos = rxr.open_rasterio(load_dir / filename)
```

```python
sos.where(sos > 249).plot.hist(bins=[x + 0.5 for x in range(249, 256)])
```

```python
# seems like the values > 205 are:
# 255 = water
# 254 = not used
# 253 = hard to tell, barely used
# 252 = hard to tell
# 251 = no season (desert but also rainforest?)
lon, lat = -68, -14
sos_f = sos.where(sos > 250).sel(
    x=slice(lon, lon + 40), y=slice(lat + 40, lat)
)
sos_f.plot()
```
