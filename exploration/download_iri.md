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

# Download IRI

```python
%load_ext jupyter_black
```

```python
import requests

from ochanticipy import (
    GeoBoundingBox,
    IriForecastProb,
    IriForecastDominant,
    create_country_config,
    create_custom_country_config,
)
```

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
df = ds.to_dataframe()
```

```python
ds
```

```python
# plot example date for below avg tercile
ds.sel(L=1, F="2023-09-16", C=0)["prob"].plot()
```

```python

```
