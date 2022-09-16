ARG DOCKER_IMAGE_BASE_ML
FROM $DOCKER_IMAGE_BASE_ML

# Move out of working dir /ray
# Delete stale data
WORKDIR /
RUN rm -rf /ray

RUN mkdir /ray
WORKDIR /ray

# Copy new ray files
COPY . .

# Create egg.link
RUN echo /ray/python > /opt/miniconda/lib/python3.7/site-packages/ray.egg-link

RUN RLLIB_TESTING=1 TRAIN_TESTING=1 TUNE_TESTING=1 ./ci/env/install-dependencies.sh
