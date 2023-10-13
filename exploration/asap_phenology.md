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
from src import utils
```

```python
# utils.process_asap_phenology_dekads()
# utils.process_asap_phenology_months()
utils.process_asap_phenology_n_month_chunks(n=3)
```

```python
da = utils.load_inseason("forecast_base_month", 1)
```

```python
da.sel(x=slice(0, 10), y=slice(10, 0)).plot()
```

```python

```
