import ast
import itertools
import os
from datetime import datetime
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import pycountry
import shapely
import xarray as xr
from ochanticipy import CodAB, create_country_config
from rasterio.enums import Resampling
from shapely.validation import make_valid

from src.constants import asap1_seasonalcalendar2gaul

DATA_DIR = Path(os.getenv("AA_DATA_DIR"))


def load_lhz_adm1_crop_pct_thresh(fileformat: str = "parquet") -> pd.DataFrame:
    load_dir = DATA_DIR / "private/processed/glb/iri"
    filestem = "iri_lhz_adm1_cropland_pct_thresholded"
    df = pd.read_parquet(load_dir / f"{filestem}.{fileformat}")
    df["date"] = pd.to_datetime(df["date"])
    df[["FNID", "asap1_id"]] = df["FNID_asap1"].str.split("_", expand=True)
    df = df.drop(columns=["FNID_asap1"])
    # manually specify dtypes because I think read_parquet can't
    int_cols = ["asap1_id", "threshold", "leadtime"]
    df[int_cols] = df[int_cols].astype(int)
    str_cols = ["FNID", "stat"]
    df[str_cols] = df[str_cols].astype(str)
    flt_cols = ["crop_gte", "total_crop", "pct_gte_thresh"]
    df[flt_cols] = df[flt_cols].astype(float)
    return df


def load_asap_seasonal() -> pd.DataFrame:
    load_dir = DATA_DIR / "public/processed/glb/asap"
    filename = "crop_calendar_gaul1_processed.csv"
    return pd.read_csv(load_dir / filename)


def process_asap_seasonal():
    """
    Process ASAP seasonal calendar.
    Matches up adm1 codes to align with those in ASAP adm.
    In some cases, this means that an admin2 gets assigned to be an admin1 -
    in this case, the original name (admin2) will appear in brackets next to
    the crop name in the crop_name column.
    Returns
    -------

    """
    asap_ref_dir = DATA_DIR / "public/raw/glb/asap/reference_data"
    filestem = "crop_calendar_gaul1"
    df = pd.read_csv(
        asap_ref_dir / filestem / f"{filestem}.csv", delimiter=";"
    )
    cod_asap = load_asap_adm(level=1)
    # check which asap1_ids don't match (all have matching asap0_ids)
    df["adm1_match"] = df["asap1_id"].isin(cod_asap["asap1_id"])
    missing_adm0s = df[~df["adm1_match"]]["asap0_id"].unique()
    for adm0 in missing_adm0s:
        # note: if prints nothing, because all admin1s accounted for
        dff = df[
            (df["asap0_id"] == adm0)
            & (~df["adm1_match"])
            & (~df["asap1_id"].isin(asap1_seasonalcalendar2gaul))
        ]
        if dff.empty:
            # skip if already assigned fix
            continue
        print(adm0)
        codf = cod_asap[cod_asap["asap0_id"] == adm0]
        print(codf["name0"].iloc[0])
        print("Missing adm1 match:")
        print(dff[["asap1_id", "name1_shr"]].value_counts())
        print("Possible adm1s:")
        print(list(codf["asap1_id"].unique()))
        print(codf[["asap1_id", "name1", "name1_shr"]].value_counts())
        print()
    df["asap1_id_match"] = df["asap1_id"].replace(asap1_seasonalcalendar2gaul)
    df = df.explode("asap1_id_match")
    df["name1_shr_match"] = df["asap1_id_match"].apply(
        lambda x: cod_asap[cod_asap["asap1_id"] == x].iloc[0]["name1_shr"]
    )
    cols = ["crop_name", "asap1_id_match"]
    df.loc[df[cols].duplicated(keep=False), "crop_name"] = df[
        df[cols].duplicated(keep=False)
    ].apply(lambda row: f"{row['crop_name']} ({row['name1_shr']})", axis=1)
    # drop and rename columns
    cols = ["asap1_id", "name1_shr", "adm1_match"]
    df = df.drop(columns=cols)
    df.columns = [x.removesuffix("_match") for x in df.columns]
    save_dir = DATA_DIR / "public/processed/glb/asap"
    save_path = save_dir / f"{filestem}_processed.csv"
    df.to_csv(save_path, index=False)


def process_fewsnet_lz_asap_adm_intersection():
    """
    Processes the intersection for all FEWSNET livelihood zones
    with ASAP admin1s.
    Returns
    -------

    """
    adm1 = load_asap_adm(level=1).to_crs(3857)
    lz = load_fewsnet_livelihoodzones().to_crs(3857)
    fix_countries = {
        "TZ": "United Republic of Tanzania",
        "CD": "Democratic Republic of the Congo",
    }
    adm1_countries = adm1["name0"].unique()
    adm1_drop_cols = [
        "km2_tot",
        "km2_crop",
        "km2_range",
        "an_crop",
        "an_range",
        "water_lim",
    ]
    lz_drop_cols = ["Shape_Leng", "Shape_Area"]
    snap_tol = 1000
    simplify_tol = 100

    lz_adm1 = gpd.GeoDataFrame()
    for alpha_2 in lz["COUNTRY"].unique():
        country = pycountry.countries.get(alpha_2=alpha_2)
        if country.name in adm1_countries:
            name = country.name
        else:
            # assign countries when there isn't a match
            name = fix_countries.get(alpha_2)
        adm1_f = adm1[adm1["name0"] == name]
        lz_f = lz[lz["COUNTRY"] == alpha_2]
        # simplify shps to avoid messy geometries
        adm1_f.loc[:, "geometry"] = adm1_f.geometry.simplify(simplify_tol)
        lz_f.loc[:, "geometry"] = lz_f.geometry.simplify(simplify_tol)

        # iterate over LZs
        for _, row in lz_f.iterrows():
            gdf_add = adm1_f.copy()
            gdf_add = gdf_add.drop(columns=adm1_drop_cols)
            # snap boundaries, to avoid thin slivers when they don't match up
            gdf_add.geometry = shapely.snap(
                gdf_add.geometry, row.geometry, tolerance=snap_tol
            )
            if not shapely.is_valid(row.geometry):
                row.geometry = make_valid(row.geometry)
            for i, x in gdf_add.iterrows():
                if not shapely.is_valid(x.geometry):
                    gdf_add.loc[i, "geometry"] = make_valid(x.geometry)
            # calculate intersection
            gdf_add.geometry = gdf_add.intersection(row.geometry)
            gdf_add = gdf_add[~gdf_add.geometry.is_empty]
            # remove geometries that aren't Polygons (ie LineStrings due to
            # overlapping boundaries
            gdf_add = gdf_add.explode(index_parts=True)
            gdf_add = gdf_add[gdf_add.geometry.geom_type == "Polygon"]
            # get rid of small areas due to imperfect alignment
            # (these still exist, even with snapping)
            gdf_add["area"] = gdf_add.area / 10e6
            gdf_add = gdf_add[gdf_add["area"] > 1]
            # aggregate geometries back together
            gdf_add = gdf_add.dissolve("name1").reset_index()
            gdf_add["area"] = gdf_add.area / 10e6
            # put LZ info in
            for col_name, value in row.items():
                if col_name not in [*lz_drop_cols, "geometry"]:
                    gdf_add[col_name] = value
            lz_adm1 = pd.concat([lz_adm1, gdf_add], ignore_index=True)

    # create unique ID for each LZ / ADM intersection
    lz_adm1["FNID_asap1"] = (
        lz_adm1["FNID"] + "_" + lz_adm1["asap1_id"].astype(str)
    )
    save_path = (
        DATA_DIR
        / "public/processed/glb/fewsnet_lz_asap_adm_intersection.shp.zip"
    )
    lz_adm1.to_file(save_path, encoding="utf-8")


def load_fewsnet_lz_asap_adm_intersection() -> gpd.GeoDataFrame:
    load_dir = DATA_DIR / "public/processed/glb"
    filename = "fewsnet_lz_asap_adm_intersection.shp.zip"
    zip_path = "zip:/" / load_dir / filename
    gdf = gpd.read_file(zip_path)
    return gdf


def load_fewsnet_livelihoodzones() -> gpd.GeoDataFrame:
    load_dir = DATA_DIR / "public/raw/glb/fewsnet"
    filename = "FEWS_NET_LH_World.zip"
    zip_path = "zip:/" / load_dir / filename
    gdf = gpd.read_file(zip_path)
    # correct for duplicate FNIDs
    gdf = gdf.dissolve("FNID").reset_index()
    return gdf


def load_asap_adm(level: int = 0) -> gpd.GeoDataFrame:
    """
    Load ASAP admin boundaries.
    Note: not as up-to-date as those on HDX, but at least complete for the
    whole world.

    Parameters
    ----------
    level: int = 0
        Admin level to load.
        Note: there is a problem with level 2

    Returns
    -------
    GeoDataFrame
    """
    load_dir = DATA_DIR / "public/raw/glb/asap/reference_data"
    filename = f"gaul{level}_asap_v04.zip"
    zip_path = "zip:/" / load_dir / filename
    gdf = gpd.read_file(zip_path)
    return gdf


def load_acaps_seasonal_processed() -> pd.DataFrame:
    """
    Load processed ACAPS seasonal calendar

    Returns
    -------
    df
    """
    filepath = (
        DATA_DIR
        / "public/processed/glb/acaps/seasonal-events-calendar_processed.csv"
    )
    return pd.read_csv(filepath)


def process_acaps_seasonal():
    """
    Processes ACAPS seasonal calendar,
    more or less to go from wide to long format.

    Explodes label (typically crop type) and adm1 columns.
    Returns
    -------

    """
    filepath = DATA_DIR / "public/raw/glb/acaps/seasonal-events-calendar.csv"
    df = pd.read_csv(filepath)
    # convert literals
    cols = [
        "iso",
        "country",
        "months",
        "event",
        "event_type",
        "label",
    ]
    df[cols] = df[cols].map(ast.literal_eval)
    df["adm1"] = df["adm1"].apply(lambda x: x.split(", "))
    # explode single-value cols
    for col in cols:
        if (df[col].apply(len) == 1).all():
            df = df.explode(col)
    # also explode labels
    df = df.explode("label")

    # explode adm1
    def replace_nans(row):
        if isinstance(row["adm1_eng_name"], float) or len(
            ast.literal_eval(row["adm1_eng_name"])
        ) != len(row["adm1"]):
            return [""] * len(row["adm1"])
        else:
            return ast.literal_eval(row["adm1_eng_name"])

    df["adm1_eng_name"] = df.apply(replace_nans, axis=1)
    df = df.explode(["adm1", "adm1_eng_name"])
    df["months_num"] = df["months"].apply(
        lambda x: [datetime.strptime(m, "%B").month for m in x]
    )
    df["start_month"] = df["months_num"].apply(lambda x: x[0])
    df["end_month"] = df["months_num"].apply(lambda x: x[-1])
    df["ADM1_NUM"] = df["adm1"].apply(
        lambda x: int(x.split(".")[1].split("_")[0])
    )
    df = df.drop(columns=["id"])

    df["has_codab"] = False
    for adm0 in df["iso"].unique():
        country_config = None
        try:
            country_config = create_country_config(adm0)
        except FileNotFoundError:
            print(f"{adm0} not in Anticipy")
        if country_config is not None:
            try:
                cod = CodAB(country_config)
                print(f"downloading {adm0}")
                cod.download()
                df.loc[df["iso"] == adm0, "has_codab"] = True
            except FileNotFoundError as err:
                print(err)
            except AttributeError as err:
                print(err)

    df.to_csv(
        DATA_DIR
        / "public/processed/glb/acaps"
        / f"{filepath.stem}_processed.csv",
        index=False,
    )


def load_drought_codabs() -> gpd.GeoDataFrame:
    return gpd.read_file(
        DATA_DIR / "public/processed/glb/cod_ab/glb_drought_countries.shp.zip"
    )


def process_drought_codabs():
    """
    Merges all CODABs into one shp.
    Selects only those that are in ACAPS, and have an existing AnticiPy config.
    Returns
    -------

    """
    df = load_acaps_seasonal_processed()
    gdf = gpd.GeoDataFrame()
    for adm0 in df[df["has_codab"]]["iso"].unique():
        country_config = create_country_config(adm0)
        codab = CodAB(country_config).load(admin_level=1)
        if "ADM1_PCODE" in codab.columns:
            code_col = "ADM1_PCODE"
        else:
            if adm0 == "NER":
                code_col = "rowcacode1"
            elif adm0 in ["CAF", "BDI", "TCD"]:
                code_col = "admin1Pcod"
        if "ADM1_EN" in codab.columns:
            name_col = "ADM1_EN"
        else:
            if adm0 == "NER":
                name_col = "adm_01"
            elif adm0 == "MOZ":
                name_col = "ADM1_PT"
            elif adm0 in ["COL", "VEN"]:
                name_col = "ADM1_ES"
            elif adm0 in ["MLI", "BFA", "COD"]:
                name_col = "ADM1_FR"
            elif adm0 in ["CAF", "BDI", "TCD"]:
                name_col = "admin1Name"
        gdf_add = gpd.GeoDataFrame(geometry=codab.geometry)
        gdf_add[["ADM1_CODE", "ADM1_NAME"]] = codab[[code_col, name_col]]

        gdf_add["iso"] = adm0
        gdf = pd.concat([gdf, gdf_add], ignore_index=True)

    gdf = gdf[gdf["ADM1_CODE"].apply(lambda x: isinstance(x, str))]
    gdf["ADM1_NUM"] = gdf["ADM1_CODE"].apply(
        lambda x: int("".join(filter(str.isdigit, x)))
    )

    save_path = (
        DATA_DIR / "public/processed/glb/cod_ab/glb_drought_countries.shp.zip"
    )
    gdf.to_file(save_path)


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

    Taken from pa-aa-bfa-drought

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
