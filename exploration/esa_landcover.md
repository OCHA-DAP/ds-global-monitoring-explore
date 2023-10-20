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

# ESA Landcover

```python
%load_ext jupyter_black
%load_ext autoreload
%autoreload 2
```

```python
import os
from pathlib import Path
```

```python
DATA_DIR = Path(os.getenv("AA_DATA_DIR"))
```

```python
proc_dir = DATA_DIR / "public/processed/glb/esa_world_cover"
filenames = os.listdir(proc_dir)
filenames
```

```python

```
