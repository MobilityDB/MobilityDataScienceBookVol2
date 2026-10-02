## Mobility Data Science: In-Memory, Large-Scale and Stream Processing
### Leticia Gómez, Alejandro Vaisman, Esteban Zimányi

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
  [nhungoc1508/master-thesis](https://github.com/nhungoc1508/master-thesis):
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
| New York City | New York City | Trajectories collected from OpenStreetMap, 2008 to 2025 |
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
