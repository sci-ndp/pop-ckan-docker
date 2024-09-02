FROM ckan/ckan-base:2.10.3

# Install any extensions needed by your CKAN instance
RUN pip3 install -e 'git+https://github.com/ckan/ckanext-harvest.git@master#egg=ckanext-harvest' && \
    if [ -f "${APP_DIR}/src/ckanext-harvest/pip-requirements.txt" ]; then \
        pip3 install -r ${APP_DIR}/src/ckanext-harvest/pip-requirements.txt; \
    else \
        echo "pip-requirements.txt not found for ckanext-harvest. Skipping..."; \
    fi && \
    pip3 install -e 'git+https://github.com/ckan/ckanext-dcat.git#egg=ckanext-dcat' && \
    if [ -f "${APP_DIR}/src/ckanext-dcat/requirements.txt" ]; then \
        pip3 install -r ${APP_DIR}/src/ckanext-dcat/requirements.txt; \
    else \
        echo "requirements.txt not found for ckanext-dcat. Skipping..."; \
    fi && \
    pip3 install ckanext-keycloak && \
    pip3 install python-keycloak-client==0.1.3 && \
    pip3 install ckanext-geoview

# Copy custom initialization scripts
COPY docker-entrypoint.d/* /docker-entrypoint.d/

# Apply any patches needed to CKAN core or any of the built extensions (not the
# runtime mounted ones)
COPY patches ${APP_DIR}/patches

RUN for d in ${APP_DIR}/patches/*; do \
        if [ -d $d ]; then \
            for f in `ls $d/*.patch | sort -g`; do \
                cd $SRC_DIR/`basename "$d"` && echo "$0: Applying patch $f to $SRC_DIR/`basename $d`"; patch -p1 < "$f" ; \
            done ; \
        fi ; \
    done
