## Mobility Data Science: From Edge to Cloud Processing
### Alejandro Vaisman, Esteban Zimányi, with contributions by Leticia Gómez

### Chapter 11: Mobility Foundation Models

This is the companion website of the book published by Springer.
It contains the datasets used in the book alongside with the scripts
allowing you to input these datasets in the various tools and reproduce the
examples and exercises in the book.

The chapter presents a trajectory foundation model whose parameters are shared
by urban and maritime movement, pretrained by masked reconstruction on a corpus
of open trajectory datasets enriched with their context. The model and its
corpus come from the master's thesis of Nhu Ngoc Hoang, *A Semantics-Enriched
Trajectory Foundation Model for Urban and Maritime Mobility*, whose code and
data are public. The directory `training/` retrains the model of the chapter
from the published data.

### Software

- Python 3.10 or later with PyTorch 2.1 or later, NumPy, pandas 2, and PyArrow
  14 or later (`training/requirements.txt`). The training command runs with
  Python 3.12, PyTorch 2.14.1, pandas 3.0.6, NumPy 2.5.3, and PyArrow 25.0.1.
- The code of the thesis at commit `72d9fec` of
  [MobilityDB/FoundationModel](https://github.com/MobilityDB/FoundationModel),
  which also holds the thesis itself:
  the enrichment pipelines (`enrichment-pipeline/`), the model and its training
  (`models/`), and the frozen benchmark (`benchmark/`). `training/train.sh`
  clones it.
- The [Kaggle command-line client](https://github.com/Kaggle/kaggle-api), with an
  API token in `~/.kaggle/kaggle.json`, to download the encoded data.
- For training at the scale of the chapter, one GPU with CUDA. The configuration
  of the chapter targets one NVIDIA A100 with 80 GB of memory and TF32 arithmetic; the
  model has 1,355,018 trainable parameters, so a smaller GPU suffices with a
  smaller batch.

### Datasets

The corpus combines eight urban and two maritime sources. None of them is
redistributed here. The enriched and encoded corpus is published by the author
of the thesis, which is what `training/fetch_data.sh` downloads:

| Artifact | Where | Size |
|---|---|---|
| Enriched urban data, with their splits | Hugging Face dataset [nhungoc1508/mt-enriched-data](https://huggingface.co/datasets/nhungoc1508/mt-enriched-data) | |
| Encoded urban data: canonical Parquet files and embeddings, per split | Kaggle dataset [nhungoc1508/trajectory-foundation-model-urban](https://www.kaggle.com/datasets/nhungoc1508/trajectory-foundation-model-urban) | 37.5 GB |
| Encoded maritime data: canonical Parquet files and embeddings, per day and split | Kaggle dataset [nhungoc1508/trajectory-foundation-model-maritime](https://www.kaggle.com/datasets/nhungoc1508/trajectory-foundation-model-maritime) | 25.7 GB |
| Held-out set (Cabspotting and NOAA) with its frozen masks | Kaggle dataset [nhungoc1508/trajectory-foundation-model-heldout](https://www.kaggle.com/datasets/nhungoc1508/trajectory-foundation-model-heldout) | 4.0 GB |

The original sources, for those who want to rerun the enrichment pipelines:

| Source | Region | Publisher |
|---|---|---|
| Porto | Porto | [Taxi Service Trajectory, ECML/PKDD 2015](https://archive.ics.uci.edu/dataset/339/taxi+service+trajectory+prediction+challenge+ecml+pkdd+2015), UCI Machine Learning Repository |
| T-Drive | Beijing | [T-Drive trajectory data sample](https://www.microsoft.com/en-us/research/publication/t-drive-trajectory-data-sample/), Microsoft Research |
| pNEUMA | Athens | [pNEUMA](https://open-traffic.epfl.ch/), EPFL; October 24, 2018, 08:30 to 11:00 |
| GeoLife | Beijing | [GeoLife GPS trajectories](https://www.microsoft.com/en-us/research/publication/geolife-gps-trajectory-dataset-user-guide/), Microsoft Research |
| New York City | New York City | GPS traces shared on OpenStreetMap by bus, car, foot, bicycle, and subway, 2009 to 2024 |
| Cabspotting (held out) | San Francisco | [CRAWDAD epfl/mobility](https://ieee-dataport.org/open-access/crawdad-epflmobility) |
| BerlinMOD-Brussels | Brussels | [MobilityDB-BerlinMOD](https://github.com/MobilityDB/MobilityDB-BerlinMOD), scale factor 0.2 |
| BerlinMOD-Hanoi | Hanoi | [MobilityDB-BerlinMOD-Hanoi](https://github.com/MobilityDB/MobilityDB-BerlinMOD-Hanoi), scale factor 0.2 |
| DMA | Danish waters | [Danish Maritime Authority](http://aisdata.ais.dk/), the 1st, 7th, and 15th of each month from March 2024 to March 2026 |
| NOAA (held out) | East coast of the United States | [Marine Cadastre AIS](https://hub.marinecadastre.gov/pages/vesseltraffic), October to December 2025, bounding box [−72.371, 39.251, −65.506, 41.792] |

The enrichment uses OpenStreetMap, the ERA5 reanalysis, the Copernicus Marine
Service reanalyses `cmems_mod_glo_wav_my_0.2deg_PT3H-i` and
`cmems_mod_glo_phy_my_0.083deg_P1D-m`, the World Port Index, the VLIZ World EEZ
v12 and IHO Sea Areas v3, the GEBCO 2026 grid, the AIS annotation tool of
[HABIT](https://github.com/M3-Archimedes/AIS-trajectory-annotation), and the
text encoder [EmbeddingGemma](https://huggingface.co/google/embeddinggemma-300m)
with outputs truncated to 256 dimensions; the configuration files under
`enrichment-pipeline/*/config/` of the thesis repository name them.

### Splits

Each source except the held-out ones is split chronologically into 70% training,
15% validation, and 15% test trajectories, ordered by start time
(`enrichment-pipeline/shared/run_split.py`). For the Danish AIS data, the split
is by day: 40 days from 2024-03-01 to 2025-08-01 for training, 8 days from
2025-08-07 to 2025-11-15 for validation, and 8 days from 2025-12-01 to
2026-03-15 for testing. The urban Kaggle dataset also holds Cabspotting under
`train/`, `val/`, and `test/`; `fetch_data.sh` moves it out of these
directories, since Cabspotting belongs to the held-out set and is not used for
training.

The day of the use case of the chapter, 2026-01-20, is not one of the AIS days
of the corpus.

### Retraining the model

    cd training
    DATA=$HOME/tfm-data ./fetch_data.sh   # about 67 GB
    DATA=$HOME/tfm-data ./train.sh

`train.sh` runs `models/train.py` of the thesis with the configuration of the
chapter (Table 11.5 of the book):

| Parameter | Value |
|---|---|
| Encoder layers, heads, width, feed-forward width | 6, 4, 128, 512 |
| Feed-forward sublayer | shared network, no mixture of experts (`--no-moe`) |
| Fourier features per temporal component | 64 |
| Semantic embedding dimension | 256 |
| Maximum sequence length | 256 |
| Dropout rate | 0.1 |
| Masking probabilities (random, block, key-point, kinematic, semantic, last-N) | 0.30, 0.15, 0.15, 0.05, 0.05, 0.30 |
| Loss weights (spatial, temporal, kinematic) | 5, 1, 0.25 |
| Batch size | 1536, as alternating batches of 768 urban and 768 maritime trajectories |
| Optimizer, weight decay | AdamW, 1e-4 |
| Learning rate | 1.4e-3 to 1e-5, cosine schedule stepped per epoch |
| Gradient clipping | norm 1 |
| Epochs, early stopping patience | at most 50, 10, on the spatial validation MSE |
| Seed | 1508 (`SEED`) |

The program seeds Python, NumPy, and PyTorch from `SEED`, and writes the
checkpoint with the smallest spatial validation error to
`checkpoints/main_best.pt`, together with the state of the generators, so that
a run can be resumed. Two runs with the same seed on different GPUs or CUDA
versions may differ slightly, since parallel floating-point reductions are not
associative.

### The use case of the chapter

The directory `usecase/` runs the use case of the chapter, "Filling the Gaps of
Vessels in Danish Waters", from the AIS data to the measured errors. Every table
it reads and writes lives in the AIS database of the book, built by `../ais/`.

| Table | Content | Built by |
|---|---|---|
| `AISInput`, `AISClean`, `Vessels`, `Ships`, `Segments` | The AIS day of January 20, 2026, cleaned, with the trips and the reported speed, course, heading, and rate of turn of each vessel | `../ais/build.sh` |
| `Bathymetry`, `WaveHeight`, `NaturalAreas` | The depth, the hourly wave height, and the protected areas of chapter 5 | `../chapter5/load_all.sh aux ddm fields` |
| `WPIPort`, `SeaAreas`, `EEZ`, `TerritorialSea`, `TSS` | The ports of the World Port Index, the IHO sea areas, the exclusive economic zones and territorial seas of the VLIZ Marine Regions, and the traffic separation schemes of OpenStreetMap | `fetch_context.sh`, `load_context.sh` |
| `Gaps`, `TripPoints` | The gaps of at most 30 minutes and their windows, sampled every minute | `01_sequences.sql` |
| `PointContext`, `PointDescriptor` | The context of every observed position and its description in the template of the corpus | `02_context.sql`, `03_descriptions.sql` |
| `PointEmbedding` | The 256-dimensional embedding of every description | `embed.py` |
| `EvalMasks`, view `ModelInput` | The positions every model is asked to reconstruct, and the sequences given to the model | `04_masks.sql` |
| `ReconstructedLonLat`, `Reconstructed`, view `Errors` | The reconstructions of the models `crossdomain` and `coordinates` and of the baseline `linear`, and their errors | `run_model.py`, `05_evaluate.sql` |
| `GapPaths`, `GapAreas` | The reconstructed path of every gap, and the protected areas the vessel could have entered | `06_exact.sql` |
| `Reconstructed`, model `hermite` | The positions inside every gap on the cubic Hermite curve between the reports that bound it | `07_hermite.sql` |

#### Software

- The AIS database of `../ais/`, with the tables of chapter 5 loaded into it.
- GDAL with `ogr2ogr`, to load the reference layers.
- Python 3.10 or later with the packages of `usecase/requirements.txt`.
- The code of the thesis at commit `2490c45`, which `run_usecase.sh` clones, and
  the checkpoint of its main model, `ablation_ffn_0710_best.pt` of the Hugging
  Face model repository [nhungoc1508/tfm](https://huggingface.co/nhungoc1508/tfm),
  which `run_model.py` downloads with `hf_hub_download` (or reads from the path
  in `CHECKPOINT`). The model has a single shared feed-forward network, adds the
  semantic channel to the token at the input, and has 1,355,018 parameters; its
  configuration is the one of the table above. `run_model.py` loads it strictly
  with the code of `2490c45`. The checkpoint `models/checkpoints/best.pt` of the
  code repository, at commit `8fc3ca2`, is a variant with a mixture of experts,
  which the chapter describes under *specialization* but does not use.
- For the embeddings, a Hugging Face account that has accepted the license of
  [EmbeddingGemma](https://huggingface.co/google/embeddinggemma-300m), and its
  token stored with `hf auth login`.

#### Running the use case

    cd usecase
    python3 -m venv venv && . venv/bin/activate
    pip install -r requirements.txt
    hf auth login
    PGDATABASE=ais bash fetch_context.sh && PGDATABASE=ais bash load_context.sh
    PGDATABASE=ais bash run_usecase.sh

On a laptop with an NVIDIA RTX 3060 GPU with 6 GB of memory, the whole run takes
about 30 minutes, of which 19 for the embedding of the 160,439 descriptions. The
use case can be reproduced without a GPU in two ways:

| Command | What runs | Time on the processor of a laptop |
|---|---|---|
| `EMBED=0 SAMPLE=5 bash run_usecase.sh` | 5% of the gaps (439), without embeddings: the model `coordinates` and the baseline `linear` | 1 minute |
| `SAMPLE=5 bash run_usecase.sh` | 5% of the gaps, with the embeddings of their 8,907 descriptions: every model | 43 minutes |

The share of gaps is chosen by a hash of the key of each gap, so every run with
the same `SAMPLE` studies the same gaps. Without a GPU, the encoder runs in
single precision instead of bfloat16, so the embeddings, and the errors of the
model `crossdomain`, may differ slightly from those of the book.

For the whole day, `05_evaluate.sql` prints the errors of the book:

    model       | task       | positions | meanerr | medianerr | p90err
    coordinates | prediction |     15427 |     144 |         2 |    498
    crossdomain | prediction |     15427 |     151 |         2 |    521
    linear      | prediction |     15427 |      21 |         0 |     26
    coordinates | recovery   |     79636 |      97 |         1 |    176
    crossdomain | recovery   |     79636 |      95 |         1 |    178
    linear      | recovery   |     79636 |      53 |         1 |     37

and `07_hermite.sql` counts the gaps in which the Hermite curve departs from the
straight segment of the baseline `linear`:

    gaps | curved | over100 | over500
    8192 |   1947 |     841 |     258

#### Synthetic gaps

`usecase/synthetic_gaps.py` compares the model, the straight segment, and the
Hermite curve on synthetic gaps: in the 693 stretches of 181 minutes of the
vessels moving at 3 knots or more, the central 5 to 120 minutes are hidden and
reconstructed from the positions around them, and the script prints, for each
length, the median and the mean error of each method and the share of the
stretches in which the curve is more accurate than the segment. It reads the
table `Ships` of the AIS database and runs the main model of the thesis without
descriptions, so it does not need the embeddings; it runs on the GPU when there
is one. From `usecase/`, after `run_usecase.sh` has cloned the thesis:

    THESIS=data/FoundationModel PGDATABASE=ais python3 synthetic_gaps.py

### Figures

The directory `figures/` draws the figures of the use case from the tables of
the AIS database once `run_usecase.sh` has run. The charts are drawn with
matplotlib (`figures/requirements.txt`) through its PGF backend, which needs
`pdflatex` with the packages `lmodern` and `xcolor`, so that their text is set
in the face of the book; each export writes its CSV files into the working
directory, and each drawing script reads them from there and writes the PDF
files the book includes. From `figures/`:

    psql -d ais -f export_gap3584.sql && python3 fig_gap3584.py
    psql -d ais -f export_errors.sql && python3 curves.py && python3 fig_errors.py
    PGDATABASE=ais OUT=/mnt/c/<folder> bash make_hermite.sh

`export_gap3584.sql` also prints the values the chapter quotes for the gap 3584:
the rows of `Reconstructed` of its table, the errors of the positions 12 to 15,
the median recovery error before and after the gap, and how far the positions
of each model inside the gap lie from the segment that bounds it.
`fig_errors.py` prints, for each task and speed class, the number of windows,
the mean paired difference with its 95% bootstrap interval, and the share of
windows in which `crossdomain` is the more accurate, which the chapter quotes
beside the figure of the paired differences; `curves.py` writes the medians the
chapter quotes for the isolation and the horizon to `isolation_curve.csv` and
`horizon_curve.csv`.

| Figure | Scripts | Files |
|---|---|---|
| The tasks on the gap 3584 and the reconstructions of `crossdomain` | `export_gap3584.sql`, `fig_gap3584.py` | `gap3584_tasks_a_v2.pdf`, `gap3584_tasks_b.pdf`, `gap3584_tasks_legend.pdf` |
| The paired differences of the error per window, by speed class | `export_errors.sql`, `fig_errors.py` | `errors_paired.pdf` |
| The median error against the isolation and the horizon | `export_errors.sql`, `curves.py`, `fig_errors.py` | `errors_isolation.pdf`, `errors_horizon.pdf` |
| The reachable region, the reconstructed path, and the protected areas of the gap 5452 | `export_errors.sql`, `fig_errors.py` | `errors_q14_gap5452.pdf` |
| The straight segment and the Hermite curve on two gaps and two hidden turns | `make_hermite.sh`, with `export_hermite.py` | `hermite_gap4907.pdf`, `hermite_gap7902.pdf`, `hermite_turn209276000.pdf`, `hermite_turn210620000.pdf` |

`make_hermite.sh` runs `export_hermite.py`, which writes the layers of each map
into a GeoPackage, the job of `render_map.py` of chapter 5 that draws it, and
`summary.json`, which gives for each map the errors or the separation of the
straight segment and the curve that the chapter quotes; it then draws each job
as a vector PDF with `hybrid_pdf.py` of chapter 3, over the OpenStreetMap vector
tiles. The labels of the maps, their scale bar, and their legend are set by the
chapter in LaTeX over the images. The script runs the Python of QGIS named by
`QGIS_PY`, as in the section "Figures" of `../chapter5/README.md`; with the QGIS
of Windows called from WSL, `OUT` is a folder on a Windows drive.
