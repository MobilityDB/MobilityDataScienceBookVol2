FROM apache/sedona:1.8.1

# Install dependencies (including build essentials if needed for other packages)
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-pip \
    python3-venv


RUN python3 -m venv /opt/env
ENV PATH="/opt/env/bin:$PATH"

RUN pip3 install --upgrade pip 
RUN pip install jupyter
RUN pip install grpcio grpcio-tools 
RUN pip install protobuf=='3.20.3'
RUN pip install matplotlib
RUN pip install plotnine   
RUN pip install bokeh
RUN pip install pandas
RUN pip install hvplot
RUN pip install seaborn
RUN pip install intake intake-parquet intake-xarray s3fs
RUN pip install altair
RUN pip install plotly
RUN pip install holoviews
RUN pip install tensorflow=='2.16.1'
RUN pip install vega_datasets


