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
cods
```

```python
cods.explore()
```

```python
# utils.process_acaps_seasonal()
seasons = utils.load_acaps_seasonal_processed()
seasons = seasons[seasons["has_codab"]]
display(seasons)
```

```python
seasons["event_type"].unique()
```

```python
seasons["source"].unique()
```

```python
seasons["label"].unique()
```

```python
growing = seasons[seasons["event_type"] == "Planting and growing"]
```

```python
growing["source"].value_counts()
```

```python
growing[growing["source"] == "FAO"]["iso"].unique()
```

```python
growing[growing["iso"] == "SOM"]
```

```python

```
