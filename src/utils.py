import itertools

import numpy as np
import xarray as xr
from rasterio.enums import Resampling


def approx_mask_raster(
    ds: xr.Dataset,
    x_dim: str,
    y_dim: str,
    resolution: float = 0.05,
) -> xr.Dataset:
    """
    Resample raster data to given resolution.

    Uses as resample method nearest neighbour, i.e. aims to keep the values
    the same as the original data. Mainly used to create an approximate mask
    over an area

    Parameters
    ----------
    ds: xr.Dataset
        Dataset to resample.
    resolution: float, default = 0.05
        Resolution in degrees to resample to

    Returns
    -------
        Upsampled dataset
    """
    upsample_list = []
    # can only do reproject on 3D array so
    # loop over all +3D dimensions
    list_dim = [d for d in ds.dims if (d != x_dim) & (d != y_dim)]
    # select from second element of list_dim since can loop over 3D
    # loop over all combs of dims
    dim_names = list_dim[1:]
    for dim_values in itertools.product(*[ds[d].values for d in dim_names]):
        ds_sel = ds.sel(
            {name: value for name, value in zip(dim_names, dim_values)}
        )

        ds_sel_upsample = ds_sel.rio.reproject(
            ds_sel.rio.crs,
            resolution=resolution,
            resampling=Resampling.nearest,
            nodata=np.nan,
        )
        upsample_list.append(
            ds_sel_upsample.expand_dims(
                {name: [value] for name, value in zip(dim_names, dim_values)}
            )
        )
    ds_upsample = xr.combine_by_coords(upsample_list)
    # reproject changes spatial dims names to x and y
    # so change back here
    ds_upsample = ds_upsample.rename({"x": x_dim, "y": y_dim})
    return ds_upsample
