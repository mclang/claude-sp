FROM python:3.13-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Root-owned: Claude can't modify the tools it tests with
RUN pip install --no-cache-dir ansible==14.5.0 ansible-lint==26.10.1
